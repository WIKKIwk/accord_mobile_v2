import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/production_map_pechat_rules.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/production_map_edit_policy.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_test_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/raw_material_scan_dialog.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
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

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    setMobileApiTestModeForceProductionMapMenuLoadFailure(false);
  });

  test('admin apparatus groups normalize default bosma names', () async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveApparatusGroup(
      const AdminApparatusGroup(
        name: 'pechat',
        apparatus: [
          '7 ta rangli pechat',
          '8 ta rangli pechat',
          '9 ta rangli pechat',
        ],
      ),
    );

    final groups = await MobileApi.instance.adminApparatusGroups();
    final bosmaGroups = groups
        .where((group) => group.name == 'Bosma aparat')
        .toList(growable: false);

    expect(bosmaGroups, hasLength(1));
    expect(bosmaGroups.single.apparatus, [
      '7 ta rangli bosma aparat',
      '8 ta rangli bosma aparat',
      '9 ta rangli bosma aparat',
      'Flexo pechat',
    ]);
    expect(groups.any((group) => group.name == 'pechat'), isFalse);
  });

  test('flexo-only apparatus group normalizes to bosma', () async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveApparatusGroup(
      const AdminApparatusGroup(
        name: 'Flexo bosma',
        apparatus: ['Flexo pechat'],
      ),
    );

    final groups = await MobileApi.instance.adminApparatusGroups();
    final bosma = groups.singleWhere((group) => group.name == 'Bosma aparat');
    expect(bosma.apparatus, contains('Flexo pechat'));
  });

  test('started alternative apparatus locks the whole alternative group', () {
    const map = ProductionMapDefinition(
      id: 'zakaz-edit-policy-group',
      productCode: 'EDIT-GROUP',
      title: 'Edit group',
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(
          id: 'seven-color',
          kind: 'apparatus',
          title: '7 ta rangli bosma aparat',
          alternativeGroupId: 'bosma',
          alternativeAssignedTitle: '7 ta rangli bosma aparat',
        ),
        ProductionMapNode(
          id: 'eight-color',
          kind: 'apparatus',
          title: '8 ta rangli bosma aparat',
          alternativeGroupId: 'bosma',
          alternativeAssignedTitle: '7 ta rangli bosma aparat',
        ),
        ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
      ],
      edges: [],
    );

    final locked = productionMapLockedNodeIds(
      map: map,
      queueStatesByApparatus: const {
        '7 ta rangli bosma aparat': {
          'zakaz-edit-policy-group': 'completed',
        },
      },
    );

    expect(locked, {'seven-color', 'eight-color'});
  });

  testWidgets('production map page can add and select an apparatus node', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapMapTool(tester, 'Aparat');
    await tester.pumpAndSettle();
    expect(find.text('Aparat tanlang'), findsOneWidget);

    await tester.ensureVisible(find.text('Aparat tanlang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aparat tanlang'));
    await tester.pumpAndSettle();
    expect(find.text('Aparat tanlang'), findsWidgets);

    await tester.tap(find.text('Godex aparat - DEMO').last);
    await tester.pumpAndSettle();

    expect(find.text('Godex aparat - DEMO'), findsWidgets);
  });

  testWidgets('production map opened from zakaz uses linear apparatus flow', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.25),
          ),
          child: child!,
        ),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            orderName: 'Zenit order',
            productName: 'zenit frutto ninja 70gr',
            itemCode: 'ITEM-001',
            rollCount: 7,
            widthMm: 650,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Zenit order'), findsOneWidget);
    expect(find.text('zenit frutto ninja 70gr'), findsOneWidget);
    expect(find.text('CPP hisob'), findsNothing);
    expect(find.text('Katta partiyami?'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Element qo‘shish'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin-fab-menu-Bosma aparat')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('admin-fab-menu-Rezka')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-fab-menu-kk li mahsulot')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('admin-fab-menu-Formula')), findsNothing);
    expect(
      find.byKey(const ValueKey('admin-fab-menu-Condition')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('admin-fab-menu-Ishlov')), findsOneWidget);
  });

  testWidgets('quick order map save clears alternative assignment state', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    final template = CalculateOrderTemplate(
      id: 'quick-template-1',
      code: '4444',
      name: 'Quick template',
      savedAt: DateTime.fromMillisecondsSinceEpoch(0),
      orderNumber: '4444',
      customerRef: 'CUSTOMER-1',
      customer: 'Customer',
      itemCode: 'ITEM-1',
      product: 'Quick product',
      status: 'rulo',
      materialDisplay: '',
      color: '',
      imageId: '',
      imageName: '',
      imageMime: '',
      imageSizeBytes: 0,
      imageUrl: '',
      widthMm: 650,
      wastePercent: 3,
      rollCount: 7,
      firstLayerMaterial: 'pet',
      firstLayerMicron: '12',
      secondLayerMaterial: '',
      secondLayerMicron: '',
      thirdLayerMaterial: '',
      thirdLayerMicron: '',
      note: '',
      kg: 120,
    );
    const dirtyMap = ProductionMapDefinition(
      id: 'zakaz-template-clean-save',
      productCode: 'ITEM-1',
      title: 'Quick template',
      code: '4444',
      orderNumber: '4444',
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(
          id: 'apparatus-7',
          kind: 'apparatus',
          title: '7 ta rangli bosma aparat',
          alternativeGroupId: 'pechat-group',
          alternativeGroupLabel: 'pechat',
          alternativeAssignedTitle: '8 ta rangli bosma aparat',
        ),
        ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
      ],
      edges: [
        ProductionMapEdge(from: 'start', to: 'apparatus-7'),
        ProductionMapEdge(from: 'apparatus-7', to: 'end'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapTestScreen(
          savedMap: dirtyMap,
          orderContext: ProductionMapOrderContext(
            orderName: 'Quick template',
            productName: 'Quick product',
            itemCode: 'ITEM-1',
            rollCount: 7,
            widthMm: 650,
            templateDraft: template,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('production-map-save')));
    await tester.pumpAndSettle();

    final saved = await MobileApi.instance.adminProductionMap(
      'zakaz-template-clean-save',
    );
    expect(
      saved.map.nodes.every(
        (node) => node.alternativeAssignedTitle.trim().isEmpty,
      ),
      isTrue,
    );
    expect(
      saved.map.nodes
          .firstWhere((node) => node.id == 'apparatus-7')
          .alternativeGroupId,
      'pechat-group',
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('production map read only hides editing controls', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(
          readOnly: true,
          savedMap: ProductionMapDefinition(
            id: 'zakaz-read-only',
            title: 'Read only order',
            productCode: 'ITEM-RO',
            orderNumber: '8888',
            nodes: [
              ProductionMapNode(
                id: 'start',
                kind: 'start',
                title: 'Start',
                x: 420,
                y: 32,
              ),
              ProductionMapNode(
                id: 'apparatus',
                kind: 'apparatus',
                title: 'Pechat',
                x: 420,
                y: 164,
              ),
              ProductionMapNode(
                id: 'end',
                kind: 'end',
                title: 'Read only product',
                itemCode: 'ITEM-RO',
                x: 420,
                y: 296,
              ),
            ],
            edges: [
              ProductionMapEdge(from: 'start', to: 'apparatus'),
              ProductionMapEdge(from: 'apparatus', to: 'end'),
            ],
          ),
          orderContext: ProductionMapOrderContext(
            orderName: 'Read only order',
            productName: 'Read only product',
            itemCode: 'ITEM-RO',
            rollCount: 7,
            widthMm: 650,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('production-map-save')), findsNothing);
    expect(find.bySemanticsLabel('Element qo‘shish'), findsNothing);
    expect(
      find.byKey(const ValueKey('production-map-node-connect-start')),
      findsNothing,
    );
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await tester.tap(find.text('Pechat'));
    await tester.pumpAndSettle();

    expect(find.text('Saqlash'), findsNothing);
  });

  testWidgets('production map canvas pinches over node cards', (tester) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final startFinder = find.text('Start').first;
    final before = tester.getRect(startFinder);
    final center = tester.getCenter(startFinder);
    final first = await tester.createGesture(pointer: 91);
    final second = await tester.createGesture(pointer: 92);
    await first.down(center + const Offset(-18, 0));
    await second.down(center + const Offset(18, 0));
    await tester.pump();
    await first.moveTo(center + const Offset(-92, -34));
    await second.moveTo(center + const Offset(92, 34));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    final after = tester.getRect(startFinder);
    expect(after.width, greaterThan(before.width * 1.08));
  });

  testWidgets('production map node cards drag with one finger', (tester) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final startFinder = find.text('Start').first;
    final before = tester.getCenter(startFinder);
    final gesture = await tester.startGesture(before);
    await gesture.moveBy(const Offset(76, 48));
    await gesture.up();
    await tester.pumpAndSettle();

    final after = tester.getCenter(startFinder);
    expect(after.dx, greaterThan(before.dx + 30));
    expect(after.dy, greaterThan(before.dy + 20));
  });

  testWidgets('production map order flow shows disabled laminatsiya above 1050',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            orderName: 'Large rubber order',
            productName: 'large rubber product',
            itemCode: 'ITEM-1100',
            rollCount: 7,
            widthMm: 1070,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Element qo‘shish'));
    await tester.pumpAndSettle();

    expect(productionMapRubberSizeFromWidth(1070), 1100);
    expect(find.byKey(const ValueKey('admin-fab-menu-Bosma aparat')),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-fab-menu-Laminatsiya')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('admin-fab-menu-Laminatsiya')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Laminatsiya apparatga buyurtma kattalik qiladi, iltimos uni bo‘laklab oling',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'production map order flow enables laminatsiya after fitting kadr rezka',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      await _usePhoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminProductionMapTestScreen(
            orderContext: ProductionMapOrderContext(
              orderName: 'Large kadr order',
              productName: 'large kadr product',
              itemCode: 'ITEM-1400',
              rollCount: 7,
              widthMm: 1070,
              templateDraft: CalculateOrderTemplate(
                id: 'template-large',
                code: 'Z-LARGE',
                name: 'Large kadr order',
                savedAt: DateTime.fromMillisecondsSinceEpoch(0),
                orderNumber: '',
                customerRef: 'CUST-001',
                customer: 'Mijoz',
                itemCode: 'ITEM-1400',
                product: 'large kadr product',
                status: 'Ready',
                materialDisplay: '',
                color: '',
                imageId: '',
                imageName: '',
                imageMime: '',
                imageSizeBytes: 0,
                imageUrl: '',
                frameProductSizeMm: 250,
                frameCount: 4,
                widthMm: 1070,
                wastePercent: 5,
                rollCount: 7,
                firstLayerMaterial: 'pet',
                firstLayerMicron: '12',
                secondLayerMaterial: 'pe oq',
                secondLayerMicron: '30',
                thirdLayerMaterial: '',
                thirdLayerMicron: '',
                note: '',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapMapTool(tester, 'Rezka');
      await tester.pumpAndSettle();
      expect(find.text('Buyurtma bo‘yicha'), findsOneWidget);

      await tester.tap(find.text('Kadr bo‘yicha'));
      await tester.pumpAndSettle();
      expect(find.text('Kadr 1'), findsOneWidget);
      expect(find.text('Kadr 4'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('rezka-frame-join-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rezka-frame-join-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saqlash'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Element qo‘shish'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('admin-fab-menu-Laminatsiya')));
      await tester.pumpAndSettle();

      expect(find.text('Laminatsiya 1'), findsOneWidget);
      expect(find.text('Laminatsiya 2'), findsOneWidget);
      expect(
        find.text(
          'Laminatsiya apparatga buyurtma kattalik qiladi, iltimos uni bo‘laklab oling',
        ),
        findsNothing,
      );
    },
  );

  testWidgets('production map order flow offers flexo bosma for flex orders', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            orderName: 'Flex order',
            productName: 'vitagum flex paket',
            itemCode: 'ITEM-FLEX',
            rollCount: 7,
            widthMm: 650,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Element qo‘shish'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin-fab-menu-Bosma aparat')),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-fab-menu-Laminatsiya')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('admin-fab-menu-Ishlov')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('admin-fab-menu-Bosma aparat')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Flexo pechat'), findsOneWidget);
    expect(find.text('7 ta rangli bosma aparat'), findsNothing);
    expect(find.text('8 ta rangli bosma aparat'), findsNothing);
    expect(find.text('9 ta rangli bosma aparat'), findsNothing);
  });

  testWidgets(
    'production map pechat group skip adds alternative apparatus nodes',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      await _usePhoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapTestScreen(
            orderContext: ProductionMapOrderContext(
              orderName: 'Zenit order',
              productName: 'zenit frutto ninja 70gr',
              itemCode: 'ITEM-001',
              rollCount: 7,
              widthMm: 650,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Element qo‘shish'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('admin-fab-menu-Bosma aparat')));
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('7 ta rangli bosma aparat'), findsOneWidget);
      expect(find.text('8 ta rangli bosma aparat'), findsOneWidget);
      expect(find.text('9 ta rangli bosma aparat'), findsNothing);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('7 ta rangli bosma aparat'), findsOneWidget);
      expect(find.text('8 ta rangli bosma aparat'), findsOneWidget);
    },
  );

  testWidgets('production map skip groups chain as parallel merge blocks', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    addTearDown(() async {
      await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: 'zakaz-9468',
          title: 'Parallel skip cleanup',
          productCode: 'ITEM-PARALLEL-SKIP-CLEANUP',
          apparatus: 'Godex aparat - DEMO',
          product: 'parallel skip cleanup product',
        ),
      );
    });
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            orderName: 'Parallel skip order',
            productName: 'parallel skip product',
            itemCode: 'ITEM-PARALLEL-SKIP',
            rollCount: 7,
            widthMm: 650,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapMapTool(tester, 'Bosma aparat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await _tapMapTool(tester, 'Laminatsiya');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('production-map-save')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('production-map-order-number-field')),
      '9468',
    );
    await tester.tap(find.byKey(const ValueKey('production-map-confirm-save')));
    await tester.pumpAndSettle();

    final saved = await MobileApi.instance.adminProductionMap('zakaz-9468');
    final map = saved.map;
    final pechatNodes = map.nodes
        .where((node) => node.title.trim().contains('rangli bosma'))
        .toList(growable: false);
    final laminatsiyaNodes = map.nodes
        .where((node) => node.title.trim().contains('Laminatsiya'))
        .toList(growable: false);

    expect(pechatNodes.map((node) => node.title), [
      '7 ta rangli bosma aparat',
      '8 ta rangli bosma aparat',
    ]);
    expect(laminatsiyaNodes.map((node) => node.title), [
      'Laminatsiya 1',
      'Laminatsiya 2',
    ]);
    for (final pechat in pechatNodes) {
      expect(
        map.edges.any(
          (edge) =>
              edge.from == pechat.id &&
              laminatsiyaNodes.any((node) => node.id == edge.to),
        ),
        isTrue,
      );
      expect(
        map.edges.any((edge) => edge.from == pechat.id && edge.to == 'end'),
        isFalse,
      );
    }
    for (final laminatsiya in laminatsiyaNodes) {
      expect(
        map.edges.any(
          (edge) =>
              pechatNodes.any((node) => node.id == edge.from) &&
              edge.to == laminatsiya.id,
        ),
        isTrue,
      );
      expect(
        map.edges.any(
          (edge) => edge.from == laminatsiya.id && edge.to == 'end',
        ),
        isTrue,
      );
    }
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('reopened saved map appends skipped apparatus group after tail', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    final orderNumber =
        '${DateTime.now().microsecondsSinceEpoch.remainder(9000) + 1000}';
    final mapId = 'zakaz-reopen-chain-test-$orderNumber';
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapTestScreen(
          savedMap: ProductionMapDefinition(
            id: mapId,
            title: 'Reopened chain order',
            productCode: 'ITEM-REOPEN-CHAIN',
            code: orderNumber,
            orderNumber: orderNumber,
            rollCount: 7,
            widthMm: 650,
            nodes: [
              const ProductionMapNode(
                id: 'start',
                kind: 'start',
                title: 'Start',
                x: 420,
                y: 32,
              ),
              const ProductionMapNode(
                id: 'order',
                kind: 'task',
                title: 'Reopened chain order',
                roleCode: 'zakaz',
                x: 420,
                y: 164,
              ),
              const ProductionMapNode(
                id: 'apparatus_1',
                kind: 'apparatus',
                title: '7 ta rangli bosma aparat',
                alternativeGroupId: 'alt_pechat_1',
                alternativeGroupLabel: 'pechat',
                x: 280,
                y: 296,
              ),
              const ProductionMapNode(
                id: 'apparatus_2',
                kind: 'apparatus',
                title: '8 ta rangli bosma aparat',
                alternativeGroupId: 'alt_pechat_1',
                alternativeGroupLabel: 'pechat',
                x: 560,
                y: 296,
              ),
              const ProductionMapNode(
                id: 'end',
                kind: 'end',
                title: 'reopen chain product',
                itemCode: 'ITEM-REOPEN-CHAIN',
                x: 420,
                y: 428,
              ),
            ],
            edges: [
              const ProductionMapEdge(from: 'start', to: 'order'),
              const ProductionMapEdge(from: 'order', to: 'apparatus_1'),
              const ProductionMapEdge(from: 'order', to: 'apparatus_2'),
              const ProductionMapEdge(from: 'apparatus_1', to: 'end'),
              const ProductionMapEdge(from: 'apparatus_2', to: 'end'),
            ],
          ),
          orderContext: const ProductionMapOrderContext(
            orderName: 'Reopened chain order',
            productName: 'reopen chain product',
            itemCode: 'ITEM-REOPEN-CHAIN',
            rollCount: 7,
            widthMm: 650,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapMapTool(tester, 'Laminatsiya');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('production-map-save')));
    await tester.pumpAndSettle();

    final saved = await MobileApi.instance.adminProductionMap(
      mapId,
    );
    final map = saved.map;
    final ids = map.nodes.map((node) => node.id).toList(growable: false);
    final pechatNodes = map.nodes
        .where((node) => node.title.trim().contains('rangli bosma'))
        .toList(growable: false);
    final laminatsiyaNodes = map.nodes
        .where((node) => node.title.trim().contains('Laminatsiya'))
        .toList(growable: false);

    expect(ids.toSet().length, ids.length);
    expect(laminatsiyaNodes, hasLength(2));
    for (final pechat in pechatNodes) {
      expect(
        map.edges.any(
          (edge) =>
              edge.from == pechat.id &&
              laminatsiyaNodes.any((node) => node.id == edge.to),
        ),
        isTrue,
      );
      expect(
        map.edges.any((edge) => edge.from == pechat.id && edge.to == 'end'),
        isFalse,
      );
    }
    for (final laminatsiya in laminatsiyaNodes) {
      expect(
        map.edges
            .any((edge) => edge.from == laminatsiya.id && edge.to == 'end'),
        isTrue,
      );
    }
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('production map does not show kk product action', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            orderName: 'Zenit order',
            productName: 'zenit frutto ninja 70gr',
            itemCode: 'ITEM-001',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Element qo‘shish'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin-fab-menu-kk li mahsulot')),
        findsNothing);
    expect(find.text('kk li mahsulot'), findsNothing);
  });

  testWidgets('production map apparatus picker shows only recommended pechat', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            orderName: 'Zenit order',
            productName: 'zenit frutto ninja 70gr',
            itemCode: 'ITEM-001',
            rollCount: 8,
            widthMm: 700,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapMapTool(tester, 'Bosma aparat');
    await tester.pumpAndSettle();

    expect(find.text('8 ta rangli bosma aparat'), findsOneWidget);
    expect(find.text('7 ta rangli bosma aparat'), findsNothing);
    expect(find.text('9 ta rangli bosma aparat'), findsNothing);
  });

  test('production map edges are unrestricted between supported nodes', () {
    const apparatus = ProductionMapNode(
      id: 'apparatus_1',
      kind: 'apparatus',
      title: 'Godex aparat - DEMO',
    );
    const task = ProductionMapNode(
      id: 'task_1',
      kind: 'task',
      title: 'Ishlov jarayoni',
    );
    const start = ProductionMapNode(id: 'start', kind: 'start', title: 'Start');

    expect(productionMapCanCreateEdge(start, task), isTrue);
    expect(productionMapCanCreateEdge(task, start), isTrue);
    expect(productionMapCanCreateEdge(task, apparatus), isTrue);
    expect(productionMapCanCreateEdge(apparatus, task), isTrue);
  });

  test(
    'production map pechat compatibility summary uses product constraints',
    () {
      expect(
        productionMapPechatCompatibilitySummary(rollCount: 7, widthMm: 650),
        'Minimal 7 ta rangli bosma • Mos: 7 ta rangli bosma, 8 ta rangli bosma',
      );
      expect(
        productionMapPechatCompatibilitySummary(rollCount: 7, widthMm: 1250),
        'Minimal 9 ta rangli bosma • Mos: 9 ta rangli bosma',
      );
    },
  );

  test('production map pechat recommendation prioritizes val then rubber', () {
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 7, widthMm: 700),
      7,
    );
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 7, widthMm: 815),
      7,
    );
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 7, widthMm: 900),
      8,
    );
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 8, widthMm: 700),
      8,
    );
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 9, widthMm: 700),
      9,
    );
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 6, widthMm: 1200),
      9,
    );
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 10, widthMm: 700),
      isNull,
    );
  });

  test('production map pechat filter uses expanded rubber limits', () {
    expect(productionMapRubberSizeFromWidth(815), 850);
    const screenshotOrderContext = ProductionMapOrderContext(
      orderName: 'alanga guruch qora',
      productName: 'alanga guruch qora',
      itemCode: 'ITEM-815',
      rollCount: 7,
      widthMm: 815,
    );
    expect(
      productionMapApparatusMatchesOrder(
        const AdminApparatus(name: '7 ta rangli bosma aparat'),
        screenshotOrderContext,
      ),
      isTrue,
    );
    expect(
      productionMapPechatCanHandleOrder(
        apparatusColorCount: 7,
        rollCount: 7,
        widthMm: 815,
      ),
      isTrue,
    );
    expect(
      productionMapPechatCanHandleOrder(
        apparatusColorCount: 7,
        rollCount: 7,
        widthMm: 851,
      ),
      isFalse,
    );
    expect(
      productionMapPechatCanHandleOrder(
        apparatusColorCount: 8,
        rollCount: 8,
        widthMm: 1050,
      ),
      isTrue,
    );
    expect(
      productionMapPechatCanHandleOrder(
        apparatusColorCount: 8,
        rollCount: 8,
        widthMm: 1051,
      ),
      isFalse,
    );
    expect(productionMapRubberSizeFromWidth(1500), 1350);
    expect(
      productionMapPechatCanHandleOrder(
        apparatusColorCount: 9,
        rollCount: 9,
        widthMm: 1350,
      ),
      isTrue,
    );
  });

  test(
    'production map pechat filter allows compatible higher pechat capacity',
    () {
      const context = ProductionMapOrderContext(
        orderName: 'Zenit order',
        productName: 'zenit frutto ninja 70gr',
        itemCode: 'ITEM-001',
        rollCount: 7,
        widthMm: 650,
      );

      expect(
        productionMapApparatusMatchesOrder(
          const AdminApparatus(
            name: '7 ta rangli bosma aparat',
          ),
          context,
        ),
        isTrue,
      );
      expect(
        productionMapApparatusMatchesOrder(
          const AdminApparatus(
            name: '8 ta rangli bosma aparat',
          ),
          context,
        ),
        isTrue,
      );
      expect(
        productionMapApparatusMatchesOrder(
          const AdminApparatus(
            name: '9 ta rangli bosma aparat',
          ),
          context,
        ),
        isFalse,
      );
      expect(
        productionMapApparatusMatchesOrder(
          const AdminApparatus(
            name: 'Godex aparat - DEMO',
          ),
          context,
        ),
        isTrue,
      );

      const smallRubberContext = ProductionMapOrderContext(
        orderName: 'Small order',
        productName: 'small product',
        itemCode: 'ITEM-002',
        rollCount: 7,
        widthMm: 100,
      );

      expect(
        productionMapApparatusMatchesOrder(
          const AdminApparatus(
            name: '8 ta rangli bosma aparat',
          ),
          smallRubberContext,
        ),
        isFalse,
      );
    },
  );

  test(
    'production map pechat filter blocks color pechat for flex products',
    () {
      for (final marker in const [
        'fleksa',
        'fleska',
        'flex',
        'flexe',
        'flexo',
      ]) {
        final context = ProductionMapOrderContext(
          orderName: 'Flexo order',
          productName: 'vitagum $marker paket',
          itemCode: 'ITEM-FLEX',
          rollCount: 7,
          widthMm: 650,
        );

        expect(
          productionMapApparatusMatchesOrder(
            const AdminApparatus(
              name: '7 ta rangli bosma aparat',
            ),
            context,
          ),
          isFalse,
        );
        expect(
          productionMapApparatusMatchesOrder(
            const AdminApparatus(
              name: '8 ta rangli bosma aparat',
            ),
            context,
          ),
          isFalse,
        );
        expect(
          productionMapApparatusMatchesOrder(
            const AdminApparatus(
              name: 'Flexo pechat',
            ),
            context,
          ),
          isTrue,
        );
        expect(
          productionMapApparatusMatchesOrder(
            const AdminApparatus(
              name: 'Laminatsiya - A',
            ),
            context,
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'production map apparatus filter blocks laminatsiya above 1050 rubber',
    () {
      const laminatsiya = AdminApparatus(
        name: 'Laminatsiya - A',
      );
      const allowedContext = ProductionMapOrderContext(
        orderName: 'Allowed order',
        productName: 'allowed product',
        itemCode: 'ITEM-1050',
        rollCount: 7,
        widthMm: 1050,
      );
      const blockedContext = ProductionMapOrderContext(
        orderName: 'Blocked order',
        productName: 'blocked product',
        itemCode: 'ITEM-1051',
        rollCount: 7,
        widthMm: 1051,
      );

      expect(productionMapRubberSizeFromWidth(1050), 1050);
      expect(productionMapRubberSizeFromWidth(1051), 1100);
      expect(
        productionMapApparatusMatchesOrder(laminatsiya, allowedContext),
        isTrue,
      );
      expect(
        productionMapApparatusMatchesOrder(laminatsiya, blockedContext),
        isFalse,
      );
    },
  );

  test(
    'production map pechat move blocks missing or incompatible order data',
    () {
      expect(
        productionMapPechatCanMoveOrder(
          apparatusColorCount: 8,
          rollCount: null,
          widthMm: 900,
        ),
        isTrue,
      );
      expect(
        productionMapPechatCanMoveOrder(
          apparatusColorCount: 8,
          rollCount: 7,
          widthMm: null,
        ),
        isTrue,
      );
      expect(
        productionMapPechatCanMoveOrder(
          apparatusColorCount: 9,
          rollCount: null,
          widthMm: 900,
        ),
        isFalse,
      );
      expect(
        productionMapPechatCanMoveOrder(
          apparatusColorCount: 9,
          rollCount: 7,
          widthMm: null,
        ),
        isFalse,
      );
      expect(
        productionMapPechatCanMoveOrder(
          apparatusColorCount: 9,
          rollCount: 7,
          widthMm: 650,
        ),
        isFalse,
      );
      expect(
        productionMapPechatCanMoveOrder(
          apparatusColorCount: 9,
          rollCount: 9,
          widthMm: 900,
        ),
        isTrue,
      );
      expect(
        productionMapPechatCanMoveOrder(
          apparatusColorCount: 7,
          rollCount: 7,
          widthMm: 1300,
        ),
        isFalse,
      );
      expect(
        productionMapPechatCanMoveOrder(
          apparatusColorCount: 8,
          rollCount: 7,
          widthMm: 1250,
        ),
        isFalse,
      );
      expect(productionMapPechatColorCount('9 ta rangli aparat'), 9);
      expect(productionMapPechatColorCount('7 ta rangli'), 7);
      expect(
        productionMapPechatCanMoveOrder(
          apparatusColorCount: 7,
          rollCount: 7,
          widthMm: null,
          sourceApparatusColorCount: 9,
        ),
        isFalse,
      );
      expect(
        productionMapPechatCanMoveOrder(
          apparatusColorCount: 7,
          rollCount: 7,
          widthMm: 1250,
          sourceApparatusColorCount: 9,
        ),
        isFalse,
      );
    },
  );

  test(
    'production map batch move reassigns alternative assigned apparatus',
    () async {
      await TestModeController.instance.setEnabled(true);
      final map = _alternativeProductionOrderMap(
        id: 'zakaz-alt-move',
        title: 'Alternative move order',
        productCode: 'ALT-MOVE',
        product: 'alternative move product',
        apparatus: const [
          '7 ta rangli bosma aparat',
          '8 ta rangli bosma aparat'
        ],
        rollCount: 7,
        widthMm: 650,
      );
      await MobileApi.instance.adminSaveProductionMap(
        map.copyWith(
          nodes: [
            for (final node in map.nodes)
              node.kind == 'apparatus'
                  ? node.copyWith(
                      alternativeAssignedTitle: '7 ta rangli bosma aparat',
                    )
                  : node,
          ],
        ),
      );

      final moved = await MobileApi.instance.adminMoveProductionMapOrdersBatch(
        mapIds: const ['zakaz-alt-move'],
        fromApparatus: '7 ta rangli bosma aparat',
        toApparatus: '8 ta rangli bosma aparat',
      );

      expect(_apparatusTitles(moved, 'zakaz-alt-move'), [
        '7 ta rangli bosma aparat',
        '8 ta rangli bosma aparat',
      ]);
      expect(_alternativeAssignedTitles(moved, 'zakaz-alt-move'), [
        '8 ta rangli bosma aparat',
        '8 ta rangli bosma aparat',
      ]);
      final maps = await MobileApi.instance.adminProductionMaps();
      expect(_alternativeAssignedTitles(maps, 'zakaz-alt-move'), [
        '8 ta rangli bosma aparat',
        '8 ta rangli bosma aparat',
      ]);
    },
  );

  test(
    'production map batch move keeps laminatsiya alternatives in group',
    () async {
      await TestModeController.instance.setEnabled(true);
      final map = _alternativeProductionOrderMap(
        id: 'zakaz-lamin-alt-move',
        title: 'Laminatsiya alternative move',
        productCode: 'LAMIN-ALT',
        product: 'laminatsiya product',
        apparatus: const ['Laminatsiya 1', 'Laminatsiya 2'],
        rollCount: 7,
        widthMm: 900,
      );
      await MobileApi.instance.adminSaveProductionMap(
        map.copyWith(
          nodes: [
            for (final node in map.nodes)
              node.kind == 'apparatus'
                  ? node.copyWith(alternativeAssignedTitle: 'Laminatsiya 1')
                  : node,
          ],
        ),
      );

      final moved = await MobileApi.instance.adminMoveProductionMapOrdersBatch(
        mapIds: const ['zakaz-lamin-alt-move'],
        fromApparatus: 'Laminatsiya 1',
        toApparatus: 'Laminatsiya 2',
      );
      expect(_alternativeAssignedTitles(moved, 'zakaz-lamin-alt-move'), [
        'Laminatsiya 2',
        'Laminatsiya 2',
      ]);

      expect(
        () => MobileApi.instance.adminMoveProductionMapOrdersBatch(
          mapIds: const ['zakaz-lamin-alt-move'],
          fromApparatus: 'Laminatsiya 2',
          toApparatus: 'Paket aparat',
        ),
        throwsA(isA<MobileApiException>()),
      );
      final maps = await MobileApi.instance.adminProductionMaps();
      expect(_alternativeAssignedTitles(maps, 'zakaz-lamin-alt-move'), [
        'Laminatsiya 2',
        'Laminatsiya 2',
      ]);
    },
  );

  testWidgets('production map order flow requires four digit order number', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            templateId: 'ORDER-1',
            orderName: 'Zenit order',
            productName: 'zenit frutto ninja 70gr',
            itemCode: 'ITEM-001',
            rollCount: 7,
            widthMm: 650,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('production-map-save')));
    await tester.pumpAndSettle();

    expect(find.text('Zakaz raqami'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('production-map-order-number-field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('production-map-order-number-field')),
      '12',
    );
    await tester.tap(find.byKey(const ValueKey('production-map-confirm-save')));
    await tester.pumpAndSettle();

    expect(find.text('4 xonali raqam kiriting'), findsOneWidget);
    expect(find.text('Production map saqlandi'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('production-map-order-number-field')),
      '1234',
    );
    await tester.tap(find.byKey(const ValueKey('production-map-confirm-save')));
    await tester.pumpAndSettle();

    expect(find.text('Production map saqlandi'), findsOneWidget);
    final maps = await MobileApi.instance.adminProductionMaps();
    expect(maps.first.map.orderNumber, '1234');
    expect(maps.first.map.id, 'zakaz-1234');
    expect(maps.first.map.rollCount, 7);
    expect(maps.first.map.widthMm, 650);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('production map order number must be unique per zakaz', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-9876',
        title: 'Old zakaz',
        productCode: 'OLD-ITEM',
        apparatus: 'Paket aparat',
        product: 'old product',
        orderNumber: '9876',
      ),
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            templateId: 'ORDER-NEW',
            orderName: 'New zakaz',
            productName: 'new product',
            itemCode: 'NEW-ITEM',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('production-map-save')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('production-map-order-number-field')),
      '9876',
    );
    await tester.tap(find.byKey(const ValueKey('production-map-confirm-save')));
    await tester.pumpAndSettle();

    expect(find.text('Bu raqam boshqa zakazga berilgan'), findsOneWidget);
    expect(find.text('Production map saqlandi'), findsNothing);
    final maps = await MobileApi.instance.adminProductionMaps();
    expect(maps.where((item) => item.map.orderNumber == '9876'), hasLength(1));
    expect(maps.first.map.title, 'Old zakaz');
    // Let the top notice auto-dismiss timer finish.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('opened production map orders page lists saved zakaz', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.upsertCalculateOrderTemplate(
      CalculateOrderTemplate(
        id: 'customer-template-2',
        code: 'CUSTOMER-ORDER-2',
        name: 'Customer order 2',
        savedAt: DateTime.fromMillisecondsSinceEpoch(0),
        orderNumber: '',
        customerRef: 'CUSTOMER-2',
        customer: 'Customer 2',
        itemCode: 'ITEM-002',
        product: 'zenit frutto ninja 70gr',
        status: '',
        materialDisplay: '',
        color: '',
        imageId: '',
        imageName: '',
        imageMime: '',
        imageSizeBytes: 0,
        imageUrl: '',
        widthMm: 650,
        wastePercent: 5,
        rollCount: 7,
        firstLayerMaterial: '',
        firstLayerMicron: '',
        secondLayerMaterial: '',
        secondLayerMicron: '',
        thirdLayerMaterial: '',
        thirdLayerMicron: '',
        note: '',
      ),
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            templateId: 'ORDER-2',
            orderName: 'Zenit opened',
            productName: 'zenit frutto ninja 70gr',
            itemCode: 'ITEM-002',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('production-map-save')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('production-map-order-number-field')),
      '2222',
    );
    await tester.tap(find.byKey(const ValueKey('production-map-confirm-save')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ochilgan zakaz qidirish'), findsOneWidget);
    expect(find.textContaining('Zenit opened'), findsOneWidget);
    expect(find.textContaining('Customer 2'), findsOneWidget);
    expect(find.textContaining('ITEM-002'), findsNothing);
  });

  testWidgets('opened production map orders load error is text only', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    setMobileApiTestModeForceProductionMapMenuLoadFailure(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reja menu yuklanmadi'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.byType(AppRefreshIndicator), findsOneWidget);
  });

  testWidgets(
    'opened production map order info sheet shows readable order details',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: 'zakaz-rounded-a',
          title: 'Rounded order A',
          productCode: 'ROUND-A',
          apparatus: 'Paynet',
          product: 'rounded product A',
          rollCount: 7,
          widthMm: 650,
        ).copyWith(
          orderKg: 100,
          baseLength: 51282.1,
        ),
      );
      await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: 'zakaz-rounded-b',
          title: 'Rounded order B',
          productCode: 'ROUND-B',
          apparatus: 'Paynet',
          product: 'rounded product B',
          rollCount: 7,
          widthMm: 650,
        ).copyWith(
          orderKg: 100,
          baseLength: 3883.5,
        ),
      );
      await _usePhoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Buyurtma ma’lumotlari').first);
      await tester.pumpAndSettle();
      expect(find.text('Zakaz kodi'), findsOneWidget);
      expect(
        find.text('Kutilayotgan buyurtma ko‘rsatkichlari'),
        findsOneWidget,
      );
      expect(find.text('Metraj'), findsNothing);
      expect(find.text('Val'), findsNothing);
      await tester.tap(find.text('Kutilayotgan buyurtma ko‘rsatkichlari'));
      await tester.pumpAndSettle();
      expect(find.text('Metraj'), findsOneWidget);
      expect(find.text('Val'), findsOneWidget);

      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Buyurtma ma’lumotlari').last);
      await tester.pumpAndSettle();
      expect(find.text('Zakaz kodi'), findsOneWidget);
    },
  );

  testWidgets('opened orders modules are ordered orders move sequence closed', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final buyurtmalarCenter = tester.getCenter(find.text('Buyurtmalar'));
    final moveCenter = tester.getCenter(find.text('Ko‘chirish'));
    final sequenceCenter = tester.getCenter(find.text('Ketma-ketlik'));
    final closedCenter = tester.getCenter(find.text('Yopilgan'));

    expect(buyurtmalarCenter.dx, lessThan(moveCenter.dx));
    expect(moveCenter.dx, lessThan(sequenceCenter.dx));
    expect(sequenceCenter.dx, lessThan(closedCenter.dx));
  });

  testWidgets('opened orders sequence module picks apparatus and reorders', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-sequence-a',
        title: 'Paket order A',
        productCode: 'PKT-A',
        apparatus: 'Godex aparat - DEMO',
        product: 'paket mahsulot A',
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-sequence-b',
        title: 'Paket order B',
        productCode: 'PKT-B',
        apparatus: 'Godex aparat - DEMO',
        product: 'paket mahsulot B',
      ),
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buyurtmalar'), findsOneWidget);
    expect(find.text('Ketma-ketlik'), findsOneWidget);
    expect(find.text('Ko‘chirish'), findsOneWidget);
    expect(find.text('Yopilgan'), findsOneWidget);

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    await tester.tap(find.text('Ketma-ketlik'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_rounded), findsNothing);

    expect(find.textContaining('Godex aparat - DEMO'), findsOneWidget);
    expect(find.textContaining('2 ta zakaz'), findsOneWidget);

    expect(find.textContaining('Paket order A'), findsOneWidget);
    expect(find.textContaining('Paket order B'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsWidgets);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('supply sequence page is shared and read only for supply roles', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-supply-sequence-order',
        title: 'Supply sequence order',
        productCode: 'SUPPLY-SEQ',
        apparatus: 'Godex aparat - DEMO',
        product: 'supply product',
      ),
    );
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'qolipchi',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          supplyViewerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ketma-ketlikdan zakaz qidirish'), findsOneWidget);
    await tester.tap(find.byType(FilterChip).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('admin-filter-option-Godex aparat - DEMO'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Supply sequence order'), findsOneWidget);
    expect(find.text('Buyurtmalar'), findsNothing);
    expect(find.text('Ko‘chirish'), findsNothing);
    expect(find.text('Yopilgan'), findsNothing);
    expect(find.byType(ReorderableListView), findsNothing);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    expect(
      find.text('Tartibni o‘zgartirish uchun zakazni ushlab torting'),
      findsNothing,
    );
    expect(find.byTooltip('Buyurtma ma’lumotlari'), findsOneWidget);
    await tester.tap(find.byTooltip('Buyurtma ma’lumotlari'));
    await tester.pumpAndSettle();
    expect(find.text('Zakaz kodi'), findsOneWidget);
    Navigator.of(tester.element(find.text('Zakaz kodi'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Qoliplar'), findsWidgets);
    expect(find.text('Ketma-ketlik'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Material ta’minotchi',
      legalName: '',
      ref: 'material_taminotchi',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
      assignedApparatus: ['Godex aparat - DEMO'],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          supplyViewerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Tarozilar rejimi'), findsOneWidget);
    expect(find.text('Ketma-ketlik'), findsOneWidget);
  });

  testWidgets('qolipchi sequence long press keeps a returned qolip note',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Godex aparat - DEMO';
    const orderId = 'zakaz-qolip-sequence-note';
    const product = QolipProduct(
      code: 'QOLIP-SEQUENCE-ITEM',
      name: 'Qolip sequence product',
      itemGroup: 'Tayyor mahsulotlar',
    );
    await MobileApi.instance.qolipSaveProductSpec(
      product: product,
      qolipCode: 'QOLIP-SEQUENCE-1',
      size: 40,
    );
    await MobileApi.instance.qolipSaveProductSpec(
      product: product,
      qolipCode: 'QOLIP-SEQUENCE-2',
      size: 41,
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: orderId,
        title: 'Qolip sequence order',
        productCode: product.code,
        apparatus: apparatus,
        product: product.name,
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'qolipchi-sequence-note',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
    );

    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          supplyViewerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterChip).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-filter-option-Godex aparat - DEMO')),
    );
    await tester.pumpAndSettle();

    final orderFinder = find.textContaining('Qolip sequence order');
    expect(
      find.text(
        'Bir marta bosing — ma’lumot. Uzoq bosing — qolip qaydini ochish.',
      ),
      findsOneWidget,
    );
    await tester.longPress(orderFinder);
    await tester.pumpAndSettle();
    expect(find.text('Order qoliplarini qayd qilish'), findsOneWidget);
    expect(find.text('Hammasini berish'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanlangan qoliplarni berdim'));
    await tester.pumpAndSettle();
    final given = await MobileApi.instance
        .adminProductionMapQolipOrderNoteDetails(orderId: orderId);
    expect(given.note?.isGiven, isTrue);
    expect(given.note?.qolipCodes, ['QOLIP-SEQUENCE-1']);

    await tester.longPress(orderFinder);
    await tester.pumpAndSettle();
    expect(find.text('Qoliplarni qaytarib oldim'), findsOneWidget);
    final givenTiles = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList(growable: false);
    expect(givenTiles, hasLength(2));
    expect(givenTiles[0].value, isTrue);
    expect(givenTiles[0].onChanged, isNull);
    expect(givenTiles[1].value, isFalse);
    expect(givenTiles[1].onChanged, isNotNull);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Hammasini berish'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanlangan qoliplarni berdim'));
    await tester.pumpAndSettle();
    final givenAll = await MobileApi.instance
        .adminProductionMapQolipOrderNoteDetails(orderId: orderId);
    expect(givenAll.note?.qolipCodes, [
      'QOLIP-SEQUENCE-1',
      'QOLIP-SEQUENCE-2',
    ]);

    await tester.longPress(orderFinder);
    await tester.pumpAndSettle();
    final allGivenTiles = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList(growable: false);
    expect(allGivenTiles.every((tile) => tile.onChanged == null), isTrue);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Yangi qolip tanlang'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Qolip qo‘shish'), findsOneWidget);
    await tester.tap(find.text('Qoliplarni qaytarib oldim'));
    await tester.pumpAndSettle();
    final returned = await MobileApi.instance
        .adminProductionMapQolipOrderNoteDetails(orderId: orderId);
    expect(returned.note?.isReturned, isTrue);
    expect(returned.note?.qolipCodes, [
      'QOLIP-SEQUENCE-1',
      'QOLIP-SEQUENCE-2',
    ]);
  });

  testWidgets('qolipchi can add a qolip from an empty order note sheet',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Godex aparat - DEMO';
    const orderId = 'zakaz-qolip-inline-add';
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: orderId,
        title: 'Inline qolip order',
        productCode: 'DEMO-HOTLUNCH',
        apparatus: apparatus,
        product: 'Hotlunch',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'qolipchi-inline-add',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
    );

    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          supplyViewerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterChip).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-filter-option-Godex aparat - DEMO')),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('Inline qolip order'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bu tayyor mahsulotga hali qolip biriktirilmagan.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Qolip qo‘shish'));
    await tester.pumpAndSettle();
    expect(find.text('Qolipni omborga biriktirish'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'INLINE-Q-1');
    await tester.enterText(fields.at(1), '40');
    await tester.pump();
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    expect(find.text('INLINE-Q-1'), findsOneWidget);
    expect(find.text('Qolip qo‘shish'), findsOneWidget);
    final details = await MobileApi.instance
        .adminProductionMapQolipOrderNoteDetails(orderId: orderId);
    expect(
      details.requiredQolips.map((item) => item.qolipCode),
      ['INLINE-Q-1'],
    );
  });

  testWidgets(
      'material supplier sequence opens details on tap and assignment on long press',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Godex aparat - DEMO';
    const secondApparatus = 'Laminatsiya 1';
    const orderId = 'zakaz-supply-sequence-actions';
    await MobileApi.instance.adminSaveProductionMap(
      _twoStageProductionOrderMap(
        id: orderId,
        title: 'Material action order',
        productCode: 'SUPPLY-ACTIONS',
        product: 'material action product',
        firstApparatus: apparatus,
        secondApparatus: secondApparatus,
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminSaveRawMaterialRule(
      apparatus: apparatus,
      itemGroups: const ['Kraska'],
    );
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Material ta’minotchi',
      legalName: '',
      ref: 'material_taminotchi',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
      assignedApparatus: [apparatus, secondApparatus],
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          supplyViewerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterChip).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-filter-option-Godex aparat - DEMO')),
    );
    await tester.pumpAndSettle();

    final orderFinder = find.textContaining('Material action order');
    expect(orderFinder, findsOneWidget);
    expect(
      find.text('Bir marta bosing — ma’lumot. Uzoq bosing — homashyo ulash.'),
      findsOneWidget,
    );

    await tester.tap(orderFinder);
    await tester.pumpAndSettle();
    expect(find.text('Zakaz kodi'), findsOneWidget);
    expect(
      find.text('Qolip yoki homashyo QR kodini tirqishga olib keling'),
      findsNothing,
    );
    Navigator.of(tester.element(find.text('Zakaz kodi'))).pop();
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('Material action order'));
    await tester.pumpAndSettle();
    expect(find.text('Orderga homashyo ulash'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sequence-apparatus-filter')),
        matching: find.text('Aparat: $apparatus'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 ta mos homashyo'), findsOneWidget);
    expect(find.text('Demo kraska'), findsOneWidget);
    expect(find.text('Ombor: Xomashyo ombori - DEMO'), findsOneWidget);
    final candidateCardFinder = find
        .ancestor(
          of: find.text('Demo kraska'),
          matching: find.byType(Card),
        )
        .first;
    final candidateColorScheme =
        Theme.of(tester.element(find.text('Demo kraska'))).colorScheme;
    expect(
      tester.widget<Card>(candidateCardFinder).color,
      candidateColorScheme.surfaceContainerLow,
    );

    await tester.tap(
      find.byKey(const ValueKey('sequence-assignment-qr-scan')),
    );
    await tester.pumpAndSettle();
    final scannerFinder = find.byKey(
      const ValueKey('sequence-assignment-qr-scanner'),
    );
    expect(scannerFinder, findsOneWidget);
    await tester
        .widget<ProductionQuickScannerPanel>(scannerFinder)
        .onCodeDetected('https://example.test/material?epc=30AA');
    await tester.pump();
    expect(find.text('Demo kraska tanlandi (1 ta)'), findsOneWidget);
    expect(find.text('Ulash · 1'), findsOneWidget);
    await tester
        .widget<ProductionQuickScannerPanel>(scannerFinder)
        .onCodeDetected('30AA');
    await tester.pump();
    expect(find.text('Ulash · 1'), findsOneWidget);

    await tester.tap(find.text('Demo kraska').first);
    await tester.pumpAndSettle();
    expect(find.text('Ulash · 1'), findsNothing);
    await tester.longPress(find.text('Demo kraska'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Card>(candidateCardFinder).color,
      candidateColorScheme.primaryContainer.withValues(alpha: 0.62),
    );
    expect(find.text('Ulash · 1'), findsOneWidget);
    await tester.tap(find.text('Ulash · 1'));
    await tester.pumpAndSettle();
    expect(find.text('1 ta homashyo orderga ulandi'), findsOneWidget);
    expect(find.text('Demo kraska'), findsNothing);
    await MobileApi.instance.adminAssignRawMaterialToOrder(
      orderId: orderId,
      apparatus: secondApparatus,
      barcode: '30BB',
    );

    await tester.tap(find.byTooltip('Yopish'));
    await tester.pumpAndSettle();
    await tester.tap(orderFinder);
    await tester.pumpAndSettle();
    expect(find.text('Biriktirilgan homashyolar'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('production-materials-expansion')),
    );
    await tester.pumpAndSettle();
    expect(find.text('30AA'), findsOneWidget);
    expect(find.text('30BB'), findsOneWidget);
    expect(
        find.text('Godex aparat - DEMO uchun biriktirilgan'), findsOneWidget);
    expect(find.text('Laminatsiya uchun biriktirilgan'), findsOneWidget);
    expect(find.text('Bu amal sizning rolingiz uchun ruxsat etilmagan'),
        findsNothing);
  });

  testWidgets(
      'material supplier can unlink an available material from sequence details',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Godex aparat - DEMO';
    const orderId = 'zakaz-supply-sequence-unlink';
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: orderId,
        title: 'Material unlink order',
        productCode: 'SUPPLY-UNLINK',
        apparatus: apparatus,
        product: 'material unlink product',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminSaveRawMaterialRule(
      apparatus: apparatus,
      itemGroups: const ['Kraska'],
    );
    await MobileApi.instance.adminAssignRawMaterialToOrder(
      orderId: orderId,
      apparatus: apparatus,
      barcode: '30AA',
    );
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Material ta’minotchi',
      legalName: '',
      ref: 'material_taminotchi',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
      assignedApparatus: [apparatus],
    );

    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          supplyViewerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterChip).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-filter-option-Godex aparat - DEMO')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Material unlink order'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('production-materials-expansion')),
    );
    await tester.pumpAndSettle();

    final unlinkButton = find.byKey(
      const ValueKey('raw-material-unlink-30AA'),
    );
    expect(unlinkButton, findsOneWidget);
    expect(tester.widget<IconButton>(unlinkButton).onPressed, isNotNull);
    await tester.tap(unlinkButton);
    await tester.pumpAndSettle();
    expect(find.text('Homashyoni uzish'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('production-material-confirm-unlink')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Homashyo zakazdan uzildi'), findsOneWidget);
    expect(find.text('30AA'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
      'material supplier empty assignment explains the minimum roll width',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = '8 ta rangli bosma aparat';
    const orderId = 'zakaz-supply-sequence-empty';
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: orderId,
        title: 'Material empty order',
        productCode: 'SUPPLY-EMPTY',
        apparatus: apparatus,
        product: 'material empty product',
        rollCount: 8,
        widthMm: 987,
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminSaveRawMaterialRule(
      apparatus: apparatus,
      itemGroups: const ['Rulon'],
    );
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Material ta’minotchi',
      legalName: '',
      ref: 'material_taminotchi',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
      assignedApparatus: [apparatus],
    );

    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          supplyViewerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterChip).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
          const ValueKey('admin-filter-option-8 ta rangli bosma aparat')),
    );
    await tester.pumpAndSettle();

    final orderFinder = find.textContaining('Material empty order');
    expect(orderFinder, findsOneWidget);
    await tester.longPress(orderFinder);
    await tester.pumpAndSettle();

    expect(find.text('Mos homashyo topilmadi'), findsOneWidget);
    expect(
      find.text(
        'Tizim qabul qiladigan rulon eni: 987 mm dan 1007 mm gacha.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'generic, sequence and worker details use the correct material scope', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Godex aparat - DEMO';
    const orderId = 'zakaz-sequence-state-policy';
    const stagedBarcode = 'RM-STATE-READY';
    const unstagedBarcode = 'RM-NOT-STAGED';
    const stateLocation = InventoryLocation(
      id: 'inventory_location:state:godex',
      kind: InventoryLocationKind.state,
      name: 'Godex State',
      factoryLocationId: 'state_godex',
      apparatus: [
        InventoryLocationApparatus(id: 'godex', name: apparatus),
      ],
    );
    seedMobileApiInventoryMovementTestData(
      locations: const [stateLocation],
      assets: const [
        InventoryAsset(
          kind: InventoryAssetKind.rawMaterial,
          assetRef: 'raw:state-ready',
          custodyWarehouseId: 'warehouse:material',
          custodyWarehouse: 'Material ombor',
          itemCode: 'RM-STATE',
          itemName: 'State homashyo',
          identifier: stagedBarcode,
          qty: 10,
          uom: 'kg',
          status: 'available',
          physicalLocation: InventoryLocationReference(
            id: 'inventory_location:state:godex',
            kind: InventoryLocationKind.state,
            name: 'Godex State',
          ),
        ),
      ],
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: orderId,
        title: 'State policy order',
        productCode: 'STATE-1',
        apparatus: apparatus,
        product: 'state policy product',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminSaveRawMaterialRule(
      apparatus: apparatus,
      startPolicy: AdminRawMaterialStartPolicy.stateAll,
      itemGroups: const ['Kraska'],
    );
    await MobileApi.instance.adminAssignRawMaterialToOrder(
      orderId: orderId,
      apparatus: apparatus,
      barcode: stagedBarcode,
    );
    await MobileApi.instance.adminAssignRawMaterialToOrder(
      orderId: orderId,
      apparatus: apparatus,
      barcode: unstagedBarcode,
    );

    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Buyurtma ma’lumotlari').first);
    await tester.pumpAndSettle();
    expect(find.text('Ish boshlash uchun homashyolar'), findsNothing);
    expect(find.text('Biriktirilgan homashyolar'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('production-materials-expansion')),
    );
    await tester.pumpAndSettle();
    expect(find.text(stagedBarcode), findsOneWidget);
    expect(find.text(unstagedBarcode), findsOneWidget);

    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ketma-ketlik'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Buyurtma ma’lumotlari').first);
    await tester.pumpAndSettle();
    expect(find.text('Ish boshlash uchun homashyolar'), findsOneWidget);
    expect(find.text('Biriktirilgan homashyolar'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('production-start-materials-expansion')),
    );
    await tester.pumpAndSettle();

    expect(find.text(stagedBarcode), findsOneWidget);
    expect(find.text(unstagedBarcode), findsNothing);
    expect(find.text('0/1'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('production-start-materials-expansion')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('production-materials-expansion')),
    );
    await tester.pumpAndSettle();
    expect(find.text(stagedBarcode), findsOneWidget);
    expect(find.text(unstagedBarcode), findsOneWidget);

    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await AppSession.instance.setSession(
      token: 'worker-state-policy-token',
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Godex operatori',
        legalName: '',
        ref: 'worker-state-policy',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [apparatus],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(apparatus));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
    await tester.pumpAndSettle();
    expect(find.text('Ish boshlash uchun homashyolar'), findsOneWidget);
    expect(find.text('Biriktirilgan homashyolar'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('production-start-materials-expansion')),
    );
    await tester.pumpAndSettle();

    expect(find.text(stagedBarcode), findsOneWidget);
    expect(find.text(unstagedBarcode), findsNothing);
    expect(find.text('0/1'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('production-start-materials-expansion')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('production-materials-expansion')),
    );
    await tester.pumpAndSettle();
    expect(find.text(stagedBarcode), findsOneWidget);
    expect(find.text(unstagedBarcode), findsOneWidget);
  });

  testWidgets('admin sequence excludes completed apparatus orders', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Godex aparat - DEMO';
    const completedOrderId = 'zakaz-admin-sequence-completed';
    const pendingOrderId = 'zakaz-admin-sequence-pending';
    await MobileApi.instance.adminSaveProductionMap(
      _twoStageProductionOrderMap(
        id: completedOrderId,
        title: 'Admin sequence completed order',
        productCode: 'ASC-A',
        product: 'admin sequence completed product',
        firstApparatus: apparatus,
        secondApparatus: 'Laminatsiya 1',
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: pendingOrderId,
        title: 'Admin sequence pending order',
        productCode: 'ASC-B',
        apparatus: apparatus,
        product: 'admin sequence pending product',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [completedOrderId, pendingOrderId],
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: 'Laminatsiya 1',
      orderIds: const [completedOrderId],
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: completedOrderId,
      action: 'start',
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: completedOrderId,
      action: 'complete',
      producedQty: 12,
      grossQty: 9,
      uom: 'm',
    );

    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ketma-ketlik'));
    await tester.pumpAndSettle();

    expect(find.text('1 ta zakaz'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sequence-$apparatus-$completedOrderId')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('sequence-$apparatus-$pendingOrderId')),
      findsOneWidget,
    );

    await tester.tap(find.text('Aparat: $apparatus'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('admin-filter-option-Laminatsiya 1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 ta zakaz'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('sequence-Laminatsiya 1-$completedOrderId'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('order actions open by long press in orders and sequence tabs', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-order-actions',
        title: 'Action menu order',
        productCode: 'ACTION-1',
        apparatus: 'Godex aparat - DEMO',
        product: 'action product',
      ),
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('Action menu order').first);
    await tester.pumpAndSettle();
    expect(find.text('Muzlatish'), findsOneWidget);
    expect(find.text('O‘chirish'), findsOneWidget);
    expect(find.text('Mapni o‘zgartirish'), findsOneWidget);
    Navigator.of(tester.element(find.text('Muzlatish'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ketma-ketlik'));
    await tester.pumpAndSettle();
    await tester.longPress(find.textContaining('Action menu order').first);
    await tester.pumpAndSettle();
    expect(find.text('Muzlatish'), findsOneWidget);
    expect(find.text('O‘chirish'), findsOneWidget);
    expect(find.text('Mapni o‘zgartirish'), findsOneWidget);
  });

  testWidgets('map action opens the selected order with started nodes locked', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Godex aparat - DEMO';
    const orderId = 'zakaz-map-action-selected';
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: orderId,
        title: 'Selected map action order',
        productCode: 'MAP-ACTION-1',
        apparatus: apparatus,
        product: 'selected product',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'start',
    );
    ProductionMapTestArgs? openedArgs;

    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.adminProductionMapTest) {
            openedArgs = settings.arguments as ProductionMapTestArgs?;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Selected editor')),
            );
          }
          return null;
        },
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.textContaining('Selected map action order').first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mapni o‘zgartirish'));
    await tester.pumpAndSettle();

    expect(find.text('Selected editor'), findsOneWidget);
    expect(openedArgs?.savedMap?.id, orderId);
    expect(openedArgs?.lockedNodeIds, contains('apparatus'));
  });

  testWidgets('order action menu follows requested and frozen states', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Godex aparat - DEMO';
    const orderId = 'zakaz-order-control-states';
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: orderId,
        title: 'Control state order',
        productCode: 'CONTROL-1',
        apparatus: apparatus,
        product: 'control product',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'start',
    );
    expect(
      await MobileApi.instance.adminProductionMapOrderControl(
        orderId: orderId,
        action: AdminOrderControlAction.freeze,
      ),
      AdminOrderControlState.freezeRequested,
    );

    Future<void> pumpScreen() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    await _usePhoneViewport(tester);
    await pumpScreen();
    await tester.longPress(find.textContaining('Control state order').first);
    await tester.pumpAndSettle();
    expect(find.text('Muzlatish so‘rovini bekor qilish'), findsOneWidget);
    expect(find.text('O‘chirish'), findsNothing);
    Navigator.of(
      tester.element(find.text('Muzlatish so‘rovini bekor qilish')),
    ).pop();
    await tester.pumpAndSettle();

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'pause',
      producedQty: 1,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpScreen();
    await tester.longPress(find.textContaining('Control state order').first);
    await tester.pumpAndSettle();
    expect(find.text('Muzdan chiqarish'), findsOneWidget);
    expect(find.text('O‘chirish'), findsNothing);
  });

  testWidgets('opened orders move module moves only compatible pechat orders', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-move-ok',
        title: 'Move ok order',
        productCode: 'MOVE-OK',
        apparatus: '8 ta rangli bosma aparat',
        product: 'move ok product',
        rollCount: 7,
        widthMm: 650,
        apparatusCopies: 2,
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-move-blocked',
        title: 'Move blocked order',
        productCode: 'MOVE-BLOCK',
        apparatus: '8 ta rangli bosma aparat',
        product: 'move blocked product',
        rollCount: 8,
        widthMm: 700,
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-move-target',
        title: 'Move target order',
        productCode: 'MOVE-TARGET',
        apparatus: '7 ta rangli bosma aparat',
        product: 'move target product',
        rollCount: 7,
        widthMm: 650,
      ),
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ko‘chirish'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tester.tap(find.text('Ko‘chirish'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.textContaining('Move ok order'), findsOneWidget);
    expect(find.textContaining('Move blocked order'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('move-boundary-apparatus-picker')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aparat tanlang'), findsOneWidget);
    expect(find.text('Tanlangan'), findsNothing);
    expect(find.text('Tanlanmagan'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await _dragOrderTitleToTopZone(
      tester,
      orderTitle: 'Move ok order',
      targetText: 'Move target order',
    );
    var maps = await MobileApi.instance.adminProductionMaps();
    expect(_apparatusTitle(maps, 'zakaz-move-ok'), '8 ta rangli bosma aparat');
    expect(find.textContaining('Move target order'), findsOneWidget);

    await _dragOrderHandleForKeyToTopZone(
      tester,
      key: const ValueKey(
        'move-order-8 ta rangli bosma aparat-zakaz-move-ok',
      ),
      targetText: 'Move target order',
    );
    expect(find.textContaining('Move ok order'), findsOneWidget);
    maps = await MobileApi.instance.adminProductionMaps();
    expect(_apparatusTitle(maps, 'zakaz-move-ok'), '7 ta rangli bosma aparat');
    expect(
      _apparatusTitles(maps, 'zakaz-move-ok'),
      isNot(contains('8 ta rangli bosma aparat')),
    );
    maps = await MobileApi.instance.adminProductionMaps();
    expect(_apparatusTitle(maps, 'zakaz-move-blocked'),
        '8 ta rangli bosma aparat');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'opened orders move module hides cross-family Flexo and color orders',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: 'zakaz-ui-flexo-node-only',
          title: 'ABCD Family',
          productCode: 'ABCD Family',
          apparatus: 'Flexo pechat',
          product: 'ABCD Family',
          orderNumber: '1119',
          rollCount: 7,
          widthMm: 765,
        ),
      );
      await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: 'zakaz-ui-color-node-only',
          title: 'Imperator salyami',
          productCode: 'Imperator salyami',
          apparatus: '7 ta rangli bosma aparat',
          product: 'Imperator salyami',
          orderNumber: '0002',
          rollCount: 7,
          widthMm: 515,
        ),
      );
      await _usePhoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ko‘chirish'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('move-boundary-apparatus-picker')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flexo pechat').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('ABCD Family'), findsNothing);
      expect(find.textContaining('Imperator salyami'), findsNothing);
      expect(
        find.text('7 ta rangli bosma aparat uchun zakaz yo‘q'),
        findsOneWidget,
      );
      expect(find.text('Flexo pechat uchun zakaz yo‘q'), findsOneWidget);
    },
  );

  testWidgets('opened orders move module transfers paused order with reason', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    const source = '7 ta rangli bosma aparat';
    const target = '8 ta rangli bosma aparat';
    const orderId = 'zakaz-paused-ui-transfer';
    const targetOrderId = 'zakaz-paused-ui-target';
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: orderId,
        title: 'Paused UI transfer order',
        productCode: 'PUT-1',
        apparatus: source,
        product: 'paused UI transfer product',
        rollCount: 7,
        widthMm: 650,
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: targetOrderId,
        title: 'Paused UI target order',
        productCode: 'PUT-2',
        apparatus: target,
        product: 'paused UI target product',
        rollCount: 7,
        widthMm: 650,
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: source,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: target,
      orderIds: const [targetOrderId],
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: source,
      orderId: orderId,
      action: 'start',
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: source,
      orderId: orderId,
      action: 'pause',
      producedQty: 4,
    );

    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ko‘chirish'));
    await tester.pumpAndSettle();

    await _dragOrderHandleToBottomZone(
      tester,
      orderTitle: 'Paused UI transfer order',
      targetText: 'Paused UI target order',
    );
    expect(find.text('Avariya sababini kiriting'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('apparatus-transfer-reason')),
      '7 rangli pechat apparati buzildi',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Ko‘chirish'));
    await tester.pumpAndSettle();

    final snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
    expect(snapshot.queueStates[source]?[orderId], isNull);
    expect(snapshot.queueStates[target]?[orderId], 'paused');
    final maps = await MobileApi.instance.adminProductionMaps();
    expect(_apparatusTitle(maps, orderId), target);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('opened orders move module moves every selected pechat order', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    for (var index = 0; index < 2; index++) {
      await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: 'zakaz-batch-move-$index',
          title: 'Batch move order ${index + 1}',
          productCode: 'BATCH-$index',
          apparatus: '7 ta rangli bosma aparat',
          product: 'batch move product ${index + 1}',
          rollCount: 7,
          widthMm: 650,
        ),
      );
    }
    for (var index = 2; index < 4; index++) {
      final map = _alternativeProductionOrderMap(
        id: 'zakaz-batch-move-$index',
        title: 'Batch move order ${index + 1}',
        productCode: 'BATCH-$index',
        product: 'batch move product ${index + 1}',
        apparatus: const [
          '7 ta rangli bosma aparat',
          '8 ta rangli bosma aparat'
        ],
        rollCount: 7,
        widthMm: 650,
      );
      await MobileApi.instance.adminSaveProductionMap(
        map.copyWith(
          nodes: [
            for (final node in map.nodes)
              node.kind == 'apparatus'
                  ? node.copyWith(
                      alternativeAssignedTitle: '7 ta rangli bosma aparat',
                    )
                  : node,
          ],
        ),
      );
    }
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-batch-move-target',
        title: 'Batch move target order',
        productCode: 'BATCH-TARGET',
        apparatus: '8 ta rangli bosma aparat',
        product: 'batch move target product',
        rollCount: 7,
        widthMm: 650,
      ),
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ko‘chirish'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 4; index++) {
      await _tapMoveOrderBadge(
        tester,
        key: ValueKey(
            'move-order-7 ta rangli bosma aparat-zakaz-batch-move-$index'),
      );
    }

    await _dragOrderHandleToBottomZone(
      tester,
      orderTitle: 'Batch move order 1',
      targetText: 'Batch move target order',
    );

    final maps = await MobileApi.instance.adminProductionMaps();
    for (var index = 0; index < 2; index++) {
      expect(
        _apparatusTitle(maps, 'zakaz-batch-move-$index'),
        '8 ta rangli bosma aparat',
      );
    }
    for (var index = 2; index < 4; index++) {
      expect(_alternativeAssignedTitles(maps, 'zakaz-batch-move-$index'), [
        '8 ta rangli bosma aparat',
        '8 ta rangli bosma aparat',
      ]);
    }
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'opened orders move module blocks 9-color rubber orders on 7-color pechat',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: 'zakaz-move-9-only',
          title: 'Nine color rubber order',
          productCode: 'MOVE-9',
          apparatus: '8 ta rangli bosma aparat',
          product: 'nine color product',
          rollCount: 7,
          widthMm: 1250,
        ),
      );
      await _usePhoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ko‘chirish'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nine color rubber order'), findsNothing);

      final maps = await MobileApi.instance.adminProductionMaps();
      expect(_apparatusTitle(maps, 'zakaz-move-9-only'),
          '8 ta rangli bosma aparat');
    },
  );

  testWidgets(
    'opened orders move module keeps direct orders out of unassigned',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: 'zakaz-direct-pechat',
          title: 'Direct pechat order',
          productCode: 'DIRECT-7',
          apparatus: '7 ta rangli bosma aparat',
          product: 'direct product',
          rollCount: 7,
          widthMm: 650,
        ),
      );
      await _usePhoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ko‘chirish'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey(
              'move-order-7 ta rangli bosma aparat-zakaz-direct-pechat'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('move-boundary-apparatus-picker')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tanlanmagan'));
      await tester.pumpAndSettle();
      expect(find.text('Tanlanmagan zakaz yo‘q'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey(
              'move-order-7 ta rangli bosma aparat-zakaz-direct-pechat'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('move-order-Tanlanmagan-zakaz-direct-pechat'),
        ),
        findsNothing,
      );
      final maps = await MobileApi.instance.adminProductionMaps();
      expect(_apparatusTitles(maps, 'zakaz-direct-pechat'), [
        '7 ta rangli bosma aparat',
      ]);
    },
  );

  testWidgets(
    'opened orders move module can assign an unassigned alternative to target',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      await MobileApi.instance.adminSaveProductionMap(
        _alternativeProductionOrderMap(
          id: 'zakaz-alt-unassigned-move',
          title: 'Unassigned alternative move order',
          productCode: 'ALT-UNASSIGNED-MOVE',
          product: 'unassigned alternative move product',
          apparatus: const [
            '7 ta rangli bosma aparat',
            '8 ta rangli bosma aparat',
          ],
          rollCount: 7,
          widthMm: 650,
        ),
      );
      await _usePhoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ko‘chirish'));
      await tester.pumpAndSettle();
      const orderKey = ValueKey(
        'move-order-7 ta rangli bosma aparat-zakaz-alt-unassigned-move',
      );
      expect(find.byKey(orderKey), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey(
            'move-order-disabled-7 ta rangli bosma aparat-'
            'zakaz-alt-unassigned-move',
          ),
        ),
        findsNothing,
      );

      await _dragOrderHandleForKeyToBottomZone(
        tester,
        key: orderKey,
      );

      final maps = await MobileApi.instance.adminProductionMaps();
      expect(
        _alternativeAssignedTitles(maps, 'zakaz-alt-unassigned-move'),
        [
          '8 ta rangli bosma aparat',
          '8 ta rangli bosma aparat',
        ],
      );
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('opened orders move picker hides opposite selected apparatus', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ko‘chirish'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('move-boundary-apparatus-picker')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('7 ta rangli bosma aparat'), findsNWidgets(2));
    Navigator.of(tester.element(find.text('Aparat tanlang'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('move-top-apparatus-picker')));
    await tester.pumpAndSettle();
    expect(find.textContaining('8 ta rangli bosma aparat'), findsNWidgets(2));
  });

  testWidgets('opened orders move top apparatus picker is centered', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ko‘chirish'));
    await tester.pumpAndSettle();

    final pickerRect = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('move-top-apparatus-picker')),
        matching: find.textContaining('7 ta rangli bosma aparat'),
      ),
    );
    final screenCenterX = tester.getSize(find.byType(MaterialApp)).width / 2;
    expect((pickerRect.center.dx - screenCenterX).abs(), lessThan(8));
  });

  testWidgets('opened orders move module boundary resizes zones', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-resize-a',
        title: 'Resize top order',
        productCode: 'RESIZE-A',
        apparatus: '7 ta rangli bosma aparat',
        product: 'resize product a',
        rollCount: 7,
        widthMm: 650,
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-resize-b',
        title: 'Resize bottom order',
        productCode: 'RESIZE-B',
        apparatus: '8 ta rangli bosma aparat',
        product: 'resize product b',
        rollCount: 7,
        widthMm: 650,
      ),
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ko‘chirish'));
    await tester.pumpAndSettle();
    final boundary = find.byKey(
      const ValueKey('move-boundary-apparatus-picker'),
    );
    final before = tester.getTopLeft(boundary).dy;
    final gesture = await tester.startGesture(tester.getCenter(boundary));
    await gesture.moveBy(const Offset(0, 160));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(boundary).dy, greaterThan(before + 40));
  });

  testWidgets(
    'opened orders picker unassigned card shows skipped alternatives in move zone',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      await MobileApi.instance.adminSaveProductionMap(
        _alternativeProductionOrderMap(
          id: 'zakaz-skip-7-8',
          title: 'Skipped pechat order',
          productCode: 'SKIP-78',
          product: 'skipped product',
          apparatus: const [
            '7 ta rangli bosma aparat',
            '8 ta rangli bosma aparat'
          ],
          rollCount: 7,
          widthMm: 650,
        ),
      );
      await MobileApi.instance.adminSaveProductionMap(
        _alternativeProductionOrderMap(
          id: 'zakaz-skip-9',
          title: 'Skipped nine order',
          productCode: 'SKIP-9',
          product: 'skipped nine product',
          apparatus: const ['9 ta rangli bosma aparat'],
          rollCount: 9,
          widthMm: 900,
        ),
      );
      await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: 'zakaz-skip-target-7',
          title: 'Skip target seven order',
          productCode: 'SKIP-TARGET-7',
          apparatus: '7 ta rangli bosma aparat',
          product: 'skip target seven product',
          rollCount: 7,
          widthMm: 650,
        ),
      );
      await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: 'zakaz-skip-target-8',
          title: 'Skip target eight order',
          productCode: 'SKIP-TARGET-8',
          apparatus: '8 ta rangli bosma aparat',
          product: 'skip target product',
          rollCount: 7,
          widthMm: 650,
        ),
      );
      await _usePhoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ko‘chirish'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('move-boundary-apparatus-picker')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tanlangan'), findsNothing);
      expect(find.text('Tanlanmagan'), findsOneWidget);
      await tester.tap(find.text('Tanlanmagan'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('move-order-Tanlanmagan-zakaz-skip-7-8')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('move-order-Tanlanmagan-zakaz-skip-9')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('move-order-7 ta rangli bosma aparat-zakaz-skip-7-8'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey(
            'move-order-disabled-7 ta rangli bosma aparat-zakaz-skip-7-8',
          ),
        ),
        findsOneWidget,
      );

      await _dragOrderHandleForKeyToTopDropZone(
        tester,
        key: const ValueKey('move-order-Tanlanmagan-zakaz-skip-7-8'),
      );

      expect(
        find.byKey(const ValueKey('move-order-Tanlanmagan-zakaz-skip-7-8')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('move-order-7 ta rangli bosma aparat-zakaz-skip-7-8'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'move-order-disabled-7 ta rangli bosma aparat-zakaz-skip-7-8',
          ),
        ),
        findsNothing,
      );
      final maps = await MobileApi.instance.adminProductionMaps();
      expect(_apparatusTitles(maps, 'zakaz-skip-7-8'), [
        '7 ta rangli bosma aparat',
        '8 ta rangli bosma aparat',
      ]);
      expect(_alternativeGroupIds(maps, 'zakaz-skip-7-8'), isNotEmpty);
      expect(_alternativeAssignedTitles(maps, 'zakaz-skip-7-8'), [
        '7 ta rangli bosma aparat',
        '7 ta rangli bosma aparat',
      ]);

      await _dragOrderHandleForKeyToZone(
        tester,
        key: const ValueKey(
          'move-order-7 ta rangli bosma aparat-zakaz-skip-7-8',
        ),
        targetText: 'Tanlanmagan zakaz yo‘q',
      );

      expect(
        find.byKey(const ValueKey('move-order-Tanlanmagan-zakaz-skip-7-8')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'move-order-disabled-7 ta rangli bosma aparat-zakaz-skip-7-8',
          ),
        ),
        findsOneWidget,
      );
      final returnedMaps = await MobileApi.instance.adminProductionMaps();
      expect(_apparatusTitles(returnedMaps, 'zakaz-skip-7-8'), [
        '7 ta rangli bosma aparat',
        '8 ta rangli bosma aparat',
      ]);
      expect(_alternativeGroupIds(returnedMaps, 'zakaz-skip-7-8'), isNotEmpty);
      expect(
        _alternativeAssignedTitles(returnedMaps, 'zakaz-skip-7-8'),
        isEmpty,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('move-top-apparatus-picker')),
          matching: find.textContaining('7 ta rangli bosma aparat'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('8 ta rangli bosma aparat').first);
      await tester.pumpAndSettle();

      await _dragOrderHandleForKeyToTopDropZone(
        tester,
        key: const ValueKey('move-order-Tanlanmagan-zakaz-skip-7-8'),
      );

      expect(
        find.byKey(
          const ValueKey('move-order-8 ta rangli bosma aparat-zakaz-skip-7-8'),
        ),
        findsOneWidget,
      );
      final assignedToEightMaps =
          await MobileApi.instance.adminProductionMaps();
      expect(
        _alternativeAssignedTitles(assignedToEightMaps, 'zakaz-skip-7-8'),
        ['8 ta rangli bosma aparat', '8 ta rangli bosma aparat'],
      );
      await tester.pump(const Duration(seconds: 3));
    },
  );

  test('test mode queue snapshot exposes skipped alternative candidates',
      () async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveProductionMap(
      _alternativeProductionOrderMap(
        id: 'zakaz-visible-skip',
        title: 'Visible skipped order',
        productCode: 'VISIBLE-SKIP',
        product: 'visible skipped product',
        apparatus: const [
          '7 ta rangli bosma aparat',
          '8 ta rangli bosma aparat',
        ],
        rollCount: 7,
        widthMm: 650,
      ),
    );

    final snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();

    expect(
      snapshot.visibleOrderIds['7 ta rangli bosma aparat'],
      contains('zakaz-visible-skip'),
    );
    expect(
      snapshot.visibleOrderIds['8 ta rangli bosma aparat'],
      contains('zakaz-visible-skip'),
    );
  });

  testWidgets('opened orders move module keeps laminatsiya skips unassigned', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    final map = _chainedAlternativeProductionOrderMap(
      id: 'zakaz-laminatsiya-skip',
      title: 'Skipped laminatsiya order',
      productCode: 'LAM-SKIP',
      product: 'laminatsiya skipped product',
      firstGroupApparatus: const [
        '7 ta rangli bosma aparat',
        '8 ta rangli bosma aparat'
      ],
      secondGroupApparatus: const ['Laminatsiya 1', 'Laminatsiya 2'],
      firstGroupAssignedTitle: '7 ta rangli bosma aparat',
      rollCount: 7,
      widthMm: 650,
    );
    await MobileApi.instance.adminSaveProductionMap(map);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ko‘chirish'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-top-apparatus-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laminatsiya 1').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('move-boundary-apparatus-picker')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanlanmagan'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('move-order-Laminatsiya 1-zakaz-laminatsiya-skip'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('move-order-Tanlanmagan-zakaz-laminatsiya-skip'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('apparatus queue worker view is read only', (tester) async {
    await TestModeController.instance.setEnabled(true);
    await AppSession.instance.setSession(
      token: 'worker-token',
      profile: const SessionProfile(
        role: UserRole.werka,
        displayName: 'Aparatchi',
        legalName: '',
        ref: 'werka',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: ['7 ta rangli bosma aparat'],
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-worker-queue',
        title: 'Worker queue order',
        productCode: 'WRK-A',
        apparatus: '7 ta rangli bosma aparat',
        product: 'worker mahsulot',
      ).copyWith(customerName: '555 kukuruz'),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-worker-queue-2',
        title: 'Worker queue order 2',
        productCode: 'WRK-B',
        apparatus: '7 ta rangli bosma aparat',
        product: 'worker mahsulot 2',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: '7 ta rangli bosma aparat',
      orderIds: const ['zakaz-worker-queue', 'zakaz-worker-queue-2'],
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
          progressDriverUrlPicker: _testProgressDriverUrlPicker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buyurtmalar'), findsNothing);
    expect(find.text('Ochilgan zakaz qidirish'), findsOneWidget);
    expect(find.text('Godex aparat - DEMO'), findsOneWidget);
    expect(find.text('7 ta rangli bosma'), findsOneWidget);
    expect(find.text('Aparatlar'), findsNothing);
    expect(find.textContaining('Worker queue order'), findsNWidgets(2));
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    expect(find.text('Sizning aparatingiz'), findsOneWidget);
    expect(find.text('Boshlash'), findsNothing);

    await tester.tap(find.text('7 ta rangli bosma'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('worker-queue').first);
    await tester.pumpAndSettle();

    expect(find.text('Boshlash'), findsOneWidget);
    expect(find.text('Tugatish'), findsNothing);

    await tester.tap(find.text('Boshlash'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _completeQolipScan(tester);

    expect(find.text('Tugatish'), findsOneWidget);
    expect(find.text('Boshlash'), findsNothing);

    await tester.tap(find.text('Tugatish'));
    await tester.pumpAndSettle();
    final tayyorMahsulotY = tester.getTopLeft(find.text('Tayyor mahsulot')).dy;
    final qaytimChiqindiY =
        tester.getTopLeft(find.text('Qaytim va chiqindi')).dy;
    final jamiChiqindiY = tester.getTopLeft(find.text('Jami chiqindi')).dy;
    final qaytarilganBoyoqY =
        tester.getTopLeft(find.text("Qaytarilgan bo'yoq")).dy;
    expect(tayyorMahsulotY, lessThan(qaytimChiqindiY));
    expect(jamiChiqindiY, lessThan(qaytarilganBoyoqY));
    await tester.tap(find.text("Qaytarilgan bo'yoq"));
    await tester.pumpAndSettle();
    for (final paint in const [
      'Oq',
      'Sariq',
      'Qizil',
      'Ko‘k',
      'Lak',
      'Tilla',
      'Kumush',
      'Qora',
      'Mix',
      'Pantone',
      'Spirtlar',
    ]) {
      expect(find.byTooltip(paint), findsOneWidget);
    }
    final usageTabBar = find.byType(TabBar).last;
    final usagePageView = find.byType(TabBarView).last;
    expect(tester.widget<TabBar>(usageTabBar).controller?.index, 0);
    await tester.drag(usagePageView, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(usageTabBar).controller?.index, 1);
    await tester.drag(usagePageView, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(usageTabBar).controller?.index, 0);
    await tester.tap(find.text('Astatka'));
    await tester.pumpAndSettle();
    for (final paint in const [
      'Oq',
      'Sariq',
      'Qizil',
      'Ko‘k',
      'Lak',
      'Tilla',
      'Kumush',
      'Qora',
      'Mix',
      'Pantone',
      'Spirtlar',
    ]) {
      expect(find.byTooltip(paint), findsOneWidget);
    }
    await tester.tap(find.text('Rasxot'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNWidgets(2));
    await tester.tap(find.byTooltip('Oq'));
    await tester.pumpAndSettle();
    for (final field in const [
      'Mix',
      '1w Oq',
      '7w Oq',
      'Qora',
      'Sariq',
      'Qizil',
      'Ko‘k',
      'Spirt',
    ]) {
      expect(find.text(field), findsOneWidget);
    }
    expect(find.widgetWithText(TextFormField, 'Pantone+'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Pantone+'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Pantone+'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('returned-paint-field-name')),
      'Pantone Blue',
    );
    await tester.enterText(
      find.byKey(const ValueKey('returned-paint-field-value')),
      '12',
    );
    await tester.tap(
      find.byKey(const ValueKey('returned-paint-confirm-field-name')),
    );
    await tester.pumpAndSettle();
    final returnedFields = find.descendant(
      of: find.byKey(const ValueKey('returned-paint-fields')),
      matching: find.byType(TextFormField),
    );
    expect(returnedFields, findsNWidgets(9));
    expect(find.widgetWithText(OutlinedButton, 'Pantone+'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Pantone+'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('returned-paint-field-name')),
      'Pantone Red',
    );
    await tester.enterText(
      find.byKey(const ValueKey('returned-paint-field-value')),
      '5',
    );
    await tester.tap(
      find.byKey(const ValueKey('returned-paint-confirm-field-name')),
    );
    await tester.pumpAndSettle();
    expect(returnedFields, findsNWidgets(10));
    expect(find.byType(BottomSheet), findsNWidgets(2));
    expect(find.byTooltip('Orqaga'), findsOneWidget);
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Orqaga'), findsOneWidget);
    expect(find.byTooltip('Oq'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Mix'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Mix+'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('returned-paint-field-name')),
      'Batch A',
    );
    await tester.enterText(
      find.byKey(const ValueKey('returned-paint-field-value')),
      '43',
    );
    await tester.tap(
      find.byKey(const ValueKey('returned-paint-confirm-field-name')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Astatka'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    await tester.tap(find.byTooltip('Mix'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Mix+'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('returned-paint-field-name')),
      'Batch A',
    );
    await tester.enterText(
      find.byKey(const ValueKey('returned-paint-field-value')),
      '17',
    );
    await tester.tap(
      find.byKey(const ValueKey('returned-paint-confirm-field-name')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Batch A'))
          .controller
          ?.text,
      '17',
    );
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rasxot'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mix'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Batch A'))
          .controller
          ?.text,
      '43',
    );
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Spirtlar'));
    await tester.pumpAndSettle();
    for (final field in const [
      'Aralashmalar',
      'Etil',
      'Metoxil',
      'Rasvavitel',
      'Izopropel',
    ]) {
      expect(find.text(field), findsOneWidget);
    }
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lak'));
    await tester.pumpAndSettle();
    expect(find.text('OPV lak'), findsOneWidget);
    expect(find.text('MAT lak'), findsOneWidget);
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mix'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Batch A'))
          .controller
          ?.text,
      '43',
    );
    Navigator.of(tester.element(find.byType(BottomSheet).first)).pop();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Jami chiqindi'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Metraj'),
      '12',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, "Og'irlik"),
      '3',
    );
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();

    expect(find.text('Tugatish'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Boshlash'), findsNothing);
  });

  testWidgets('worker intake shows and expands only pending assigned material',
      (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Rezka';
    const orderId = 'zakaz-worker-material-intake';
    const candidateBarcode = 'ROLL-WORKER-ASSIGNED';
    const stateLocation = InventoryLocation(
      id: 'inventory_location:state:rezka-intake',
      kind: InventoryLocationKind.state,
      name: 'Rezka State',
      factoryLocationId: 'state_rezka_intake',
      apparatus: [
        InventoryLocationApparatus(id: 'rezka-intake', name: apparatus),
      ],
    );
    seedMobileApiInventoryMovementTestData(
      locations: const [stateLocation],
      assets: const [
        InventoryAsset(
          kind: InventoryAssetKind.rawMaterial,
          assetRef: 'raw:worker-intake-assigned',
          custodyWarehouseId: 'warehouse:material',
          custodyWarehouse: 'Material ombor',
          itemCode: 'ROLL-WORKER',
          itemName: 'Worker assigned material',
          identifier: candidateBarcode,
          qty: 100,
          uom: 'kg',
          status: 'available',
          physicalLocation: InventoryLocationReference(
            id: 'inventory_location:state:rezka-intake',
            kind: InventoryLocationKind.state,
            name: 'Rezka State',
          ),
        ),
      ],
    );
    await AppSession.instance.setSession(
      token: 'worker-material-intake-token',
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Rezka operatori',
        legalName: '',
        ref: 'worker-material-intake',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [apparatus],
      ),
    );
    await MobileApi.instance.adminCreateApparatus(apparatus);
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: orderId,
        title: 'Worker material intake',
        productCode: 'WMI-A',
        apparatus: apparatus,
        product: 'worker material product',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminApparatusQueueAction(
      apparatus: apparatus,
      orderId: orderId,
      action: 'start',
    );
    await MobileApi.instance.adminAssignRawMaterialToOrder(
      orderId: orderId,
      apparatus: apparatus,
      barcode: candidateBarcode,
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(apparatus));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('worker-material-intake').first);
    await tester.pumpAndSettle();
    expect(find.text('Ish boshlash uchun homashyolar'), findsNothing);
    expect(find.text('Hali qabul qilinmagan homashyolar'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('production-intake-materials-expansion'),
        ),
        matching: find.text('1 ta'),
      ),
      findsOneWidget,
    );
    expect(find.text(candidateBarcode), findsNothing);
    expect(
      find.byKey(const ValueKey('receive-additional-raw-material')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('receive-additional-raw-material')),
    );
    await tester.pumpAndSettle();
    expect(find.text(candidateBarcode), findsOneWidget);
    expect(
      find.byKey(const ValueKey('production-quick-scanner-manual-toggle')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('production-quick-scanner-manual-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('production-quick-scanner-manual')),
      'ROLL-WORKER-1000',
    );
    await tester.tap(find.byTooltip('Qabul qilish'));
    await tester.pumpAndSettle();
    expect(find.text('Homashyo biriktirilmagan'), findsWidgets);
    expect(find.text('ROLL-WORKER-1000'), findsNothing);
    expect(find.text(candidateBarcode), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('production-quick-scanner-manual')),
      candidateBarcode,
    );
    await tester.tap(find.byTooltip('Qabul qilish'));
    await tester.pumpAndSettle();
    expect(find.text('Hali qabul qilinmagan homashyo yo‘q'), findsOneWidget);
    expect(find.text('0 ta'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('production-quick-scanner-manual')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('worker order cards use the shared production status colors', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Godex aparat - DEMO';
    const orderId = 'zakaz-worker-status-colors';
    await AppSession.instance.setSession(
      token: 'worker-status-colors-token',
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Aparatchi',
        legalName: '',
        ref: 'worker-status-colors',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [apparatus],
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: orderId,
        title: 'Worker status colors',
        productCode: 'WSC',
        apparatus: apparatus,
        product: 'worker status colors product',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'start',
    );
    await _usePhoneViewport(tester);
    final theme = ThemeData(useMaterial3: true);

    Future<void> pumpWorkerScreen() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Color cardColor() {
      final row = find.byKey(const ValueKey('worker-order-$orderId'));
      expect(row, findsOneWidget);
      return tester
          .widget<Material>(
            find.descendant(of: row, matching: find.byType(Material)).first,
          )
          .color!;
    }

    Color expectedTint(Color accent) {
      return Color.alphaBlend(
        accent.withValues(alpha: 0.16),
        theme.colorScheme.surfaceContainerLowest,
      );
    }

    await pumpWorkerScreen();
    expect(cardColor(), expectedTint(const Color(0xFF2E7D32)));

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'pause',
      producedQty: 1,
    );
    await pumpWorkerScreen();
    expect(cardColor(), expectedTint(const Color(0xFFF9A825)));

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'resume',
    );
    expect(
      await MobileApi.instance.adminProductionMapOrderControl(
        orderId: orderId,
        action: AdminOrderControlAction.freeze,
      ),
      AdminOrderControlState.freezeRequested,
    );
    await pumpWorkerScreen();
    expect(cardColor(), expectedTint(const Color(0xFF1565C0)));
  });

  testWidgets('opened order cards color active laminatsiya stages', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Laminatsiya 1';
    const orderId = 'zakaz-opened-laminatsiya-status-colors';
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: orderId,
        title: 'Opened laminatsiya status colors',
        productCode: 'OLSC',
        apparatus: apparatus,
        product: 'opened laminatsiya status colors product',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'start',
    );
    await _usePhoneViewport(tester);
    final theme = ThemeData(useMaterial3: true);

    Future<void> pumpAdminScreen() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Color cardColor() {
      final row = find.byKey(const ValueKey('opened-order-$orderId'));
      expect(row, findsOneWidget);
      return tester
          .widget<Material>(
            find.descendant(of: row, matching: find.byType(Material)).first,
          )
          .color!;
    }

    Color expectedTint(Color accent) {
      return Color.alphaBlend(
        accent.withValues(alpha: 0.16),
        theme.colorScheme.surfaceContainerLowest,
      );
    }

    await pumpAdminScreen();
    expect(cardColor(), expectedTint(const Color(0xFF2E7D32)));

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'pause',
      producedQty: 1,
    );
    await pumpAdminScreen();
    expect(cardColor(), expectedTint(const Color(0xFFF9A825)));
  });

  testWidgets('opened order cards refresh after another worker pauses', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Laminatsiya 1';
    const orderId = 'zakaz-opened-laminatsiya-live-pause';
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: orderId,
        title: 'Opened laminatsiya live pause',
        productCode: 'OLLP',
        apparatus: apparatus,
        product: 'opened laminatsiya live pause product',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'start',
    );
    await _usePhoneViewport(tester);
    final theme = ThemeData(useMaterial3: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    Color cardColor() {
      final row = find.byKey(const ValueKey('opened-order-$orderId'));
      expect(row, findsOneWidget);
      return tester
          .widget<Material>(
            find.descendant(of: row, matching: find.byType(Material)).first,
          )
          .color!;
    }

    Color expectedTint(Color accent) {
      return Color.alphaBlend(
        accent.withValues(alpha: 0.16),
        theme.colorScheme.surfaceContainerLowest,
      );
    }

    expect(cardColor(), expectedTint(const Color(0xFF2E7D32)));

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'pause',
      producedQty: 1,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(cardColor(), expectedTint(const Color(0xFFF9A825)));
  });

  testWidgets('worker completed orders move to own completed tab', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await AppSession.instance.setSession(
      token: 'worker-completed-token',
      profile: const SessionProfile(
        role: UserRole.werka,
        displayName: 'Aparatchi',
        legalName: '',
        ref: 'worker-completed-1',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: ['7 ta rangli bosma aparat'],
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-worker-completed-1',
        title: 'Worker completed order 1',
        productCode: 'WCD-A',
        apparatus: '7 ta rangli bosma aparat',
        product: 'worker completed mahsulot 1',
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-worker-completed-2',
        title: 'Worker completed order 2',
        productCode: 'WCD-B',
        apparatus: '7 ta rangli bosma aparat',
        product: 'worker completed mahsulot 2',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: '7 ta rangli bosma aparat',
      orderIds: const [
        'zakaz-worker-completed-1',
        'zakaz-worker-completed-2',
      ],
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
          progressDriverUrlPicker: _testProgressDriverUrlPicker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tugallangan'), findsOneWidget);
    expect(find.textContaining('Worker completed order 1'), findsOneWidget);

    await tester.tap(find.textContaining('worker-completed-1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boshlash'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _completeQolipScan(tester);
    await tester.tap(find.text('Tugatish'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Jami chiqindi'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Metraj'),
      '12',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, "Og'irlik"),
      '3',
    );
    await tester.tap(find.text("Qaytarilgan bo'yoq"));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Oq'));
    await tester.pumpAndSettle();
    final completedOrderReturnedPaintFields = find.descendant(
      of: find.byKey(const ValueKey('returned-paint-fields')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(completedOrderReturnedPaintFields.at(0), '1');
    await tester.enterText(completedOrderReturnedPaintFields.at(1), '2');
    await tester.enterText(completedOrderReturnedPaintFields.at(2), '3');
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Astatka'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Oq'));
    await tester.pumpAndSettle();
    final completedOrderAstatkaFields = find.descendant(
      of: find.byKey(const ValueKey('returned-paint-fields')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(completedOrderAstatkaFields.at(0), '1');
    await tester.enterText(completedOrderAstatkaFields.at(1), '2');
    await tester.enterText(completedOrderAstatkaFields.at(2), '3');
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.textContaining('Worker completed order 1'), findsNothing);

    await tester.tap(find.text('Tugallangan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Worker completed order 1'), findsOneWidget);
    expect(find.textContaining('Worker completed order 2'), findsNothing);
  });

  testWidgets('bosma worker progress dialogs use bosma metric fields', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await AppSession.instance.setSession(
      token: 'worker-bosma-dialog-token',
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Bosma aparatchi',
        legalName: '',
        ref: 'worker-bosma-dialog',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: ['7 ta rangli bosma'],
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-bosma-dialog',
        title: 'Bosma dialog order',
        productCode: 'BSD-A',
        apparatus: '7 ta rangli bosma',
        product: 'bosma dialog mahsulot',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: '7 ta rangli bosma',
      orderIds: const ['zakaz-bosma-dialog'],
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('7 ta rangli bosma'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('bosma-dialog').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boshlash'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _completeQolipScan(tester);

    await tester.tap(find.text('Tugatish'));
    await tester.pumpAndSettle();

    expect(find.text("Qaytarilgan bo'yoq"), findsOneWidget);
    expect(find.text('Jami chiqindi'), findsOneWidget);
    expect(find.text("Og'irlik"), findsOneWidget);
    expect(find.text('Metraj'), findsOneWidget);

    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pauza'));
    await tester.pumpAndSettle();

    expect(find.text("Qaytarilgan bo'yoq"), findsNothing);
    expect(find.text('Jami chiqindi'), findsOneWidget);
    expect(find.text("Og'irlik"), findsOneWidget);
    expect(find.text('Metraj'), findsOneWidget);
  });

  testWidgets(
      'laminatsiya worker progress dialogs use laminatsiya metric fields',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await AppSession.instance.setSession(
      token: 'worker-laminatsiya-dialog-token',
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Laminatsiya operatori',
        legalName: '',
        ref: 'worker-laminatsiya-dialog',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: ['Laminatsiya 1'],
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-laminatsiya-dialog',
        title: 'Laminatsiya dialog order',
        productCode: 'LMD-A',
        apparatus: 'Laminatsiya 1',
        product: 'laminatsiya dialog mahsulot',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: 'Laminatsiya 1',
      orderIds: const ['zakaz-laminatsiya-dialog'],
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Laminatsiya 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('laminatsiya-dialog').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boshlash'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tugatish'));
    await tester.pumpAndSettle();

    expect(find.text('Bosmadan ortgan rulon'), findsOneWidget);
    expect(find.text('Plyonkadan ortgan rulon'), findsOneWidget);
    expect(find.text('Jami chiqindi'), findsOneWidget);
    expect(find.text("Og'irlik"), findsOneWidget);
    expect(find.text('Metraj'), findsOneWidget);

    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pauza'));
    await tester.pumpAndSettle();

    expect(find.text('Bosmadan ortgan rulon'), findsNothing);
    expect(find.text('Plyonkadan ortgan rulon'), findsOneWidget);
    expect(find.text('Jami chiqindi'), findsOneWidget);
    expect(find.text("Og'irlik"), findsOneWidget);
    expect(find.text('Metraj'), findsOneWidget);
  });

  testWidgets('rezka worker progress dialogs use rezka metric fields', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await AppSession.instance.setSession(
      token: 'worker-rezka-dialog-token',
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Rezka operatori',
        legalName: '',
        ref: 'worker-rezka-dialog',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: ['Rezka'],
      ),
    );
    await MobileApi.instance.adminCreateApparatus('Rezka');
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-rezka-dialog',
        title: 'Rezka dialog order',
        productCode: 'RZD-A',
        apparatus: 'Rezka',
        product: 'rezka dialog mahsulot',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: 'Rezka',
      orderIds: const ['zakaz-rezka-dialog'],
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rezka'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('rezka-dialog').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boshlash'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tugatish'));
    await tester.pumpAndSettle();

    expect(find.text('Bosmachining chiqindisi'), findsOneWidget);
    expect(find.text('Laminatsiya chiqindisi'), findsOneWidget);
    expect(
      find.text('Tayyor mahsulot chetidan chiqqan chiqindi'),
      findsOneWidget,
    );

    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pauza'));
    await tester.pumpAndSettle();

    expect(find.text('Bosmachining chiqindisi'), findsOneWidget);
    expect(find.text('Laminatsiya chiqindisi'), findsOneWidget);
    expect(
      find.text('Tayyor mahsulot chetidan chiqqan chiqindi'),
      findsOneWidget,
    );
  });

  testWidgets('rezka worker detail explains WIP split from map', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await AppSession.instance.setSession(
      token: 'worker-rezka-split-token',
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Rezka operatori',
        legalName: '',
        ref: 'worker-rezka-split',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: ['Rezka'],
      ),
    );
    await MobileApi.instance.adminCreateApparatus('Rezka');
    final map = _twoStageProductionOrderMap(
      id: 'zakaz-rezka-split',
      title: 'Rezka split order',
      productCode: 'RZS-A',
      product: 'rezka split mahsulot',
      firstApparatus: '7 ta rangli bosma aparat',
      secondApparatus: 'Rezka',
    );
    await MobileApi.instance.adminSaveProductionMap(
      map.copyWith(
        nodes: [
          for (final node in map.nodes)
            node.id == 'second-apparatus'
                ? node.copyWith(
                    rezkaKadrCount: 4,
                    rezkaFrameGroups: const [3, 1],
                  )
                : node,
        ],
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: 'Rezka',
      orderIds: const ['zakaz-rezka-split'],
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rezka'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('rezka-split').first);
    await tester.pumpAndSettle();

    expect(find.text('Map bo‘yicha rezka'), findsOneWidget);
    expect(find.textContaining('2 bo‘lak'), findsOneWidget);
    expect(find.textContaining('1-bo‘lak: 3 kadr'), findsOneWidget);
    expect(find.textContaining('2-bo‘lak: 1 kadr'), findsOneWidget);
  });

  testWidgets('worker in-progress history opens WIP details', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await AppSession.instance.setSession(
      token: 'worker-completed-context-token',
      profile: const SessionProfile(
        role: UserRole.werka,
        displayName: 'Aparatchi',
        legalName: '',
        ref: 'worker-completed-context',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: ['7 ta rangli bosma aparat'],
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _twoStageProductionOrderMap(
        id: 'zakaz-worker-completed-context',
        title: 'Worker completed context',
        productCode: 'WCC',
        product: 'worker context mahsulot',
        firstApparatus: '7 ta rangli bosma aparat',
        secondApparatus: 'Laminatsiya 1',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: '7 ta rangli bosma aparat',
      orderIds: const ['zakaz-worker-completed-context'],
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: 'Laminatsiya 1',
      orderIds: const ['zakaz-worker-completed-context'],
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: '7 ta rangli bosma aparat',
      orderId: 'zakaz-worker-completed-context',
      action: 'start',
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: '7 ta rangli bosma aparat',
      orderId: 'zakaz-worker-completed-context',
      action: 'complete',
      producedQty: 12,
      grossQty: 9,
      uom: 'm',
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: 'Laminatsiya 1',
      orderId: 'zakaz-worker-completed-context',
      action: 'start',
    );

    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tugallangan'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('completed context').first);
    await tester.pumpAndSettle();

    expect(find.text('WIP tafsilotlari'), findsOneWidget);
    expect(find.byKey(const ValueKey('worker-wip-count')), findsOneWidget);
    expect(find.textContaining('WIP yaratilgan'), findsOneWidget);
    expect(find.text('Ish boshlash uchun homashyolar'), findsNothing);
  });

  testWidgets('later stage detail keeps previous progress QR scan visible', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await AppSession.instance.setSession(
      token: 'worker-lamin-previous-qr-token',
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Laminatsiya aparatchi',
        legalName: '',
        ref: 'worker-lamin-previous-qr',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: ['Laminatsiya 1'],
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _twoStageProductionOrderMap(
        id: 'zakaz-worker-previous-qr',
        title: 'Worker previous QR',
        productCode: 'WPQ',
        product: 'worker previous qr product',
        firstApparatus: '7 ta rangli bosma aparat',
        secondApparatus: 'Laminatsiya 1',
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: '7 ta rangli bosma aparat',
      orderIds: const ['zakaz-worker-previous-qr'],
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: 'Laminatsiya 1',
      orderIds: const ['stale-zakaz'],
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: '7 ta rangli bosma aparat',
      orderId: 'zakaz-worker-previous-qr',
      action: 'start',
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: '7 ta rangli bosma aparat',
      orderId: 'zakaz-worker-previous-qr',
      action: 'complete',
      producedQty: 12,
      grossQty: 9,
      uom: 'm',
    );

    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Laminatsiya 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('previous-qr').first);
    await tester.pumpAndSettle();

    final previousQrLabel = find.text('Oldingi bosqich QR');
    expect(previousQrLabel, findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('production-quick-scanner-manual-toggle')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('production-quick-scanner-manual')),
      findsOneWidget,
    );
    expect(
      find.text('Oldingi bosqichdan kelgan mahsulotlar'),
      findsOneWidget,
    );
    expect(tester.getSize(previousQrLabel).width, greaterThan(120));
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey('production-quick-scanner-manual')),
          )
          .right,
      lessThan(360),
    );
  });

  testWidgets(
    'later stage waits for previous apparatus before showing progress QR scan',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      await AppSession.instance.setSession(
        token: 'worker-lamin-wait-token',
        profile: const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Laminatsiya aparatchi',
          legalName: '',
          ref: 'worker-lamin-wait',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: ['Laminatsiya 1'],
        ),
      );
      await MobileApi.instance.adminSaveProductionMap(
        _twoStageProductionOrderMap(
          id: 'zakaz-worker-lamin-wait',
          title: 'Worker lamin wait',
          productCode: 'WLW',
          product: 'worker lamin wait product',
          firstApparatus: '7 ta rangli bosma aparat',
          secondApparatus: 'Laminatsiya 1',
        ),
      );
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: 'Laminatsiya 1',
        orderIds: const ['zakaz-worker-lamin-wait'],
      );

      await _usePhoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Laminatsiya 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('lamin-wait').first);
      await tester.pumpAndSettle();

      expect(find.text('Oldingi bosqich QR'), findsNothing);
      expect(find.text('Scan'), findsNothing);
      expect(
        find.text(
            'Oldingi bosqich tugallanguncha kutilmoqda: 7 ta rangli bosma aparat'),
        findsOneWidget,
      );
      expect(find.text('2 / 5 bosqich'), findsOneWidget);
    },
  );

  testWidgets('production map sheet closes when tapping the dimmed barrier', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Katta partiyami?'));
    await tester.pumpAndSettle();

    expect(find.text('Node sozlash'), findsOneWidget);

    await tester.tapAt(const Offset(200, 90));
    await tester.pumpAndSettle();

    expect(find.text('Node sozlash'), findsNothing);
  });

  testWidgets('production map page shows default condition flow', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Katta partiyami?'), findsOneWidget);
    expect(find.text('Katta partiya'), findsNothing);
    expect(find.text('Rezkaga yuborish'), findsNothing);
    expect(
      find.byKey(const ValueKey('production-map-branch-add-true')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('production-map-branch-add-false')),
      findsWidgets,
    );
  });

  testWidgets('production map formula field shows human variable editor', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CPP hisob'));
    await tester.pumpAndSettle();

    expect(find.text('Node sozlash'), findsOneWidget);
    expect(find.text('Buyurtma miqdori * 1.08'), findsOneWidget);
    expect(find.text('order_qty * 1.08'), findsNothing);

    await tester.tap(find.text('Buyurtma miqdori * 1.08'));
    await tester.pumpAndSettle();

    expect(find.text('Formula yozish'), findsOneWidget);
    expect(find.text('Buyurtma miqdori'), findsWidgets);

    await tester.enterText(find.byType(TextField).last, 'buyu');
    await tester.pump();
    final formulaField = tester.widget<TextField>(find.byType(TextField).last);
    final formulaSpan = formulaField.controller!.buildTextSpan(
      context: tester.element(find.byType(TextField).last),
      style: const TextStyle(),
      withComposing: false,
    );
    expect(formulaSpan.toPlainText(), 'buyurtma miqdori');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Formula yozish'), findsOneWidget);
    expect(formulaField.focusNode?.hasFocus, isTrue);
    expect(formulaField.controller!.text, 'Buyurtma miqdori ');

    await tester.tap(find.text('Saqlash').last);
    await tester.pumpAndSettle();

    expect(find.text('Buyurtma miqdori'), findsWidgets);
  });

  testWidgets('production map edge delete button removes an outgoing edge', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapMapTool(tester, 'Ishlov');
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(
      const ValueKey('production-map-edge-delete-task_1-end-'),
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(deleteButton, findsNothing);
  });

  testWidgets('started apparatus node and its incoming edge stay disabled', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await _usePhoneViewport(tester);
    const map = ProductionMapDefinition(
      id: 'zakaz-locked-editor-node',
      productCode: 'LOCKED-EDITOR',
      title: 'Locked editor order',
      orderNumber: '4321',
      customerName: 'Locked customer',
      orderKg: 125,
      baseLength: 840,
      nodes: [
        ProductionMapNode(
          id: 'start',
          kind: 'start',
          title: 'Start',
          x: 420,
          y: 32,
        ),
        ProductionMapNode(
          id: 'locked-apparatus',
          kind: 'apparatus',
          title: 'Locked apparatus',
          x: 420,
          y: 164,
        ),
        ProductionMapNode(
          id: 'future-apparatus',
          kind: 'apparatus',
          title: 'Future apparatus',
          x: 420,
          y: 296,
        ),
        ProductionMapNode(
          id: 'end',
          kind: 'end',
          title: 'End',
          x: 420,
          y: 428,
        ),
      ],
      edges: [
        ProductionMapEdge(from: 'start', to: 'locked-apparatus'),
        ProductionMapEdge(
          from: 'locked-apparatus',
          to: 'future-apparatus',
        ),
        ProductionMapEdge(from: 'future-apparatus', to: 'end'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(
          savedMap: map,
          lockedNodeIds: {'locked-apparatus'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('production-map-node-connect-locked-apparatus'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('production-map-node-connect-future-apparatus'),
      ),
      findsOneWidget,
    );
    final incomingEdge = find.byKey(
      const ValueKey(
        'production-map-edge-delete-start-locked-apparatus-',
      ),
    );
    final outgoingEdge = find.byKey(
      const ValueKey(
        'production-map-edge-delete-locked-apparatus-future-apparatus-',
      ),
    );
    expect(
      tester
          .widget<InkWell>(
            find.descendant(of: incomingEdge, matching: find.byType(InkWell)),
          )
          .onTap,
      isNull,
    );
    expect(
      tester
          .widget<InkWell>(
            find.descendant(of: outgoingEdge, matching: find.byType(InkWell)),
          )
          .onTap,
      isNotNull,
    );

    await tester.drag(find.text('Locked apparatus'), const Offset(90, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('production-map-save')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    final saved = await MobileApi.instance.adminProductionMap(map.id);
    expect(
      saved.map.nodes.singleWhere((node) => node.id == 'locked-apparatus').x,
      420,
    );
    expect(saved.map.customerName, 'Locked customer');
    expect(saved.map.orderKg, 125);
    expect(saved.map.baseLength, 840);

    await tester.tap(find.text('Locked apparatus'));
    await tester.pumpAndSettle();
    expect(find.text('Aparat tanlang'), findsNothing);
    await tester.tap(find.text('Future apparatus'));
    await tester.pumpAndSettle();
    expect(find.text('Aparat tanlang'), findsOneWidget);
  });

  testWidgets('production map branch adds condition with open branch handles', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapMapTool(tester, 'Condition');
    await tester.pumpAndSettle();

    expect(find.text('Shart'), findsOneWidget);
    expect(find.text('Shunda yo‘liga qo‘shish'), findsNothing);
    expect(find.text('Bajariladigan ish'), findsNothing);
    expect(find.text('Boshqa holatdagi ish'), findsNothing);
    expect(
      find.byKey(const ValueKey('production-map-branch-add-true')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('production-map-branch-add-false')),
      findsWidgets,
    );
  });
}

Future<void> _completeQolipScan(WidgetTester tester) async {
  await MobileApi.instance.qolipSaveProductSpec(
    product: const QolipProduct(
      code: 'DEMO-CPP',
      name: 'CPP sous',
      itemGroup: 'Demo xomashyo',
    ),
    qolipCode: 'TEST-QOLIP-QR',
    size: 50,
  );
  await tester.tap(
    find.byKey(const ValueKey('production-quick-scanner-manual-toggle')),
  );
  await tester.pumpAndSettle();
  final input = find.byKey(
    const ValueKey('production-quick-scanner-manual'),
  );
  expect(input, findsOneWidget);
  await tester.enterText(input, 'TEST-QOLIP-QR');
  await tester.tap(find.byTooltip('Qabul qilish'));
  await tester.pumpAndSettle();
  expect(find.text('Qolip qo‘shildi (1/1 ta)'), findsOneWidget);
  final qolipsHeader = find.byKey(
    const ValueKey('production-qolips-expansion'),
  );
  expect(qolipsHeader, findsOneWidget);
  expect(
    find.descendant(of: qolipsHeader, matching: find.text('1/1 ta')),
    findsOneWidget,
  );
  await tester.tap(qolipsHeader);
  await tester.pumpAndSettle();
  expect(
    find.byKey(
      const ValueKey('production-scanned-qolip-test-qolip-qr'),
    ),
    findsOneWidget,
  );
  await tester.tap(find.text('Boshlash'));
  await tester.pumpAndSettle();
}

ProductionMapDefinition _alternativeProductionOrderMap({
  required String id,
  required String title,
  required String productCode,
  required String product,
  required List<String> apparatus,
  double? rollCount,
  double? widthMm,
}) {
  final apparatusNodes = [
    for (var index = 0; index < apparatus.length; index++)
      ProductionMapNode(
        id: 'apparatus-$index',
        kind: 'apparatus',
        title: apparatus[index],
        alternativeGroupId: 'alt-$id',
        alternativeGroupLabel: 'pechat',
      ),
  ];
  return ProductionMapDefinition(
    id: id,
    productCode: productCode,
    title: title,
    rollCount: rollCount,
    widthMm: widthMm,
    nodes: [
      const ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ...apparatusNodes,
      ProductionMapNode(
        id: 'end',
        kind: 'end',
        title: product,
        itemCode: productCode,
      ),
    ],
    edges: [
      for (final node in apparatusNodes) ...[
        ProductionMapEdge(from: 'start', to: node.id),
        ProductionMapEdge(from: node.id, to: 'end'),
      ],
    ],
  );
}

ProductionMapDefinition _chainedAlternativeProductionOrderMap({
  required String id,
  required String title,
  required String productCode,
  required String product,
  required List<String> firstGroupApparatus,
  required List<String> secondGroupApparatus,
  required String firstGroupAssignedTitle,
  double? rollCount,
  double? widthMm,
}) {
  final firstGroupNodes = [
    for (var index = 0; index < firstGroupApparatus.length; index++)
      ProductionMapNode(
        id: 'first-apparatus-$index',
        kind: 'apparatus',
        title: firstGroupApparatus[index],
        alternativeGroupId: 'alt-first-$id',
        alternativeGroupLabel: 'pechat',
        alternativeAssignedTitle: firstGroupAssignedTitle,
      ),
  ];
  final secondGroupNodes = [
    for (var index = 0; index < secondGroupApparatus.length; index++)
      ProductionMapNode(
        id: 'second-apparatus-$index',
        kind: 'apparatus',
        title: secondGroupApparatus[index],
        alternativeGroupId: 'alt-second-$id',
        alternativeGroupLabel: 'laminatsiya',
      ),
  ];
  return ProductionMapDefinition(
    id: id,
    productCode: productCode,
    title: title,
    rollCount: rollCount,
    widthMm: widthMm,
    nodes: [
      const ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ...firstGroupNodes,
      ...secondGroupNodes,
      ProductionMapNode(
        id: 'end',
        kind: 'end',
        title: product,
        itemCode: productCode,
      ),
    ],
    edges: [
      for (final first in firstGroupNodes)
        ProductionMapEdge(from: 'start', to: first.id),
      for (final first in firstGroupNodes)
        for (final second in secondGroupNodes)
          ProductionMapEdge(from: first.id, to: second.id),
      for (final second in secondGroupNodes)
        ProductionMapEdge(from: second.id, to: 'end'),
    ],
  );
}

ProductionMapDefinition _productionOrderMap({
  required String id,
  required String title,
  required String productCode,
  required String apparatus,
  required String product,
  String orderNumber = '',
  double? rollCount,
  double? widthMm,
  double? orderKg,
  double? baseLength,
  int apparatusCopies = 1,
}) {
  final apparatusNodes = [
    for (var index = 0; index < apparatusCopies; index++)
      ProductionMapNode(
        id: index == 0 ? 'apparatus' : 'apparatus-$index',
        kind: 'apparatus',
        title: apparatus,
      ),
  ];
  return ProductionMapDefinition(
    id: id,
    productCode: productCode,
    title: title,
    orderNumber: orderNumber,
    rollCount: rollCount,
    widthMm: widthMm,
    orderKg: orderKg,
    baseLength: baseLength,
    nodes: [
      const ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ...apparatusNodes,
      ProductionMapNode(
        id: 'end',
        kind: 'end',
        title: product,
        itemCode: productCode,
      ),
    ],
    edges: [
      ProductionMapEdge(from: 'start', to: apparatusNodes.first.id),
      for (var index = 0; index < apparatusNodes.length - 1; index++)
        ProductionMapEdge(
          from: apparatusNodes[index].id,
          to: apparatusNodes[index + 1].id,
        ),
      ProductionMapEdge(from: apparatusNodes.last.id, to: 'end'),
    ],
  );
}

ProductionMapDefinition _twoStageProductionOrderMap({
  required String id,
  required String title,
  required String productCode,
  required String product,
  required String firstApparatus,
  required String secondApparatus,
}) {
  return ProductionMapDefinition(
    id: id,
    productCode: productCode,
    title: title,
    nodes: [
      const ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ProductionMapNode(
        id: 'product-task',
        kind: 'task',
        title: product,
      ),
      ProductionMapNode(
        id: 'first-apparatus',
        kind: 'apparatus',
        title: firstApparatus,
      ),
      ProductionMapNode(
        id: 'second-apparatus',
        kind: 'apparatus',
        title: secondApparatus,
      ),
      ProductionMapNode(
        id: 'end',
        kind: 'end',
        title: product,
        itemCode: productCode,
      ),
    ],
    edges: const [
      ProductionMapEdge(from: 'start', to: 'product-task'),
      ProductionMapEdge(from: 'product-task', to: 'first-apparatus'),
      ProductionMapEdge(from: 'first-apparatus', to: 'second-apparatus'),
      ProductionMapEdge(from: 'second-apparatus', to: 'end'),
    ],
  );
}

Future<void> _usePhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapMapTool(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel('Element qo‘shish'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('admin-fab-menu-$label')));
}

Future<void> _dragOrderTitleToTopZone(
  WidgetTester tester, {
  required String orderTitle,
  required String targetText,
}) async {
  final order = find.textContaining(orderTitle);
  await tester.ensureVisible(order);
  await tester.pumpAndSettle();
  final gesture = await tester.startGesture(tester.getCenter(order));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 120));
  final target = tester.getCenter(find.textContaining(targetText).first);
  await gesture.moveTo(target);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _tapMoveOrderBadge(
  WidgetTester tester, {
  required ValueKey<String> key,
}) async {
  final order = find.byKey(key);
  await tester.ensureVisible(order);
  await tester.pumpAndSettle();
  final topLeft = tester.getTopLeft(order);
  final height = tester.getSize(order).height;
  await tester.tapAt(topLeft + Offset(28, height / 2));
  await tester.pumpAndSettle();
}

Future<void> _dragOrderHandleForKeyToTopZone(
  WidgetTester tester, {
  required ValueKey<String> key,
  required String targetText,
}) async {
  await _dragOrderHandleForKeyToZone(
    tester,
    key: key,
    targetText: targetText,
  );
}

Future<void> _dragOrderHandleToBottomZone(
  WidgetTester tester, {
  required String orderTitle,
  required String targetText,
}) async {
  await _dragOrderHandleToZone(
    tester,
    orderTitle: orderTitle,
    targetText: targetText,
  );
}

Future<void> _dragOrderHandleToZone(
  WidgetTester tester, {
  required String orderTitle,
  required String targetText,
}) async {
  final order = find.textContaining(orderTitle);
  await tester.ensureVisible(order);
  await tester.pumpAndSettle();
  final orderCenter = tester.getCenter(order);
  final handles = tester
      .widgetList<Icon>(find.byIcon(Icons.drag_handle_rounded))
      .toList(growable: false);
  final handleFinders = [
    for (var index = 0; index < handles.length; index++)
      find.byIcon(Icons.drag_handle_rounded).at(index),
  ];
  Finder? matchingHandle;
  var minDistance = double.infinity;
  for (final handle in handleFinders) {
    final center = tester.getCenter(handle);
    final distance = (center.dy - orderCenter.dy).abs();
    if (distance < minDistance) {
      minDistance = distance;
      matchingHandle = handle;
    }
  }
  final start = tester.getCenter(matchingHandle!);
  final gesture = await tester.startGesture(start);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 260));
  final target = tester.getCenter(find.textContaining(targetText).first);
  await gesture.moveBy(const Offset(0, -24));
  await tester.pump();
  await gesture.moveTo(target);
  await tester.pump(const Duration(milliseconds: 240));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _dragOrderHandleForKeyToZone(
  WidgetTester tester, {
  required ValueKey<String> key,
  required String targetText,
}) async {
  final order = find.byKey(key);
  await tester.ensureVisible(order);
  await tester.pumpAndSettle();
  final handle = find.descendant(
    of: order,
    matching: find.byIcon(Icons.drag_handle_rounded),
  );
  final start = tester.getCenter(handle);
  final gesture = await tester.startGesture(start);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 260));
  final target = tester.getCenter(find.textContaining(targetText).first);
  await gesture.moveBy(const Offset(0, -24));
  await tester.pump();
  await gesture.moveTo(target);
  await tester.pump(const Duration(milliseconds: 240));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _dragOrderHandleForKeyToTopDropZone(
  WidgetTester tester, {
  required ValueKey<String> key,
}) async {
  final order = find.byKey(key);
  await tester.ensureVisible(order);
  await tester.pumpAndSettle();
  final topHeader = find.byKey(const ValueKey('move-top-apparatus-picker'));
  final boundary = find.byKey(const ValueKey('move-boundary-apparatus-picker'));
  final headerCenter = tester.getCenter(topHeader);
  final headerBottom = tester.getBottomLeft(topHeader).dy;
  final boundaryTop = tester.getTopLeft(boundary).dy;
  final target = Offset(headerCenter.dx, (headerBottom + boundaryTop) / 2);
  final handle = find.descendant(
    of: order,
    matching: find.byIcon(Icons.drag_handle_rounded),
  );
  final start = tester.getCenter(handle);
  final gesture = await tester.startGesture(start);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 260));
  await gesture.moveBy(const Offset(0, -24));
  await tester.pump();
  await gesture.moveTo(target);
  await tester.pump(const Duration(milliseconds: 240));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _dragOrderHandleForKeyToBottomZone(
  WidgetTester tester, {
  required ValueKey<String> key,
}) async {
  final order = find.byKey(key);
  await tester.ensureVisible(order);
  await tester.pumpAndSettle();
  final boundary = find.byKey(
    const ValueKey('move-boundary-apparatus-picker'),
  );
  final boundaryRect = tester.getRect(boundary);
  final viewport = tester.getSize(find.byType(MaterialApp));
  final target = Offset(
    boundaryRect.center.dx,
    boundaryRect.bottom + (viewport.height - boundaryRect.bottom) * 0.42,
  );
  final handle = find.descendant(
    of: order,
    matching: find.byIcon(Icons.drag_handle_rounded),
  );
  final start = tester.getCenter(handle);
  final gesture = await tester.startGesture(start);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 260));
  await gesture.moveBy(const Offset(0, -24));
  await tester.pump();
  await gesture.moveTo(target);
  await tester.pump(const Duration(milliseconds: 240));
  await gesture.up();
  await tester.pumpAndSettle();
}

String _apparatusTitle(List<ProductionMapSaved> maps, String id) {
  final map = maps.singleWhere((item) => item.map.id == id).map;
  return map.nodes.firstWhere((node) => node.kind == 'apparatus').title.trim();
}

List<String> _apparatusTitles(List<ProductionMapSaved> maps, String id) {
  final map = maps.singleWhere((item) => item.map.id == id).map;
  return map.nodes
      .where((node) => node.kind == 'apparatus')
      .map((node) => node.title.trim())
      .toList(growable: false);
}

List<String> _alternativeGroupIds(List<ProductionMapSaved> maps, String id) {
  final map = maps.singleWhere((item) => item.map.id == id).map;
  return map.nodes
      .where((node) => node.kind == 'apparatus')
      .map((node) => node.alternativeGroupId.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

List<String> _alternativeAssignedTitles(
  List<ProductionMapSaved> maps,
  String id,
) {
  final map = maps.singleWhere((item) => item.map.id == id).map;
  return map.nodes
      .where((node) => node.kind == 'apparatus')
      .map((node) => node.alternativeAssignedTitle.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

Future<String?> _testProgressDriverUrlPicker(BuildContext _) async {
  return 'test://progress-printer';
}
