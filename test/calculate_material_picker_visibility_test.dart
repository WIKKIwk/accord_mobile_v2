import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/navigation/app_root_navigation.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/m3_segmented_list.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/m3_sequence_list.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_calculate_materials_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_calculate_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_drawer_navigation.dart';
import 'package:accord_mobile_v2/src/features/admin/state/calculate_order_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/widgets/m3_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestModeController.instance.setEnabled(true);
    resetMobileApiCalculateTestModeData();
    M3AsyncPickerSheet.clearMemoryCache();
    await CalculateOrderTemplateStore.instance.debugReset();
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
    );
  });

  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    M3AsyncPickerSheet.clearMemoryCache();
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets(
      'material drag persists, hidden rows stay fixed, picker uses order',
      (tester) async {
    await TestModeController.instance.setEnabled(false);
    var materials = <CalculateMaterial>[
      _material('pet', 'PET'),
      _material('cpp', 'CPP'),
      _material('bopp', 'BOPP', active: false),
    ];
    final writes = <List<String>>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/calculate-materials/sequence')) {
        final ids =
            (jsonDecode(request.body)['material_ids'] as List).cast<String>();
        writes.add(ids);
        expect(ids, isNot(contains('bopp')));
        materials = [
          for (final id in ids)
            materials.firstWhere((material) => material.id == id),
          ...materials.where((material) => !material.active),
        ];
        return http.Response(
            jsonEncode(
                {'materials': materials.map((item) => item.toJson()).toList()}),
            200);
      }
      if (request.url.path.endsWith('/calculate-materials')) {
        return http.Response(
            jsonEncode(
                {'materials': materials.map((item) => item.toJson()).toList()}),
            200);
      }
      return http.Response('{"templates":[]}', 200);
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      final navigator = await _pumpOrderForm(tester);
      void openManager() => AdminDrawerNavigation.openRoute(
            tester.element(find.byType(AdminCalculateScreen)),
            AppRoutes.adminCalculateMaterials,
          );
      openManager();
      await tester.pumpAndSettle();
      final sequence =
          tester.widget<M3SequenceList>(find.byType(M3SequenceList));
      expect(sequence.itemCount, 3);
      expect(sequence.reorderableItemCount, 2);
      expect(find.byType(M3SegmentFilledSurface), findsNWidgets(3));
      expect(find.textContaining('g/cm³'), findsNothing);
      expect(find.textContaining('mkr'), findsNothing);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('material-bopp')),
              matching: find.byType(ReorderableDragStartListener)),
          findsNothing);
      expect(tester.getCenter(find.text('BOPP')).dy,
          greaterThan(tester.getCenter(find.text('CPP')).dy));

      await _dragMaterial(tester, 'CPP', 'PET', upward: true);
      expect(writes, [
        ['cpp', 'pet']
      ]);
      expect(tester.getCenter(find.text('CPP')).dy,
          lessThan(tester.getCenter(find.text('PET')).dy));
      // Downward moves also use the final destination index directly.
      await _dragMaterial(tester, 'CPP', 'PET', upward: false);
      expect(writes.last, ['pet', 'cpp']);
      await _dragMaterial(tester, 'CPP', 'PET', upward: true);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      openManager();
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('CPP')).dy,
          lessThan(tester.getCenter(find.text('PET')).dy));
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await _openMaterialPicker(tester);
      expect(_pickerMaterial('BOPP'), findsNothing);
      expect(tester.getCenter(_pickerMaterial('CPP')).dy,
          lessThan(tester.getCenter(_pickerMaterial('PET')).dy));
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
    }, () => client);
  });

  testWidgets('failed sequence save restores persisted order', (tester) async {
    await TestModeController.instance.setEnabled(false);
    final materials = [_material('pet', 'PET'), _material('cpp', 'CPP')];
    var writes = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/calculate-materials/sequence')) {
        writes++;
        return http.Response('{"error":"unavailable"}', 503);
      }
      if (request.url.path.endsWith('/calculate-materials')) {
        return http.Response(
            jsonEncode(
                {'materials': materials.map((item) => item.toJson()).toList()}),
            200);
      }
      return http.Response('{"templates":[]}', 200);
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      final navigator = await _pumpOrderForm(tester);
      AdminDrawerNavigation.openRoute(
          tester.element(find.byType(AdminCalculateScreen)),
          AppRoutes.adminCalculateMaterials);
      await tester.pumpAndSettle();
      await _dragMaterial(tester, 'CPP', 'PET', upward: true);
      expect(writes, 1);
      expect(tester.getCenter(find.text('PET')).dy,
          lessThan(tester.getCenter(find.text('CPP')).dy));
      expect(
          tester
              .widget<M3SequenceDragHandle>(
                  find.byType(M3SequenceDragHandle).first)
              .enabled,
          isTrue);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
    }, () => client);
  });

  testWidgets('all hidden materials have no movable rows', (tester) async {
    for (final material in await MobileApi.instance.calculateMaterials()) {
      await MobileApi.instance
          .upsertCalculateMaterial(material.copyWith(active: false));
    }
    final navigator = await _pumpOrderForm(tester);
    AdminDrawerNavigation.openRoute(
        tester.element(find.byType(AdminCalculateScreen)),
        AppRoutes.adminCalculateMaterials);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<M3SequenceList>(find.byType(M3SequenceList))
            .reorderableItemCount,
        0);
    expect(find.byType(M3SequenceDragHandle), findsNothing);
    expect(find.byType(ReorderableDragStartListener), findsNothing);
    expect(find.text('BOPP'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('disabling another material pins it after existing hidden rows',
      (tester) async {
    final materials = await MobileApi.instance.calculateMaterials();
    await MobileApi.instance.upsertCalculateMaterial(
      materials
          .firstWhere((material) => material.name == 'BOPP')
          .copyWith(active: false),
    );
    final navigator = await _pumpOrderForm(tester);
    AdminDrawerNavigation.openRoute(
        tester.element(find.byType(AdminCalculateScreen)),
        AppRoutes.adminCalculateMaterials);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CPP'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    final save = find.widgetWithText(FilledButton, 'Saqlash');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final saved = await MobileApi.instance.calculateMaterials();
    expect(saved.last.name, 'CPP');
    expect(saved[saved.length - 2].name, 'BOPP');
    expect(tester.getCenter(find.text('CPP')).dy,
        greaterThan(tester.getCenter(find.text('BOPP')).dy));
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('material-builtin-cpp')),
            matching: find.byType(ReorderableDragStartListener)),
        findsNothing);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'saved visibility applies when returning through drawer navigation',
      (tester) async {
    final navigator = await _pumpOrderForm(tester);
    final orderState = tester.state(find.byType(AdminCalculateScreen));
    await _openMaterialPicker(tester);
    expect(_pickerMaterial('BOPP'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    for (final active in [false, true]) {
      AdminDrawerNavigation.openRoute(
        tester.element(find.byType(AdminCalculateScreen)),
        AppRoutes.adminCalculateMaterials,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BOPP'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Saqlash');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final materials = await MobileApi.instance.calculateMaterials();
      expect(
          materials.firstWhere((item) => item.name == 'BOPP').active, active);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(AdminCalculateScreen)), same(orderState));

      await _openMaterialPicker(tester);
      expect(_pickerMaterial('CPP'), findsOneWidget);
      if (active) {
        await tester.enterText(find.byType(SearchBar), 'BOPP');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }
      expect(_pickerMaterial('BOPP'), active ? findsOneWidget : findsNothing);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('failed refresh offers retry instead of an old material list',
      (tester) async {
    await TestModeController.instance.setEnabled(false);
    var unavailable = false;
    var active = true;
    final client = MockClient((request) async {
      if (request.url.path == '/v1/mobile/admin/calculate-materials') {
        if (unavailable) {
          return http.Response('{"error":"unavailable"}', 503);
        }
        return http.Response(
          jsonEncode({
            'materials': [
              {
                'id': 'bopp',
                'name': 'BOPP',
                'active': active,
                'density_g_cm3': 0.905,
                'variants': [
                  {'micron': 18},
                ],
              },
            ],
          }),
          200,
        );
      }
      return http.Response('{"templates":[]}', 200);
    });
    addTearDown(client.close);

    await http.runWithClient(() async {
      final navigator = await _pumpOrderForm(tester);
      await _openMaterialPicker(tester);
      expect(_pickerMaterial('BOPP'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      unavailable = true;
      await _openMaterialPicker(tester);
      expect(_pickerMaterial('BOPP'), findsNothing);
      final retry = find.widgetWithText(FilledButton, 'Qayta urinish');
      expect(retry, findsOneWidget);

      unavailable = false;
      active = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(retry, findsNothing);
      expect(_pickerMaterial('BOPP'), findsNothing);
      expect(find.byType(SearchBar), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
    }, () => client);
  });
}

CalculateMaterial _material(String id, String name, {bool active = true}) =>
    CalculateMaterial(
        id: id,
        name: name,
        active: active,
        densityGCm3: 0.905,
        variants: const [CalculateMaterialVariant(micron: 20)]);

Future<void> _dragMaterial(WidgetTester tester, String name, String target,
    {required bool upward}) async {
  final row = find.ancestor(
      of: find.text(name), matching: find.byType(M3SegmentFilledSurface));
  final handle =
      find.descendant(of: row, matching: find.byType(M3SequenceDragHandle));
  final targetCenter = tester.getCenter(find.text(target));
  final start = tester.getCenter(handle);
  final gesture = await tester.startGesture(start);
  await gesture.moveBy(Offset(0, upward ? -24 : 24));
  await tester.pump(const Duration(milliseconds: 250));
  await gesture.moveTo(Offset(start.dx, targetCenter.dy - (upward ? 0 : 20)));
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<GlobalKey<NavigatorState>> _pumpOrderForm(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final navigator = GlobalKey<NavigatorState>();
  addTearDown(() async {
    navigator.currentState?.popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
  });
  await tester.pumpWidget(MaterialApp(
    navigatorKey: navigator,
    navigatorObservers: [AppRootNavigation.navigatorObserver],
    theme: ThemeData(useMaterial3: true),
    locale: const Locale('uz'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const AdminCalculateScreen(),
    routes: {
      AppRoutes.adminCalculateMaterials: (_) =>
          const AdminCalculateMaterialsScreen(),
    },
  ));
  await tester.pumpAndSettle();
  return navigator;
}

Future<void> _openMaterialPicker(WidgetTester tester) async {
  final field = find.byWidgetPredicate((widget) =>
      widget is InputDecorator && widget.decoration.labelText == '1-qavat');
  await tester.scrollUntilVisible(
    field,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(field);
  await tester.pumpAndSettle();
}

Finder _pickerMaterial(String name) => find.descendant(
      of: find.byType(M3AsyncPickerSheet<CalculateMaterial>),
      matching: find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == name,
      ),
    );
