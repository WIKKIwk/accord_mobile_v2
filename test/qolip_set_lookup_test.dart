import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_home_screen.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_management_dialogs.dart';
import 'package:accord_mobile_v2/src/features/qolip/qolip_set_search.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _product = QolipProduct(
    code: 'DEMO-HOTLUNCH',
    name: 'Hotlunch',
    itemGroup: 'Demo tayyor mahsulotlar',
    warehouse: 'Qolip ombori');

SessionProfile _profile(String ref) => SessionProfile(
    role: UserRole.qolipchi,
    displayName: 'Qolipchi',
    legalName: '',
    ref: ref,
    phone: '',
    avatarUrl: '',
    capabilities: const ['qolip.manage']);

Finder _code() => find.byWidgetPredicate((widget) =>
    widget is TextField && widget.decoration?.labelText == 'Qolip code');
Finder _save() => find.widgetWithText(FilledButton, 'Saqlash');

Future<void> _open(WidgetTester tester,
    {bool singleMoldDialog = false,
    ValueChanged<QolipMoldDraft>? onNewMold}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('uz'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ],
    home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () => singleMoldDialog
                      ? showQolipMoldAddDialog(context,
                          scope: _product.name,
                          product: _product,
                          allowExisting: true, onSave: (draft) async {
                          onNewMold?.call(draft);
                        })
                      : showQolipProductSpecSheet(context,
                          initialProduct: _product,
                          lockProduct: true,
                          closeAfterSave: true),
                  child: const Text('Open'),
                ))),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String query) async {
  await tester.enterText(_code(), query);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

Future<void> _pressSave(WidgetTester tester) async {
  tester.testTextInput.hide();
  await tester.ensureVisible(_save());
  await tester.tap(_save());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Map<String, dynamic> _wire(QolipManagedSet entry) => {
      'name': entry.name,
      'set_id': entry.set.id,
      'fingerprint': entry.set.fingerprint,
      'warehouse': entry.source.warehouse,
      'products': [],
      'members': [
        for (final mold in entry.set.members)
          {
            'qolip_code': mold.qolipCode,
            'size': mold.qolipSize,
            'color': mold.qolipColor,
            'warehouse': mold.warehouse,
          }
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = MobileApi.instance;
  late List<QolipManagedSet> sets;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    QolipCatalogStore.instance.reset();
    await ServerEndpointStore.instance.clearOverride();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'set-lookup-token';
    AppSession.instance.profile = _profile('lookup-clerk');
    sets = [];
    for (final (prefix, name) in [
      ('RED', 'Kross qizil'),
      ('GREEN', 'Kross yashil'),
      ('BLUE', 'Botinka ko‘k')
    ]) {
      final created =
          await api.qolipCreateSet(warehouse: 'Qolip ombori', members: [
        for (var i = 1; i <= 2; i++)
          QolipMoldDraft(
              code: '$prefix-$i', size: 420, color: i == 1 ? 'BLACK' : 'RED'),
      ]);
      sets.add(await api.qolipRenameSet(setId: created.set.id, name: name));
    }
  });
  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    resetMobileApiTestModeData();
    QolipCatalogStore.instance.reset();
    await TestModeController.instance.setEnabled(false);
    await ServerEndpointStore.instance.clearOverride();
  });

  test(
      'set search tolerates partial names, typos and Cyrillic and ranks exact names',
      () async {
    expect(
        (await api.qolipResolveSet(' KROSS  QIZIL '))!.id, sets.first.set.id);
    expect((await searchQolipSets(sets, 'kross')).map((s) => s.name),
        ['Kross qizil', 'Kross yashil']);
    for (final query in [
      'kros qizl',
      'Кросс қизил',
      'qizil kross',
      'KROSS QIZIL'
    ]) {
      expect(
          (await searchQolipSets(sets, query)).first.set.id, sets.first.set.id,
          reason: query);
    }
    expect(await searchQolipSets(sets, 'unrelated'), isEmpty);
    expect(await searchQolipSets(sets, 'RED-3'), isEmpty);
    expect((await searchQolipSets(sets, 'RED-1')).single.set.id,
        sets.first.set.id);
    expect(
        await searchQolipSets(sets, 'RED-1', includeMoldCodes: false), isEmpty);
  });

  for (final inline in [true, false]) {
    testWidgets(
        '${inline ? 'inline suggestion' : 'save'} attaches one fuzzy name match with its complete molds',
        (tester) async {
      await _open(tester);
      await _type(tester, 'kros qizl');
      final suggestion =
          find.byKey(ValueKey('qolip-set-suggestion-${sets.first.set.id}'));
      expect(suggestion, findsOneWidget);
      if (inline) {
        await tester.ensureVisible(suggestion);
        await tester.tap(suggestion);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      } else {
        await _pressSave(tester);
      }
      expect(find.text('Mavjud komplektdan foydalanish'), findsOneWidget);
      expect(find.textContaining('Kross qizil (${sets.first.set.id})'),
          findsOneWidget);
      await tester.tap(find.text('Ha'));
      await tester.pumpAndSettle();
      final molds = await api.qolipProductMolds(_product.code);
      expect(molds.map((m) => m.qolipCode).toSet(), {'RED-1', 'RED-2'});
      expect(molds.every((m) => m.qolipSize == 420), isTrue);
      expect(find.text('Qolipni omborga biriktirish'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'ambiguous partial name opens choice cards and attaches only the chosen set',
      (tester) async {
    await _open(tester);
    await _type(tester, 'kross');
    await _pressSave(tester);
    expect(find.text('Mos komplektlar (2)'), findsOneWidget);
    await tester.tap(find.text('Kross yashil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Ha'));
    await tester.pumpAndSettle();
    expect(
        (await api.qolipProductMolds(_product.code))
            .map((m) => m.qolipCode)
            .toSet(),
        {'GREEN-1', 'GREEN-2'});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cancelling ambiguous set selection keeps input and creates no molds',
      (tester) async {
    await _open(tester);
    await _type(tester, 'kross');
    await _pressSave(tester);
    Navigator.of(tester.element(find.text('Mos komplektlar (2)'))).pop();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_code()).controller!.text, 'kross');
    expect(find.byType(AlertDialog), findsNothing);
    expect(await api.qolipProductMolds(_product.code), isEmpty);
  });

  testWidgets(
      'product add dialog accepts a set name without new-mold color or size',
      (tester) async {
    var newMolds = 0;
    await _open(tester, singleMoldDialog: true, onNewMold: (_) => newMolds++);
    await _type(tester, 'kros qizl');
    expect(tester.widget<FilledButton>(_save()).onPressed, isNotNull);
    await _pressSave(tester);
    await tester.tap(find.text('Ha'));
    await tester.pumpAndSettle();
    expect(newMolds, 0);
    expect(
        (await api.qolipProductMolds(_product.code))
            .map((m) => m.qolipCode)
            .toSet(),
        {'RED-1', 'RED-2'});
    expect(find.byType(AlertDialog), findsNothing);
  });

  test(
      'lookup caches catalog reads and rejects responses from a previous session',
      () async {
    await TestModeController.instance.setEnabled(false);
    final pending = Completer<http.Response>();
    var calls = 0;
    await http.runWithClient(() async {
      final lookup = QolipSetLookup();
      final old = lookup.load();
      await Future<void>.delayed(Duration.zero);
      final rejected = expectLater(
          old,
          throwsA(isA<MobileApiException>()
              .having((e) => e.code, 'code', 'session_scope_changed')));
      AppSession.instance.profile = _profile('another-clerk');
      pending.complete(http.Response(
          jsonEncode({
            'sets': [_wire(sets.first)]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      await rejected;
      expect((await lookup.load()).single.name, sets.last.name);
      await lookup.load();
      expect(calls, 2);
    },
        () => MockClient((request) async {
              expect(request.url.path, '/v1/mobile/qolip/sets');
              if (calls++ == 0) return pending.future;
              return http.Response(
                  jsonEncode({
                    'sets': [_wire(sets.last)]
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
