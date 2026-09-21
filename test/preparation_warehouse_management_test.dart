import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/m3_segmented_list.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget screen(List<String> warehouses,
        {Future<void> Function()? reload, void Function(String)? select}) =>
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: PreparationWarehouseScreen(
        warehouses: warehouses,
        assignedWarehouses: warehouses,
        materialWarehouses: const ['Own', 'Child'],
        initialWarehouse: 'Child',
        materials: const [],
        history: const [],
        locked: false,
        onWarehouseSelected: select ?? (_) {},
        onReceive: (_) async {},
        onCreateMaterial: (_) async {},
        onReload: reload ?? () async {},
        freshMaterials: () => [],
        freshHistory: () => [],
        freshAssignedWarehouses: () => warehouses,
        freshMaterialWarehouses: () =>
            warehouses.where((w) => w != 'Shared').toList(),
        freshManagedWarehouses: () =>
            warehouses.where((w) => w != 'Shared' && w != 'Own').toList(),
      ),
    );

Future<void> openActions(WidgetTester tester) async {
  await tester
      .tap(find.byKey(const ValueKey('preparation-warehouse-filter-chip')));
  await tester.pumpAndSettle();
  await tester.longPress(find.text('Child'));
  await tester.pumpAndSettle();
  expect(find.text('Nomini o‘zgartirish'), findsOneWidget);
  expect(
      find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(M3SegmentFilledSurface)),
      findsNWidgets(2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.tayyorlovMasteri,
        displayName: 'Master',
        legalName: '',
        ref: 'prep-1',
        phone: '',
        avatarUrl: '',
        capabilities: ['preparation.access']);
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('long press renames own child and refreshes selected warehouse',
      (tester) async {
    final warehouses = ['Own', 'Child', 'Shared'];
    String? selected;
    var calls = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(screen(warehouses,
          select: (w) => selected = w,
          reload: () async {
            warehouses[1] = 'Renamed';
          }));
      await tester.pumpAndSettle();
      await openActions(tester);
      expect(selected, isNull); // A long press must not also select the chip.
      await tester.tap(find.text('Nomini o‘zgartirish'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          'Child');
      await tester.enterText(find.byType(TextFormField), 'Renamed');
      await tester.tap(find.text('Saqlash'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(selected, 'Renamed');
      expect(find.text('Ombor nomi o‘zgartirildi'), findsOneWidget);
      expect(find.text('Child'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              calls++;
              expect(request.method, 'PATCH');
              expect(request.url.path, '/v1/mobile/preparation/warehouses');
              expect(jsonDecode(request.body),
                  {'warehouse': 'Child', 'name': 'Renamed'});
              return http.Response('{"warehouse":"Renamed"}', 200);
            }));
  });

  for (final reject in [false, true]) {
    testWidgets(
        'delete child confirms, reject=$reject preserves material warehouse',
        (tester) async {
      final warehouses = ['Own', 'Child', 'Shared'];
      var calls = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(screen(warehouses, reload: () async {
          warehouses.remove('Child');
        }));
        await tester.pumpAndSettle();
        await openActions(tester);
        await tester.tap(find.text('O‘chirish'));
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(find.text('Omborni o‘chirish'), findsOneWidget);
        await tester.tap(find.text('O‘chirish'));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(warehouses.contains('Child'), reject);
        expect(
            find.text(reject
                ? 'Omborda homashyo yoki mahsulot bor. Avval ularni boshqa omborga ko‘chiring'
                : 'Ombor o‘chirildi'),
            findsOneWidget);
        expect(find.textContaining('dhsjkl'), findsNothing);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                calls++;
                expect(request.method, 'DELETE');
                expect(request.url.queryParameters, {'warehouse': 'Child'});
                return reject
                    ? http.Response(
                        '{"code":"preparation_warehouse_not_empty","error":"dhsjkl"}',
                        409)
                    : http.Response(
                        '{"warehouse":"Child","deleted":true}', 200);
              }));
    });
  }

  testWidgets(
      'root/shared long presses have no management menu; parent dropdown only exclusive',
      (tester) async {
    await tester.pumpWidget(screen(['Own', 'Child', 'Shared']));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('preparation-warehouse-filter-chip')));
    await tester.pumpAndSettle();
    for (final name in ['Own', 'Shared']) {
      if (find.text(name).evaluate().isEmpty) {
        await tester.tap(
            find.byKey(const ValueKey('preparation-warehouse-filter-chip')));
        await tester.pumpAndSettle();
      }
      await tester.longPress(find.text(name));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    }
    await tester
        .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ombor qo‘shish'));
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('preparation-warehouse-parent')));
    // Inspect rendered dropdown entries, not just the selected initial value.
    expect(dropdown, isNotNull);
    await tester
        .tap(find.byKey(const ValueKey('preparation-warehouse-parent')));
    await tester.pumpAndSettle();
    final items = tester.widgetList<DropdownMenuItem<String>>(
        find.byType(DropdownMenuItem<String>));
    expect(items.map((item) => item.value).toSet(), {'Own', 'Child'});
    expect(tester.takeException(), isNull);
  });

  for (final code in [
    'preparation_warehouse_name_taken',
    'preparation_warehouse_not_exclusive',
    'unknown'
  ]) {
    test('warehouse errors are readable: $code', () async {
      await http.runWithClient(() async {
        await expectLater(
            MobileApi.instance
                .preparationRenameWarehouse(warehouse: 'Child', name: 'Own'),
            throwsA(isA<MobileApiException>().having(
                (e) => e.message,
                'readable message',
                allOf(
                    isNot(contains('dhsjkl')),
                    contains(code == 'preparation_warehouse_name_taken'
                        ? 'Bunday nomli ombor mavjud'
                        : code == 'preparation_warehouse_not_exclusive'
                            ? 'eksklyuziv'
                            : 'qayta urinib')))));
      },
          () => MockClient((_) async => http.Response(
              jsonEncode({'code': code, 'error': 'dhsjkl'}), 409)));
    });
  }
}
