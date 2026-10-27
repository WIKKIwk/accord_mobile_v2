import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_sets_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: home,
    );

const _nameField = ValueKey('qolip-set-name-field');
const _save = ValueKey('qolip-set-name-save');
const _rename = 'Komplekt nomini o‘zgartirish';

Future<void> _openName(WidgetTester tester, String id) async {
  await tester.longPress(find.byKey(ValueKey('qolip-set-$id')));
  await tester.pumpAndSettle();
  expect(find.text(_rename), findsOneWidget);
  await tester.tap(find.text(_rename));
  await tester.pumpAndSettle();
}

void _mobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = MobileApi.instance;
  late List<QolipManagedSet> sets;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    await ServerEndpointStore.instance.clearOverride();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'set-name-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'name-clerk',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
    );
    sets = [];
    for (final code in ['NAME-A', 'NAME-B']) {
      sets.add(await api.qolipCreateSet(
        warehouse: 'Qolip ombori',
        members: [QolipMoldDraft(code: code, size: 420, color: 'BLACK')],
      ));
    }
  });

  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
    await ServerEndpointStore.instance.clearOverride();
  });

  testWidgets('long press assigns, reloads, prefills and searches a set name',
      (tester) async {
    _mobileViewport(tester);
    await tester.pumpWidget(_app(const QolipSetsScreen()));
    await tester.pumpAndSettle();
    await _openName(tester, sets.first.set.id);
    expect(
        tester.widget<TextField>(find.byKey(_nameField)).controller!.text, '');
    await tester.enterText(find.byKey(_nameField), 'Hot lunch');
    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();
    expect(find.text('Hot lunch'), findsOneWidget);
    expect(find.textContaining(sets.first.set.id), findsOneWidget);

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pumpWidget(_app(const QolipSetsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Hot lunch'), findsOneWidget);
    await _openName(tester, sets.first.set.id);
    expect(tester.widget<TextField>(find.byKey(_nameField)).controller!.text,
        'Hot lunch');
    await tester.enterText(find.byKey(_nameField), 'Hot lunch yangi');
    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();
    expect(find.text('Hot lunch yangi'), findsOneWidget);
    final saved = (await api.qolipManagedSets())
        .firstWhere((entry) => entry.set.id == sets.first.set.id);
    expect(saved.name, 'Hot lunch yangi');
    expect(saved.set.fingerprint, sets.first.set.fingerprint);

    await tester.enterText(find.byType(EditableText).first, 'yangi');
    await tester.pumpAndSettle();
    expect(
        find.byKey(ValueKey('qolip-set-${sets.first.set.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('qolip-set-${sets.last.set.id}')), findsNothing);
  });

  testWidgets('invalid and duplicate names keep the dialog open for correction',
      (tester) async {
    _mobileViewport(tester);
    await api.qolipRenameSet(setId: sets.first.set.id, name: 'Fresh');
    await tester.pumpWidget(_app(const QolipSetsScreen()));
    await tester.pumpAndSettle();
    await _openName(tester, sets.last.set.id);
    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();
    expect(find.text('1–160 ta belgidan iborat nom kiriting'), findsOneWidget);
    await tester.enterText(find.byKey(_nameField), ' FRESH ');
    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();
    expect(find.text('Bu nom boshqa komplektga berilgan. Boshqa nom kiriting.'),
        findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(_nameField)).controller!.text,
        ' FRESH ');
    expect(
        (await api.qolipManagedSets())
            .firstWhere((entry) => entry.set.id == sets.last.set.id)
            .name,
        '');
    await tester.enterText(find.byKey(_nameField), 'Fresh 2');
    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();
    expect(find.byKey(_nameField), findsNothing);
    expect(find.text('Fresh 2'), findsOneWidget);
  });

  test('rename wire contract persists names and preserves conflict errors',
      () async {
    await TestModeController.instance.setEnabled(false);
    final set = sets.first;
    var calls = 0;
    await http.runWithClient(() async {
      final saved =
          await api.qolipRenameSet(setId: set.set.id, name: ' Hot   lunch ');
      expect(saved.name, 'Hot lunch');
      expect(saved.set.id, set.set.id);
      await expectLater(
        api.qolipRenameSet(setId: set.set.id, name: 'Hot lunch'),
        throwsA(isA<MobileApiException>()
            .having((error) => error.code, 'code', 'qolip_set_name_conflict')),
      );
    },
        () => MockClient((request) async {
              expect(request.method, 'POST');
              expect(request.url.path, '/v1/mobile/qolip/sets/rename');
              expect(request.headers['Authorization'], 'Bearer set-name-token');
              expect(jsonDecode(request.body),
                  {'set_id': set.set.id, 'name': 'Hot lunch'});
              if (calls++ > 0) {
                return http.Response(
                    '{"error":"qolip_set_name_conflict"}', 409);
              }
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'set': {
                      'set_id': set.set.id,
                      'fingerprint': set.set.fingerprint,
                      'name': 'Hot lunch',
                      'warehouse': set.source.warehouse,
                      'members': [
                        for (final mold in set.set.members)
                          {
                            'qolip_code': mold.qolipCode,
                            'size': mold.qolipSize,
                            'color': mold.qolipColor,
                            'warehouse': mold.warehouse,
                          }
                      ],
                      'products': [],
                    }
                  }),
                  200);
            }));
    expect(calls, 2);
  });
}
