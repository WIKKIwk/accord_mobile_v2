import 'dart:async';
import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
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
      {'is_transferring': true}
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
}
