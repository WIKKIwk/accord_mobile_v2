import 'dart:async';
import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/paddon_widgets.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_storage_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> pallet(
        {bool archived = false, bool locked = true, int revision = 4}) =>
    {
      'code': 'QP-00012',
      'warehouse': 'Qolip ombori',
      'location': 'A1',
      'note': '',
      'locked': locked,
      'archived': archived,
      'revision': revision,
      'item_count': 1,
    };
Map<String, dynamic> mold() => {
      'qolip_code': 'Q-ONE',
      'qolip_set_id': '9501',
      'warehouse': 'Qolip ombori',
      'item_name': 'Shared mold',
      'size': 40,
      'quantity': 1
    };
Map<String, dynamic> detail(
        {bool archived = false, bool locked = true, int revision = 4}) =>
    {
      'ok': true,
      'paddon': pallet(archived: archived, locked: locked, revision: revision),
      'items': [mold()],
      'history': [],
    };
http.Response jsonResponse(Map<String, dynamic> data, [int code = 200]) =>
    http.Response(jsonEncode(data), code,
        headers: {'content-type': 'application/json'});
Widget app(Widget home) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate
    ],
    home: home);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = 'storage-test';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        ref: 'qolipchi',
        displayName: 'Worker',
        legalName: '',
        phone: '',
        avatarUrl: '',
        capabilities: ['qolip.manage'],
        assignedWarehouses: ['Qolip ombori']);
    AppSession.instance.revision.value++;
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    QolipCatalogStore.instance.reset();
  });

  test('typed pallet QR cannot collide with an existing mold code', () {
    expect(qolipPaddonCodeFromQr('qolip-paddon:QP-00012'), 'QP-00012');
    expect(qolipPaddonCodeFromQr('QP-00012'), isNull);
    expect(qolipPaddonCodeFromQr('Q-ONE'), isNull);
    expect(qolipPaddonCodeFromQr('qolip-paddon:Q-ONE'), isNull);
  });
  test('retry keys retain identical intent but change for revised contents',
      () {
    final intent = QolipStorageIntent();
    final body = {
      'action': 'archive',
      'code': 'QP-00012',
      'expected_revision': 4
    };
    final id = intent.keyFor(body);
    expect(intent.keyFor(Map<String, dynamic>.from(body)), id);
    expect(intent.keyFor({...body, 'expected_revision': 5}), isNot(id));
    intent.complete();
    expect(intent.keyFor(body), isNot(id));
  });
  test('physical candidates cannot be selected while held or unavailable', () {
    for (final blocked in [
      {'paddon_code': 'QP-00012'},
      {'archived': true},
      {'is_in_use': true},
      {'is_in_rework': true},
      {'is_transferring': true},
      {'is_custody_mismatch': true}
    ]) {
      expect(
          QolipStorageMold.fromJson({...mold(), ...blocked}).available, false);
    }
    expect(QolipStorageMold.fromJson(mold()).available, true);
  });
  test('API sends revision and request id and honors pagination', () async {
    await http.runWithClient(() async {
      final page = await MobileApi.instance
          .qolipStorageMolds(query: 'Q-ONE', offset: 100);
      expect(page.items.single.code, 'Q-ONE');
      expect(page.nextOffset, 200);
      final restored = await MobileApi.instance.qolipPaddonAction({
        'action': 'restore',
        'code': 'QP-00012',
        'expected_revision': 4,
        'request_id': 'stable-retry'
      });
      expect(restored.paddon.locked, true);
      expect(restored.paddon.archived, false);
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                expect(request.url.queryParameters['offset'], '100');
                expect(request.url.queryParameters['q'], 'Q-ONE');
                return jsonResponse({
                  'ok': true,
                  'molds': [mold()],
                  'has_more': true,
                  'next_offset': 200
                });
              }
              expect(jsonDecode(request.body), {
                'action': 'restore',
                'code': 'QP-00012',
                'expected_revision': 4,
                'request_id': 'stable-retry'
              });
              return jsonResponse(detail(revision: 5));
            }));
  });
  test('an account switch discards a late successful read', () async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      final read = MobileApi.instance.qolipPaddonDetail('QP-00012');
      await Future<void>.delayed(Duration.zero);
      AppSession.instance.profile = const SessionProfile(
          role: UserRole.qolipchi,
          ref: 'other',
          displayName: 'Other',
          legalName: '',
          phone: '',
          avatarUrl: '');
      response.complete(jsonResponse(detail()));
      await expectLater(
          read,
          throwsA(isA<MobileApiException>()
              .having((e) => e.code, 'code', 'session_scope_changed')));
    }, () => MockClient((_) => response.future));
  });
  test('malformed successful mutation never reports a valid pallet', () async {
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance
              .qolipPaddonAction({'action': 'lock', 'request_id': 'x'}),
          throwsA(anything));
    },
        () => MockClient((_) async => jsonResponse({
              'ok': true,
              'paddon': {'code': 'QP-00012'}
            })));
  });
  testWidgets('archived locked pallet restores without unlocking or editing',
      (tester) async {
    var archived = true;
    final writes = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const QolipPaddonScreen(code: 'QP-00012')));
      await tester.pumpAndSettle();
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Add molds'), findsNothing);
      expect(find.text('Unlock'), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Restore'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(writes.single['action'], 'restore');
      expect(writes.single['expected_revision'], 4);
      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
      expect(find.text('Add molds'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                writes.add(
                    Map<String, dynamic>.from(jsonDecode(request.body) as Map));
                archived = false;
              }
              return jsonResponse(
                  detail(archived: archived, revision: archived ? 4 : 5));
            }));
  });
  testWidgets('cancel archive confirmation sends no mutation', (tester) async {
    var writes = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const QolipPaddonScreen(code: 'QP-00012')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.text('Locked'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') writes++;
              return jsonResponse(detail());
            }));
  });
  testWidgets('old pallet archive visit cannot restore a newer visit',
      (tester) async {
    var writes = 0;
    final entry = QolipArchiveEntry.fromJson({
      'id': 'old-visit',
      'kind': 'paddon',
      'code': 'QP-00012',
      'warehouse': 'Qolip ombori',
      'archived_at': '2026-10-28T10:00:00Z',
      'snapshot': {
        'items': [mold()]
      }
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(app(QolipArchiveDetailScreen(entry: entry)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.textContaining('state changed on another device'),
          findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') writes++;
              final response = detail(archived: true, revision: 10);
              (response['paddon'] as Map)['archive_entry_id'] = 'new-visit';
              return jsonResponse(response);
            }));
  });
  testWidgets('committed mutation refreshes canonical state after old replay',
      (tester) async {
    var written = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const QolipPaddonScreen(code: 'QP-00012')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Unlock'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Add molds'), findsNothing);
      expect(find.text('Restore'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                written = true;
                return jsonResponse(detail(locked: false, revision: 5));
              }
              return jsonResponse(
                  detail(archived: written, revision: written ? 7 : 4));
            }));
  });
  testWidgets('switching accounts hides already loaded pallet contents',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const QolipPaddonScreen(code: 'QP-00012')));
      await tester.pumpAndSettle();
      expect(find.text('Q-ONE'), findsOneWidget);
      AppSession.instance.profile = const SessionProfile(
          role: UserRole.qolipchi,
          ref: 'other',
          displayName: 'Other',
          legalName: '',
          phone: '',
          avatarUrl: '');
      AppSession.instance.revision.value++;
      await tester.pumpAndSettle();
      expect(find.text('Q-ONE'), findsNothing);
      expect(find.textContaining('Account or permissions changed'),
          findsOneWidget);
    }, () => MockClient((_) async => jsonResponse(detail())));
  });
  test('archive filter sends calendar dates without UTC conversion', () async {
    await http.runWithClient(() async {
      await MobileApi.instance.qolipArchive(
          warehouse: 'Qolip ombori',
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 28),
          status: 'all');
    },
        () => MockClient((request) async {
              expect(request.url.queryParameters['warehouse'], 'Qolip ombori');
              expect(request.url.queryParameters['from'], '2026-10-01');
              expect(request.url.queryParameters['to'], '2026-10-28');
              expect(request.url.queryParameters['status'], 'all');
              return jsonResponse(
                  {'ok': true, 'entries': [], 'has_more': false});
            }));
  });
  test(
      'complete set lookup includes later pages and rejects any unavailable member',
      () async {
    final offsets = <String>[];
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.qolipStorageSet('9501', warehouse: 'Qolip ombori'),
          throwsA(isA<MobileApiException>()
              .having((e) => e.code, 'code', 'qolip_set_unavailable')
              .having((e) => e.details, 'blocked', ['Q-TWO'])));
      expect(offsets, ['0', '100']);
    },
        () => MockClient((request) async {
              final offset = request.url.queryParameters['offset']!;
              offsets.add(offset);
              return jsonResponse({
                'ok': true,
                'molds': [
                  offset == '0'
                      ? mold()
                      : {...mold(), 'qolip_code': 'Q-TWO', 'is_in_use': true}
                ],
                'has_more': offset == '0',
                'next_offset': 100
              });
            }));
  });
  test('complete set includes every distinct code across pages', () async {
    await http.runWithClient(() async {
      final selected = await MobileApi.instance.qolipStorageSet('9501');
      expect(selected.map((m) => m.code), ['Q-ONE', 'Q-TWO']);
    },
        () => MockClient((request) async {
              final first = request.url.queryParameters['offset'] == '0';
              return jsonResponse({
                'ok': true,
                'molds': [
                  mold(),
                  if (!first) {...mold(), 'qolip_code': 'Q-TWO'}
                ],
                'has_more': first,
                'next_offset': 100
              });
            }));
  });
  test('archive mutation resets names as well as cached mold details',
      () async {
    final store = QolipCatalogStore.instance;
    store.window('').loaded = true;
    await http.runWithClient(() async {
      await MobileApi.instance.qolipPaddonAction(
          {'action': 'archive', 'request_id': 'archive-reset'});
      expect(store.window('').loaded, false);
    },
        () => MockClient((_) async => jsonResponse({
              ...detail(archived: true),
              'catalog_delta': {'reset': true}
            })));
  });
  testWidgets(
      'archive filters stay scrollable with keyboard and expire on account change',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const QolipStorageScreen(archive: true)));
      await tester.pumpAndSettle();
      expect(find.text('Archive dates'), findsOneWidget);
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      AppSession.instance.profile = const SessionProfile(
          role: UserRole.qolipchi,
          ref: 'different',
          displayName: 'Other',
          legalName: '',
          phone: '',
          avatarUrl: '');
      AppSession.instance.revision.value++;
      await tester.pumpAndSettle();
      expect(find.text('Archive dates'), findsNothing);
      expect(find.textContaining('Account or permissions changed'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async =>
            jsonResponse({'ok': true, 'entries': [], 'has_more': false})));
  });
  test('QR mold lookup requests exact code rather than fuzzy first page',
      () async {
    await http.runWithClient(() async {
      final result = await MobileApi.instance.qolipStorageMolds(code: 'Q-ONE');
      expect(result.items.single.code, 'Q-ONE');
    },
        () => MockClient((request) async {
              expect(request.url.queryParameters['code'], 'Q-ONE');
              expect(request.url.queryParameters['q'], '');
              return jsonResponse({
                'ok': true,
                'molds': [mold()],
                'has_more': false
              });
            }));
  });
  testWidgets(
      'definitive restore conflict rereads same archive visit with new revision',
      (tester) async {
    var revision = 4;
    final writes = <Map<String, dynamic>>[];
    final entry = QolipArchiveEntry.fromJson({
      'id': 'same-visit',
      'kind': 'paddon',
      'code': 'QP-00012',
      'warehouse': 'Qolip ombori',
      'archived_at': '2026-10-28T10:00:00Z',
      'snapshot': {
        'items': [mold()]
      }
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(app(QolipArchiveDetailScreen(entry: entry)));
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();
      }
      expect(writes.map((e) => e['expected_revision']), [4, 5]);
      expect(writes[0]['request_id'], isNot(writes[1]['request_id']));
      expect(find.text('Restored'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                writes.add(
                    Map<String, dynamic>.from(jsonDecode(request.body) as Map));
                if (writes.length == 1) {
                  revision = 5;
                  return jsonResponse({'error': 'qolip_paddon_changed'}, 409);
                }
                return jsonResponse(detail(revision: 6));
              }
              final response = detail(archived: true, revision: revision);
              (response['paddon'] as Map)['archive_entry_id'] = 'same-visit';
              return jsonResponse(response);
            }));
  });
  testWidgets(
      'uncertain restore failure preserves original request and does not retarget visit',
      (tester) async {
    var reads = 0;
    final writes = <Map<String, dynamic>>[];
    final entry = QolipArchiveEntry.fromJson({
      'id': 'same-visit',
      'kind': 'paddon',
      'code': 'QP-00012',
      'warehouse': 'Qolip ombori',
      'archived_at': '2026-10-28T10:00:00Z',
      'snapshot': {
        'items': [mold()]
      }
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(app(QolipArchiveDetailScreen(entry: entry)));
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();
      }
      expect(reads, 1);
      expect(writes[0], writes[1]);
      expect(find.text('Restored'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                writes.add(
                    Map<String, dynamic>.from(jsonDecode(request.body) as Map));
                if (writes.length == 1) {
                  return jsonResponse({'error': 'temporary_failure'}, 500);
                }
                return jsonResponse(detail(revision: 5));
              }
              reads++;
              final response = detail(archived: true);
              (response['paddon'] as Map)['archive_entry_id'] = 'same-visit';
              return jsonResponse(response);
            }));
  });
  testWidgets('leaving archive detail during restore lookup sends no write',
      (tester) async {
    final pending = Completer<http.Response>();
    var writes = 0;
    final entry = QolipArchiveEntry.fromJson({
      'id': 'same-visit',
      'kind': 'paddon',
      'code': 'QP-00012',
      'warehouse': 'Qolip ombori',
      'archived_at': '2026-10-28T10:00:00Z',
      'snapshot': {
        'items': [mold()]
      }
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(app(QolipArchiveDetailScreen(entry: entry)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();
      await tester.pumpWidget(app(const SizedBox()));
      final response = detail(archived: true);
      (response['paddon'] as Map)['archive_entry_id'] = 'same-visit';
      pending.complete(jsonResponse(response));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                writes++;
                return jsonResponse(detail());
              }
              return pending.future;
            }));
  });
  testWidgets(
      'discarding pending mold archive gives reselected codes a new intent',
      (tester) async {
    final writes = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const QolipStorageScreen()));
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Molds: Archive'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm (1)'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();
        if (attempt == 0) {
          await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
          await tester.pumpAndSettle();
        }
      }
      expect(writes.length, 2);
      expect(writes[0]['qolip_codes'], writes[1]['qolip_codes']);
      expect(writes[0]['request_id'], isNot(writes[1]['request_id']));
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                writes.add(
                    Map<String, dynamic>.from(jsonDecode(request.body) as Map));
                return jsonResponse({'error': 'temporary_failure'}, 500);
              }
              return jsonResponse(request.url.path.endsWith('/molds')
                  ? {
                      'ok': true,
                      'molds': [mold()],
                      'has_more': false
                    }
                  : {'ok': true, 'paddons': [], 'has_more': false});
            }));
  });
  testWidgets('pallet list shares production cards and opens create from dock',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var writes = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const QolipStorageScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(PaddonListCard), findsNWidgets(2));
      expect(
          find.byKey(const ValueKey('qolip-paddons-summary')), findsOneWidget);
      expect(find.text('Molds: 3'), findsOneWidget);
      expect(find.text('New pallet'), findsNothing);
      await tester
          .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New pallet'));
      // Creation stays busy while its review dialog is open.
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(writes, 0);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      await tester
          .tap(find.byKey(const ValueKey('qolip-paddon-card-QP-00012')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('qolip-paddon-summary')), findsOneWidget);
      expect(find.text('Q-ONE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method != 'GET') writes++;
              if (request.url.path.endsWith('/paddons/detail')) {
                return jsonResponse(detail());
              }
              if (request.url.path.endsWith('/qolip/blocks')) {
                return jsonResponse({
                  'warehouses': ['Qolip ombori'],
                  'blocks': []
                });
              }
              return jsonResponse({
                'ok': true,
                'paddons': [
                  pallet(),
                  {
                    ...pallet(locked: false),
                    'code': 'QP-00013',
                    'item_count': 2
                  },
                ]
              });
            }));
  });

  testWidgets('dock add reviews selected molds before writing on small screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var added = false;
    var writes = 0;
    Map<String, dynamic> current() => {
          ...detail(locked: false, revision: added ? 5 : 4),
          'paddon': {
            ...pallet(locked: false, revision: added ? 5 : 4),
            'item_count': added ? 1 : 0
          },
          'items': [if (added) mold()],
        };
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const QolipPaddonScreen(code: 'QP-00012')));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add molds'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm (1)'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Q-ONE'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.byKey(const ValueKey('qolip-paddon-mold-Q-ONE')),
          findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Lock'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse({
                  'ok': true,
                  'molds': [mold()]
                });
              }
              if (request.method == 'POST') {
                final body = jsonDecode(request.body) as Map;
                expect(body['action'], 'add');
                expect(body['code'], 'QP-00012');
                expect(body['expected_revision'], 4);
                expect(body['qolip_codes'], ['Q-ONE']);
                writes++;
                added = true;
              }
              return jsonResponse(current());
            }));
  });

  testWidgets('mold details overlay hides captured data after account switch',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const QolipPaddonScreen(code: 'QP-00012')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Q-ONE'));
      await tester.pumpAndSettle();
      expect(find.text('Q-ONE'), findsWidgets);
      AppSession.instance.profile = const SessionProfile(
          role: UserRole.qolipchi,
          ref: 'different',
          displayName: 'Other',
          legalName: '',
          phone: '',
          avatarUrl: '');
      AppSession.instance.revision.value++;
      await tester.pumpAndSettle();
      expect(find.text('Q-ONE'), findsNothing);
      expect(
          find.textContaining('Account or permissions changed'), findsWidgets);
    }, () => MockClient((_) async => jsonResponse(detail())));
  });
}
