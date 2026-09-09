import 'dart:async';
import 'dart:convert';
import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/zebra_rps_renderer.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/features/gscale/gscale_mobile_app.dart';
import 'package:accord_mobile_v2/src/features/raw_material_split/models/raw_material_split_models.dart';
import 'package:accord_mobile_v2/src/features/raw_material_split/models/raw_material_split_width_plan.dart';
import 'package:accord_mobile_v2/src/features/raw_material_split/presentation/raw_material_split_screen.dart';
import 'package:accord_mobile_v2/src/features/raw_material_split/presentation/raw_material_split_history_screen.dart';
import 'package:accord_mobile_v2/src/features/raw_material_split/presentation/raw_material_split_print.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = SessionProfile(
    role: UserRole.homashyoRezkachi,
    displayName: 'Cutter',
    legalName: '',
    ref: 'split-1',
    phone: '',
    avatarUrl: '',
    capabilities: ['raw_material.split']);
const _source = {
  'revision': '1.000000',
  'stock_id': 'parent',
  'barcode': 'parent',
  'warehouse': 'Raw W',
  'item_code': 'FILM',
  'item_name': 'Film',
  'kg': '100',
  'width_mm': '1000',
  'micron': '20'
};
final _result = <String, dynamic>{
  'id': 'split-result',
  'source': _source,
  'source_kg': '100',
  'output_kg': '98',
  'waste_kg': '2',
  'outputs': [
    {
      ..._source,
      'stock_id': 'child1',
      'barcode': 'child1',
      'kg': '39',
      'gross_kg': '40',
      'bobina_kg': '1',
      'width_mm': '400'
    },
    {
      ..._source,
      'stock_id': 'child2',
      'barcode': 'child2',
      'kg': '59',
      'gross_kg': '60',
      'bobina_kg': '1',
      'width_mm': '600'
    },
  ],
};
Map<String, dynamic> _payload() => {
      'request_id': newRawSplitRequestId(),
      'source_barcode': 'parent',
      'expected_revision': '1.000000',
      'expected_kg': '100',
      'expected_width_mm': '1000',
      'expected_micron': '20',
      'waste_kg': '2',
      'outputs': [
        {'kg': '39', 'width_mm': '400', 'gross_kg': '40', 'bobina_kg': '1'},
        {'kg': '59', 'width_mm': '600', 'gross_kg': '60', 'bobina_kg': '1'}
      ]
    };
http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _issueResult(Map<String, dynamic> payload) {
  final command = payload['command'] as Map;
  return {
    'id': 'raw-issue:test',
    'request_id': command['request_id'],
    'source': _source,
    'source_kg': '100.000000',
    'output_kg': '98.000000',
    'entered_waste_kg': command['waste_kg'],
    'waste_kg': '1.000000',
    'difference_kg': '1.000000',
    'kind': 'missing_weight',
    'outputs': command['outputs'],
    'note': (payload['note'] as String).trim(),
    'actor_ref': 'split-1',
    'actor_name': 'Cutter',
    'created_at': '2026-09-08T12:00:00+00:00',
  };
}

Future<void> _submitWidth(WidgetTester tester, int index, String width) async {
  await tester.enterText(
      find.widgetWithText(TextField, 'Eni (mm)').at(index), width);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _tapAddRoll(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, '+ rulon'));
  await tester.tap(find.widgetWithText(FilledButton, '+ rulon'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = _profile;
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });
  test(
      'waste errors preserve measurements and distinguish zero, missing and excess',
      () {
    for (final entry in [
      ('0', 'zero_waste', '2 kg hisobga olinmagan'),
      ('00,000000', 'zero_waste', '2 kg hisobga olinmagan'),
      ('1', 'missing_weight', '1 kg hisobga olinmagan'),
      ('2.000001', 'excess_weight', 'Asl vazndan 0.000001 kg oshib ketdi'),
      ('', 'invalid_waste', 'Atxot kg ni kiriting'),
      ('bad', 'invalid_waste', 'Atxot kg ni kiriting'),
      ('-1', 'invalid_waste', 'Atxot kg ni kiriting'),
      ('1.', 'invalid_waste', 'Atxot kg ni kiriting'),
    ]) {
      final check = RawSplitWasteCheck(
          rawSplitQuantity('100'), rawSplitQuantity('98'), entry.$1);
      expect(check.kind, entry.$2);
      expect(check.message, contains(entry.$3));
      if (check.kind == 'invalid_waste') expect(check.difference, isNull);
    }
    expect(
        RawSplitWasteCheck(rawSplitQuantity('100'), rawSplitQuantity('98'), '2')
            .kind,
        isNull);
  });

  test(
      'issue retry survives lost or invalid response and stays separate from stock',
      () async {
    final payload = {
      'command': _payload()..['waste_kg'] = '1',
      'note': 'Tarozi tekshirilsin'
    };
    final calls = <String>[];
    var attempt = 0;
    await http.runWithClient(() async {
      await expectLater(MobileApi.instance.rawSplitReportIssue(payload),
          throwsA(isA<http.ClientException>()));
      expect(await MobileApi.instance.rawSplitIssuePending(), payload);
      expect(await MobileApi.instance.rawSplitPending(), isNull);
      AppSession.instance.profile = _profile.copyWith(ref: 'split-2');
      expect(await MobileApi.instance.rawSplitIssuePending(), isNull);
      AppSession.instance.profile = _profile;
      await expectLater(
          MobileApi.instance
              .rawSplitReportIssue({...payload, 'note': 'Changed'}),
          throwsStateError);
      await expectLater(MobileApi.instance.rawSplitReportIssue(payload),
          throwsFormatException);
      expect(await MobileApi.instance.rawSplitIssuePending(), payload);
      final saved = await MobileApi.instance.rawSplitReportIssue(
          (await MobileApi.instance.rawSplitIssuePending())!);
      expect(saved.check.difference, rawSplitQuantity('1'));
      expect(await MobileApi.instance.rawSplitIssuePending(), isNull);
      expect(calls.length, 3);
      expect(calls.toSet().length, 1);
    },
        () => MockClient((request) async {
              expect(request.url.path, '/v1/mobile/raw-material-split/issues');
              calls.add(request.body);
              attempt++;
              if (attempt == 1) throw http.ClientException('lost response');
              final result = _issueResult(payload);
              if (attempt == 2) result['difference_kg'] = '2.000000';
              return _json(result);
            }));
  });

  testWidgets(
      'print exposes inline issue form; reporting saves only audit and appears in history',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? report;
    final posts = <String>[];
    Widget app(Widget home) => MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        );
    Future<void> tap(String text) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(text));
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    await http.runWithClient(() async {
      await tester.pumpWidget(app(const RawMaterialSplitScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'parent');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await _submitWidth(tester, 0, '700');
      await tester.enterText(
          find.widgetWithText(TextField, 'Og‘irlik (kg)'), '99');
      await tester.enterText(
          find.widgetWithText(TextField, 'Babina (kg)'), '1');
      final waste = find.widgetWithText(TextField, 'Atxot (kg) *');
      await tester.enterText(waste, '0');
      expect(find.widgetWithText(TextField, 'Farq sababi'), findsNothing);
      await tap('Saqlash va chop etish');
      expect(find.textContaining('2 kg hisobga olinmagan'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Farq sababi'), findsOneWidget);
      expect(posts, isEmpty);
      expect(find.byType(ServerPickerPage), findsNothing);
      expect(tester.widget<TextField>(waste).controller!.text, '0');
      expect(tester.getRect(find.textContaining('2 kg hisobga olinmagan')).top,
          greaterThanOrEqualTo(tester.getRect(waste).bottom));
      await tap('Muammoni saqlash');
      expect(find.text('Farq sababini yozing'), findsOneWidget);
      expect(posts, isEmpty);
      await tester.enterText(waste, '1');
      await tester.enterText(
          find.widgetWithText(TextField, 'Farq sababi'), 'Tarozi tekshirilsin');
      await tap('Muammoni saqlash');
      expect(posts, ['/v1/mobile/raw-material-split/issues']);
      expect(
          find.text('Muammo saqlandi. Chop etish uchun hisobni to‘g‘rilang.'),
          findsOneWidget);
      expect(tester.widget<TextField>(waste).controller!.text, '1');
      await tap('Saqlash va chop etish');
      expect(posts.length, 1); // Reporting never permits an invalid stock save.
      expect(find.byType(ServerPickerPage), findsNothing);
      await tester.enterText(waste, '2');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Farq sababi'), findsNothing);
      expect(find.textContaining('Hisob teng ✓'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(app(const RawMaterialSplitHistoryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Muammolar'), findsOneWidget);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('Sabab: Tarozi tekshirilsin'), findsOneWidget);
      expect(find.text('QR: parent'), findsOneWidget);
      expect(find.textContaining('Cutter ·'), findsOneWidget);
      expect(find.byTooltip('Shu rulonni qayta chop etish'), findsNothing);
      expect(find.text('Muammo qaydi. Ombor hisobi o‘zgartirilmagan.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                posts.add(request.url.path);
                expect(
                    request.url.path, '/v1/mobile/raw-material-split/issues');
                final body =
                    Map<String, dynamic>.from(jsonDecode(request.body) as Map);
                final command = body['command'] as Map;
                expect(command['waste_kg'], '1');
                expect(command['outputs'], [
                  {
                    'kg': '98.000000',
                    'gross_kg': '99.000000',
                    'bobina_kg': '1.000000',
                    'width_mm': '700.000000'
                  }
                ]);
                report = _issueResult(body);
                return _json(report!);
              }
              if (request.url.path.endsWith('/source')) return _json(_source);
              return _json({
                'warehouses': ['Raw W'],
                'history': [],
                'issues': [if (report != null) report]
              });
            }));
  });
  test('width plans enforce 355 mm, exact total and usable remainder', () {
    final one = RawSplitWidthPlan('700', ['400']);
    expect(one.maxRolls, 1);
    expect(one.remaining, rawSplitQuantity('300'));
    expect(one.canAdd, isFalse);
    one.validateForSave();
    for (final widths in [
      ['350', '350'],
      ['355', '355'],
      ['700.000001'],
      ['NaN'],
      ['-1']
    ]) {
      expect(() => RawSplitWidthPlan('700', widths).validateForSave(),
          throwsFormatException);
    }
    RawSplitWidthPlan('710', ['355', '355']).validateForSave();
    final edge = RawSplitWidthPlan('1000', ['645']);
    expect(edge.canAdd, isTrue);
    expect(edge.validateForSave, throwsFormatException);
    final trim = RawSplitWidthPlan('1000', ['645,000001']);
    expect(trim.remaining, rawSplitQuantity('354.999999'));
    expect(trim.canAdd, isFalse);
    trim.validateForSave();
    final pending = RawSplitWidthPlan('1000', ['600', '']);
    expect(pending.canAdd, isFalse);
    expect(pending.validateForSave, throwsFormatException);
    expect(RawSplitWidthPlan('354.999999', ['']).maxRolls, 0);
  });
  testWidgets(
      'field-sized plus adds only fitting rolls and preserves entered data',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var sourceWidth = '700';
    var saves = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RawMaterialSplitScreen(),
      ));
      await tester.pumpAndSettle();
      Future<void> scan() async {
        await tester.enterText(find.byType(TextField).first, 'parent');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
      }

      final widths = find.widgetWithText(TextField, 'Eni (mm)');
      final weights = find.widgetWithText(TextField, 'Og‘irlik (kg)');
      final bobinas = find.widgetWithText(TextField, 'Babina (kg)');
      await scan();
      expect(widths, findsOneWidget);
      expect(tester.widget<TextField>(widths.first).textInputAction,
          TextInputAction.done);
      expect(tester.widget<TextField>(widths.first).decoration!.suffixIcon,
          isNull);
      expect(find.byTooltip('Enni tasdiqlash'), findsNothing);
      expect(tester.getCenter(find.text('Netto: —')).dy,
          closeTo(tester.getCenter(bobinas.first).dy, 0.1));
      final widthBeforeWarning = tester.getRect(widths.first);
      await _submitWidth(tester, 0, '350');
      final warning = find.text('1-rulon: Eni kamida 355 mm bo‘lsin');
      expect(warning, findsOneWidget);
      final widthAfterWarning = tester.getRect(widths.first);
      expect(widthAfterWarning.top, closeTo(widthBeforeWarning.top, 0.1));
      expect(widthAfterWarning.height, closeTo(widthBeforeWarning.height, 0.1));
      expect(widthAfterWarning.top,
          closeTo(tester.getRect(weights.first).top, 0.1));
      expect(
          tester.widget<TextField>(widths.first).decoration!.errorText, isNull);
      expect(
          tester.getRect(warning).top,
          greaterThan(tester
              .getRect(find.widgetWithText(TextField, 'Atxot (kg) *'))
              .bottom));
      expect(widths, findsOneWidget);
      await _submitWidth(tester, 0, '400');
      expect(widths, findsOneWidget);
      expect(find.text('Qolgan 300 mm — atxot'), findsOneWidget);
      expect(find.text('Atxotga ketadi: 300 mm'), findsOneWidget);
      expect(find.text('Rulon qo‘shish'), findsNothing);
      expect(find.text('+ rulon'), findsNothing);
      expect(tester.getCenter(find.text('Netto: —')).dy,
          closeTo(tester.getCenter(bobinas.first).dy, 0.1));

      sourceWidth = '1000';
      await scan();
      await tester.enterText(widths.first, '600');
      await tester.pump();
      expect(widths, findsOneWidget); // Typing alone cannot add rows.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(widths, findsOneWidget); // Done does not add a roll.
      final add = find.widgetWithText(FilledButton, '+ rulon');
      expect(add, findsOneWidget);
      final addRect = tester.getRect(add);
      final fieldRect = tester.getRect(bobinas.first);
      expect(addRect.width, closeTo(fieldRect.width, 0.1));
      expect(addRect.height, closeTo(fieldRect.height, 0.1));
      final addShape = tester
          .widget<FilledButton>(add)
          .style!
          .shape!
          .resolve({}) as RoundedRectangleBorder;
      final inputShape = Theme.of(tester.element(bobinas.first))
          .inputDecorationTheme
          .enabledBorder as OutlineInputBorder;
      expect(addShape.borderRadius, inputShape.borderRadius);
      expect(tester.getRect(find.text('Netto: —')).top,
          greaterThan(addRect.bottom));
      await _tapAddRoll(tester);
      expect(widths, findsNWidgets(2));
      expect(add, findsNothing); // An empty draft cannot be added twice.
      await _submitWidth(tester, 0, '600');
      expect(widths, findsNWidgets(2)); // Repeated Done is idempotent.
      await _submitWidth(tester, 0, '700');
      expect(widths, findsOneWidget); // Only the entirely empty row is removed.
      await _submitWidth(tester, 0, '645');
      expect(add, findsOneWidget);
      await _tapAddRoll(tester);
      expect(widths, findsNWidgets(2)); // Exactly 355 mm fits.
      await _submitWidth(tester, 0, '645.000001');
      expect(widths, findsOneWidget);
      await tester.enterText(widths.first, '600');
      await tester.pump();
      await _tapAddRoll(tester);
      expect(widths, findsNWidgets(2));
      await _submitWidth(tester, 1, '400');
      await tester.enterText(weights.at(1), '12');
      await tester.enterText(bobinas.at(1), '1');
      await _submitWidth(tester, 0, '700');
      expect(widths, findsNWidgets(2));
      expect(tester.widget<TextField>(widths.at(1)).controller!.text, '400');
      expect(tester.widget<TextField>(weights.at(1)).controller!.text, '12');
      expect(tester.widget<TextField>(bobinas.at(1)).controller!.text, '1');
      expect(find.textContaining('Enlar yig‘indisi asl endan oshdi'),
          findsNWidgets(2));
      expect(add, findsNothing);
      await tester.ensureVisible(find.text('Saqlash va chop etish'));
      await tester.tap(find.text('Saqlash va chop etish'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(find.byType(ServerPickerPage), findsNothing);
      await tester.ensureVisible(find.byTooltip('Rulonni olib tashlash').last);
      await tester.tap(find.byTooltip('Rulonni olib tashlash').last);
      await tester.pumpAndSettle();
      await _submitWidth(tester, 0, '600');
      await _tapAddRoll(tester);
      await tester.enterText(weights.at(1), '7');
      await _submitWidth(tester, 0, '700');
      expect(widths, findsNWidgets(2)); // A partial draft is not empty.
      expect(tester.widget<TextField>(weights.at(1)).controller!.text, '7');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.method == 'POST') saves++;
              if (request.url.path.endsWith('/source')) {
                return _json({..._source, 'width_mm': sourceWidth});
              }
              return _json({
                'warehouses': ['Raw W'],
                'history': []
              });
            }));
  });
  test('independent role, home, admin kind and fail closed route', () {
    expect(userRoleFromJson('homashyo_rezkachi'), UserRole.homashyoRezkachi);
    expect(userRoleToJson(UserRole.homashyoRezkachi), 'homashyo_rezkachi');
    expect(SessionProfile.fromJson(_profile.toJson()).accessRole,
        UserRole.homashyoRezkachi);
    expect(AppSession.instance.homeRoute, AppRoutes.rawMaterialSplit);
    expect(AppRouter.canOpenRoute(AppRoutes.rawMaterialSplit), isTrue);
    expect(AppRouter.canOpenRoute(AppRoutes.rawMaterialSplitHistory), isTrue);
    expect(AppRouter.canOpenRoute(AppRoutes.rezkaSplit), isFalse);
    expect(AppRouter.canOpenRoute(AppRoutes.apparatusQueue), isFalse);
    final user = AdminUserListEntry.fromJson({
      'id': 'split-1',
      'source': 'system_user',
      'principal_role': 'homashyo_rezkachi',
      'name': 'Cutter',
      'phone': ''
    });
    expect(user.kind, AdminUserKind.homashyoRezkachi);
    expect(user.roleLabel, 'Homashyo rezkachisi');
    AppSession.instance.profile = _profile.copyWith(capabilities: []);
    expect(AppRouter.canOpenRoute(AppRoutes.rawMaterialSplit), isFalse);
    expect(AppRouter.canOpenRoute(AppRoutes.rawMaterialSplitHistory), isFalse);
    AppSession.instance.profile = _profile.copyWith(role: UserRole.aparatchi);
    expect(AppRouter.canOpenRoute(AppRoutes.rawMaterialSplit), isFalse);
    expect(AppRouter.canOpenRoute(AppRoutes.rawMaterialSplitHistory), isFalse);
  });
  test('exact six-place quantities and immutable result validation', () {
    expect(rawSplitQuantity('0,1') + rawSplitQuantity('0.2'),
        rawSplitQuantity('0.3'));
    expect(rawSplitDecimal(rawSplitQuantity('999999999999.999999')),
        '999999999999.999999');
    expect(rawSplitDisplay('100.000000'), '100');
    expect(rawSplitDisplay('0.000000'), '0');
    expect(RawSplitResult.fromJson(_result).outputs.map((o) => o.kg),
        ['39', '59']);
    for (final bad in ['NaN', '-1', '0', '1e2', '1.0000001', '9999999999999']) {
      expect(() => rawSplitQuantity(bad), throwsFormatException);
    }
    expect(() => RawSplitResult.fromJson({..._result, 'output_kg': '100'}),
        throwsFormatException);
    expect(
        () => RawSplitResult.fromJson({
              ..._result,
              'outputs': [_result['outputs'][0], _result['outputs'][0]]
            }),
        throwsFormatException);
  });
  test('split labels replace source dimensions and preserve measured weights',
      () {
    final roll = RawSplitRoll.fromJson({
      ..._source,
      'item_name': 'BOPP METAL 700/12',
      'barcode': '300000000000000000000001',
      'width_mm': '350',
      'micron': '12',
      'kg': '3',
      'gross_kg': '3.5',
      'bobina_kg': '0.5',
    });
    final label = rawMaterialSplitPrintRequest(roll);
    expect(label.itemName, 'BOPP METAL 350/12');
    expect(label.grossQty, 3.5);
    expect(label.tareKg, 0.5);
    expect(label.netQty, 3);
    expect(label.tareEnabled, isTrue);
    final zpl = utf8.decode(ZebraRpsRenderer.render(label));
    expect(zpl, contains('BOPP METAL 350/12'));
    expect(zpl, contains('B:3.5 kg N:3 kg'));
    expect(zpl, isNot(contains('700/12')));
    final noCore = rawMaterialSplitPrintRequest(RawSplitRoll.fromJson({
      ..._source,
      'gross_kg': '100',
      'bobina_kg': '0',
    }));
    expect(noCore.materialProductLabelTitle, contains('B:100 kg N:100 kg'));
    final legacy = rawMaterialSplitPrintRequest(RawSplitRoll.fromJson(_source));
    expect(legacy.tareEnabled, isFalse);
    expect(legacy.materialProductLabelTitle, isNot(contains('B:')));
    expect(
        () => RawSplitRoll.fromJson({
              ..._source,
              'gross_kg': '101',
              'bobina_kg': '2',
            }),
        throwsFormatException);
  });
  testWidgets(
      'measured split sends net stock and prints gross core and child dimensions',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const channel = MethodChannel('accord/bluetooth_printer');
    final printed = <Map<Object?, Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'printLabel') {
        printed.add(Map<Object?, Object?>.from(call.arguments as Map));
      }
      return {'ok': true, 'status': 'done'};
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final source = {
      ..._source,
      'item_name': 'BOPP METAL 800/12',
      'kg': '12',
      'width_mm': '800',
      'micron': '12'
    };
    final result = {
      ..._result,
      'source': source,
      'source_kg': '12',
      'output_kg': '11',
      'waste_kg': '1',
      'outputs': [
        {
          ...source,
          'stock_id': 'child1',
          'barcode': '300000000000000000000001',
          'width_mm': '400',
          'kg': '5',
          'gross_kg': '6',
          'bobina_kg': '1'
        },
        {
          ...source,
          'stock_id': 'child2',
          'barcode': '300000000000000000000002',
          'width_mm': '400',
          'kg': '6',
          'gross_kg': '6.5',
          'bobina_kg': '0.5'
        },
      ],
    };
    var saves = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RawMaterialSplitScreen(),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'parent');
      await tester.tap(find.byTooltip('Rulonni topish'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await _submitWidth(tester, i, '400');
        if (i == 0) await _tapAddRoll(tester);
        await tester.enterText(
            find.widgetWithText(TextField, 'Og‘irlik (kg)').at(i),
            i == 0 ? '6' : '6.5');
        await tester.enterText(
            find.widgetWithText(TextField, 'Babina (kg)').at(i),
            i == 0 ? '1' : '0.5');
      }
      await tester.enterText(
          find.widgetWithText(TextField, 'Atxot (kg) *'), '1');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Netto: 5 kg'), findsOneWidget);
      expect(find.text('Netto: 6 kg'), findsOneWidget);
      await tester.tap(find.byTooltip('Printer tanlash'));
      await tester.pumpAndSettle();
      tester
          .widget<ServerPickerPage>(find.byType(ServerPickerPage))
          .onSelectBluetooth(const BluetoothPrinterProfile(
              name: 'XP-P323B', address: '00:11:22:33:44:55'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Saqlash va chop etish'));
      await tester.tap(find.text('Saqlash va chop etish'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(printed, hasLength(2));
      expect(printed[0], containsPair('item_name', 'BOPP METAL 400/12'));
      expect(printed[0], containsPair('gross_qty', 6.0));
      expect(printed[0], containsPair('tare_kg', 1.0));
      expect(printed[0], containsPair('tare_enabled', true));
      expect(printed[1], containsPair('gross_qty', 6.5));
      expect(printed[1], containsPair('tare_kg', 0.5));
      expect(printed[0]['epc'], isNot(printed[1]['epc']));
      expect(await MobileApi.instance.rawSplitPending(), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                expect(request.url.path, '/v1/mobile/raw-material-split/split');
                saves++;
                final payload = jsonDecode(request.body) as Map;
                expect(payload['waste_kg'], '1.000000');
                expect(payload['outputs'], [
                  {
                    'kg': '5.000000',
                    'width_mm': '400.000000',
                    'gross_kg': '6.000000',
                    'bobina_kg': '1.000000'
                  },
                  {
                    'kg': '6.000000',
                    'width_mm': '400.000000',
                    'gross_kg': '6.500000',
                    'bobina_kg': '0.500000'
                  },
                ]);
                return _json(result);
              }
              if (request.url.path.endsWith('/source')) return _json(source);
              return _json({
                'warehouses': ['Raw W'],
                'history': saves == 0 ? [] : [result]
              });
            }));
  });
  test('lost response survives restart and reuses exactly the saved command',
      () async {
    final bodies = <String>[];
    await http.runWithClient(() async {
      final command = _payload();
      await expectLater(MobileApi.instance.rawSplitSave(command),
          throwsA(isA<http.ClientException>()));
      final pending = await MobileApi.instance.rawSplitPending();
      expect(pending, command);
      await expectLater(
          MobileApi.instance.rawSplitSave(_payload()), throwsStateError);
      final result = await MobileApi.instance.rawSplitSave(pending!);
      expect(result.id, 'split-result');
      expect(bodies[0], bodies[1]);
      expect(await MobileApi.instance.rawSplitPending(), isNull);
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer token');
              bodies.add(request.body);
              if (bodies.length == 1) {
                throw http.ClientException('lost response');
              }
              return _json(_result);
            }));
  });
  test(
      'malformed success and proxy failure preserve retry; domain rejection clears it',
      () async {
    var response = _json({'id': 'incomplete'});
    await http.runWithClient(() async {
      final command = _payload();
      await expectLater(
          MobileApi.instance.rawSplitSave(command), throwsA(anything));
      expect(await MobileApi.instance.rawSplitPending(), isNotNull);
      response = http.Response('gateway timeout', 504);
      await expectLater(MobileApi.instance.rawSplitSave(command),
          throwsA(isA<MobileApiException>()));
      expect(await MobileApi.instance.rawSplitPending(), isNotNull);
      response =
          _json({'code': 'raw_split_conflict', 'error': 'Rulon band'}, 409);
      await expectLater(MobileApi.instance.rawSplitSave(command),
          throwsA(isA<MobileApiException>()));
      expect(await MobileApi.instance.rawSplitPending(), isNull);
    }, () => MockClient((_) async => response));
  });
  test('uncertain commands are isolated per account', () async {
    await http.runWithClient(() async {
      await expectLater(MobileApi.instance.rawSplitSave(_payload()),
          throwsA(isA<http.ClientException>()));
      AppSession.instance.profile = _profile.copyWith(ref: 'split-2');
      expect(await MobileApi.instance.rawSplitPending(), isNull);
      AppSession.instance.profile = _profile;
      expect(await MobileApi.instance.rawSplitPending(), isNotNull);
    }, () => MockClient((_) async => throw http.ClientException('offline')));
  });
  test('parallel saves blocked; auth denial keeps retry key', () async {
    final started = Completer<void>(), finish = Completer<void>();
    var requests = 0;
    await http.runWithClient(() async {
      final command = _payload();
      final first = expectLater(MobileApi.instance.rawSplitSave(command),
          throwsA(isA<MobileApiException>()));
      await started.future;
      await expectLater(
          MobileApi.instance.rawSplitSave(command), throwsStateError);
      finish.complete();
      await first;
      expect(requests, 1);
      expect(await MobileApi.instance.rawSplitPending(), isNotNull);
    },
        () => MockClient((_) async {
              requests++;
              started.complete();
              await finish.future;
              return _json({'error': 'forbidden'}, 403);
            }));
  });
  test('printer failure and reprint do not submit stock again', () async {
    var saves = 0, prints = 0;
    await http.runWithClient(() async {
      await MobileApi.instance.rawSplitSave(_payload());
      Future<void> print() => MobileApi.instance.rawSplitPrint(
          splitId: 'split-result',
          barcode: 'child1',
          driverUrl: 'http://printer',
          printer: 'godex',
          printMode: 'label');
      await expectLater(print(), throwsA(isA<MobileApiException>()));
      await print();
      expect(saves, 1);
      expect(prints, 2);
      expect(await MobileApi.instance.rawSplitPending(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/split')) {
                saves++;
                return _json(_result);
              }
              expect(request.url.path, '/v1/mobile/raw-material-split/print');
              expect((jsonDecode(request.body) as Map).containsKey('outputs'),
                  isFalse);
              prints++;
              return prints == 1
                  ? _json({'error': 'printer offline'}, 502)
                  : _json({'ok': true, 'status': 'done', 'barcode': 'child1'});
            }));
  });
  testWidgets('scan lookup and measured weights show 98 stock plus 2 waste',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var saves = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: RawMaterialSplitScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'parent');
      await tester.tap(find.byTooltip('Rulonni topish'));
      await tester.pumpAndSettle();
      final weights = find.widgetWithText(TextField, 'Og‘irlik (kg)');
      final bobinas = find.widgetWithText(TextField, 'Babina (kg)');
      await _submitWidth(tester, 0, '400');
      await _tapAddRoll(tester);
      await _submitWidth(tester, 1, '600');
      expect(find.text('En to‘liq taqsimlandi'), findsOneWidget);
      expect(find.text('Atxotga ketadi: 0 mm'), findsOneWidget);
      await tester.enterText(weights.at(0), '40');
      await tester.enterText(weights.at(1), '60');
      await tester.enterText(bobinas.at(0), '1');
      await tester.enterText(bobinas.at(1), '1');
      // Waste is required, and a balanced net total cannot make zero valid.
      expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Atxot (kg) *'))
              .controller!
              .text,
          isEmpty);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Saqlash va chop etish'));
      await tester.tap(find.text('Saqlash va chop etish'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Atxot kg ni kiriting'), findsOneWidget);
      expect(saves, 0);
      expect(find.widgetWithText(TextField, 'Brutto (kg)'), findsNothing);
      expect(find.widgetWithText(TextField, 'Netto (kg)'), findsNothing);
      await tester.enterText(weights.at(0), '42');
      for (final zero in ['0', '0.000000', '0,0']) {
        await tester.enterText(
            find.widgetWithText(TextField, 'Atxot (kg) *'), zero);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(find.textContaining('Hisob teng ✓'), findsNothing);
        await tester.ensureVisible(find.text('Saqlash va chop etish'));
        await tester.tap(find.text('Saqlash va chop etish'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Atxot 0 dan katta bo‘lishi kerak'),
            findsOneWidget);
        expect(find.byType(ServerPickerPage), findsNothing);
        expect(saves, 0);
      }
      await tester.enterText(weights.at(0), '40');
      await tester.enterText(
          find.widgetWithText(TextField, 'Atxot (kg) *'), '2');
      await tester.pump();
      expect(find.textContaining('Chiqish: 98 kg · Chiqindi: 2 kg'),
          findsOneWidget);
      expect(find.textContaining('Hisob teng ✓'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.text('Netto: 39 kg'), findsOneWidget);
      expect(find.text('Netto: 59 kg'), findsOneWidget);
      await tester.enterText(weights.at(0), '40.000001');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Saqlash va chop etish'));
      await tester.tap(find.text('Saqlash va chop etish'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(find.textContaining('Asl vazndan 0.000001 kg oshib ketdi'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                saves++;
                return _json(_result);
              }
              if (request.url.path.endsWith('/source')) return _json(_source);
              return _json({
                'warehouses': ['Raw W'],
                'history': []
              });
            }));
  });
  testWidgets('simple Rezka header, spaced scan and shared device picker',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          AppRoutes.profile: (_) =>
              const Scaffold(body: Text('Opened cutter profile')),
          AppRoutes.rawMaterialSplitHistory: (_) =>
              const RawMaterialSplitHistoryScreen(),
        },
        home: const RawMaterialSplitScreen(),
      ));
      await tester.pumpAndSettle();
      final action = find.byType(AppShellProfileAction);
      expect(action, findsOneWidget);
      expect(find.ancestor(of: action, matching: find.byType(AppBar)),
          findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Rezka'), findsOneWidget);
      expect(find.text('Rezka'), findsNWidgets(2));
      expect(find.text('Homashyo rezka'), findsNothing);
      expect(find.text('Homashyo rezkachisi'), findsNothing);
      expect(find.text('Ishlab chiqarishdan oldingi rezka'), findsNothing);
      expect(find.byTooltip('Yangilash'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(find.text('Bo‘lish tarixi'), findsNothing);
      expect(find.text('Printer tanlanmagan'), findsNothing);
      final fieldRect = tester.getRect(find.byType(TextField));
      final scanRect =
          tester.getRect(find.widgetWithText(OutlinedButton, 'Skanerlash'));
      expect(scanRect.top - fieldRect.bottom, greaterThanOrEqualTo(12));
      expect(scanRect.width, fieldRect.width);
      expect(scanRect.height, greaterThanOrEqualTo(48));
      final connect = find.byType(DevicePickerIcon);
      expect(find.ancestor(of: connect, matching: find.byType(AppBar)),
          findsOneWidget);
      expect(tester.widget<DevicePickerIcon>(connect).attention, isTrue);
      await tester.tap(find.byTooltip('Printer tanlash'));
      await tester.pumpAndSettle();
      expect(find.byType(ServerPickerPage), findsOneWidget);
      expect(find.text('USB'), findsOneWidget);
      expect(find.text('Bluetooth'), findsOneWidget);
      expect(find.text('Wi-Fi'), findsOneWidget);
      Navigator.of(tester.element(find.byType(ServerPickerPage))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rezka tarixi'));
      await tester.pumpAndSettle();
      expect(find.byType(RawMaterialSplitHistoryScreen), findsOneWidget);
      expect(find.text('Rezka tarixi'), findsOneWidget);
      await tester.tap(find.byTooltip('Orqaga'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Opened cutter profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((_) async => _json({
              'warehouses': ['Raw W'],
              'history': [],
            })));
  });
  testWidgets('flat form and history fit a narrow screen and keep roll actions',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RawMaterialSplitHistoryScreen(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('child1'), findsOneWidget);
      expect(find.text('child2'), findsOneWidget);
      expect(find.byTooltip('Shu rulonni qayta chop etish'), findsNWidgets(2));
      expect(find.byType(Card), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RawMaterialSplitScreen(),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'parent');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('1-rulon'), findsOneWidget);
      expect(find.text('2-rulon'), findsNothing);
      final widths = find.widgetWithText(TextField, 'Eni (mm)');
      final weights = find.widgetWithText(TextField, 'Og‘irlik (kg)');
      expect(
          tester.getRect(weights.first).left -
              tester.getRect(widths.first).right,
          greaterThanOrEqualTo(12));
      await _submitWidth(tester, 0, '400');
      await _tapAddRoll(tester);
      expect(widths, findsNWidgets(2));
      await _submitWidth(tester, 1, '600');
      expect(widths, findsNWidgets(2));
      await tester.ensureVisible(find.byTooltip('Rulonni olib tashlash').last);
      await tester.tap(find.byTooltip('Rulonni olib tashlash').last);
      await tester.pumpAndSettle();
      expect(widths, findsOneWidget);
      await tester.ensureVisible(find.text('Saqlash va chop etish'));
      await tester.pumpAndSettle();
      expect(find.text('Saqlash va chop etish').hitTestable(), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/source')) return _json(_source);
              return _json({
                'warehouses': ['Raw W'],
                'history': [_result],
              });
            }));
  });
}
