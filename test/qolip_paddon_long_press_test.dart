import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_storage_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _code = 'QP-00012';
const _card = ValueKey('qolip-paddon-card-$_code');
const _add = ValueKey('qolip-paddon-menu-add');
const _delete = ValueKey('qolip-paddon-menu-delete');
const _confirm = ValueKey('qolip-paddon-delete-confirm');
const _cancel = ValueKey('qolip-paddon-delete-cancel');

Map<String, dynamic> _paddon({int count = 0, int revision = 1}) => {
      'code': _code,
      'warehouse': 'Qolip ombori',
      'locked': false,
      'archived': false,
      'revision': revision,
      'item_count': count,
    };

http.Response _json(Map<String, dynamic> data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json'});

Widget _app() => const MaterialApp(
      locale: Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: QolipStorageScreen(),
    );

Future<void> _openMenu(WidgetTester tester) async {
  await tester.longPress(find.byKey(_card));
  await tester.pumpAndSettle();
  expect(find.byKey(_add), findsOneWidget);
  expect(find.byKey(_delete), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = 'paddon-actions-test';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      ref: 'qolipchi',
      displayName: 'Worker',
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
      assignedWarehouses: ['Qolip ombori'],
    );
    AppSession.instance.revision.value++;
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    QolipCatalogStore.instance.reset();
  });

  testWidgets('long press opens the ordinary mold picker after detail loads',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final detail = Completer<http.Response>();
    final writes = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _openMenu(tester);
      await tester.tap(find.byKey(_add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('qolip-picker-list')), findsNothing);
      detail.complete(_json({
        'ok': true,
        'paddon': _paddon(),
        'items': [],
        'history': [],
      }));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qolip-picker-list')), findsOneWidget);
      expect(find.text(_code), findsOneWidget);
      expect(writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method != 'GET') writes.add(request.url.path);
              if (request.url.path.endsWith('/paddons/detail')) {
                return detail.future;
              }
              if (request.url.path.endsWith('/paddons/molds')) {
                return _json({'ok': true, 'molds': [], 'has_more': false});
              }
              return _json({
                'ok': true,
                'paddons': [_paddon()],
                'has_more': false,
              });
            }));
  });

  testWidgets('freshly empty pallet requires confirmation before deletion',
      (tester) async {
    final writes = <Map<String, dynamic>>[];
    var deleted = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _openMenu(tester);
      await tester.tap(find.byKey(_delete));
      await tester.pumpAndSettle();
      expect(find.text('Delete pallet?'), findsOneWidget);
      await tester.tap(find.byKey(_cancel));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);

      await _openMenu(tester);
      await tester.tap(find.byKey(_delete));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(writes.single['action'], 'delete');
      expect(writes.single['code'], _code);
      expect(writes.single['expected_revision'], 2);
      expect(writes.single['request_id'], isNotEmpty);
      expect(find.byKey(_card), findsNothing);
      expect(find.text('Pallet deleted'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                writes.add(
                    Map<String, dynamic>.from(jsonDecode(request.body) as Map));
                deleted = true;
                return _json({'ok': true, 'deleted': true, 'code': _code});
              }
              if (request.url.path.endsWith('/paddons/detail')) {
                return _json({
                  'ok': true,
                  'paddon': _paddon(revision: 2),
                  'items': [],
                  'history': [],
                });
              }
              return _json({
                'ok': true,
                'paddons': [if (!deleted) _paddon(count: 1)],
                'has_more': false,
              });
            }));
  });

  testWidgets('nonempty pallet cannot be deleted from a stale list',
      (tester) async {
    var writes = 0;
    var changed = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _openMenu(tester);
      await tester.tap(find.byKey(_delete));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.byKey(_card), findsOneWidget);
      expect(find.text('Remove all molds from the pallet before deleting it.'),
          findsOneWidget);

      await _openMenu(tester);
      await tester.tap(find.byKey(_delete));
      await tester.pumpAndSettle();
      expect(find.byKey(_confirm), findsNothing);
      expect(writes, 1);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                writes++;
                changed = true;
                return _json(
                    {'ok': false, 'error': 'qolip_paddon_not_empty'}, 409);
              }
              if (request.url.path.endsWith('/paddons/detail')) {
                return _json({
                  'ok': true,
                  'paddon': _paddon(
                      count: changed ? 1 : 0, revision: changed ? 2 : 1),
                  'items': [],
                  'history': [],
                });
              }
              return _json({
                'ok': true,
                'paddons': [
                  _paddon(count: changed ? 1 : 0, revision: changed ? 2 : 1)
                ],
                'has_more': false,
              });
            }));
  });

  testWidgets('uncertain deletion retries the same request without a new read',
      (tester) async {
    final writes = <Map<String, dynamic>>[];
    var detailReads = 0;
    var deletionConfirmed = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _openMenu(tester);
      await tester.tap(find.byKey(_delete));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(find.byKey(_card), findsOneWidget);

      await _openMenu(tester);
      await tester.tap(find.byKey(_delete));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(writes, hasLength(2));
      expect(writes.last, writes.first);
      expect(detailReads, 1);
      expect(find.byKey(_card), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                writes.add(
                    Map<String, dynamic>.from(jsonDecode(request.body) as Map));
                if (writes.length == 1) {
                  return _json({'ok': false, 'error': 'connection_lost'}, 503);
                }
                deletionConfirmed = true;
                return _json({'ok': true, 'deleted': true, 'code': _code});
              }
              if (request.url.path.endsWith('/paddons/detail')) {
                detailReads++;
                if (writes.isNotEmpty) {
                  return _json(
                      {'ok': false, 'error': 'qolip_storage_not_found'}, 404);
                }
                return _json({
                  'ok': true,
                  'paddon': _paddon(),
                  'items': [],
                  'history': [],
                });
              }
              return _json({
                'ok': true,
                'paddons': [if (!deletionConfirmed) _paddon()],
                'has_more': false,
              });
            }));
  });

  testWidgets('account change during confirmation prevents deletion',
      (tester) async {
    var writes = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _openMenu(tester);
      await tester.tap(find.byKey(_delete));
      await tester.pumpAndSettle();
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        ref: 'another-user',
        displayName: 'Another worker',
        legalName: '',
        phone: '',
        avatarUrl: '',
        capabilities: ['qolip.manage'],
        assignedWarehouses: ['Qolip ombori'],
      );
      AppSession.instance.revision.value++;
      await tester.pump();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') writes++;
              if (request.url.path.endsWith('/paddons/detail')) {
                return _json({
                  'ok': true,
                  'paddon': _paddon(),
                  'items': [],
                  'history': [],
                });
              }
              return _json({
                'ok': true,
                'paddons': [_paddon()],
                'has_more': false,
              });
            }));
  });
}
