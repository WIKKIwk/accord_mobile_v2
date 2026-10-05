part of 'admin_item_create_screen_test.dart';

void _registerAdminItemGroupFilterTests() {
  testWidgets('group filter uses catalog names for pages, search and reset', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final seenRequests = <String>[];
    final client = _AdminItemCreateHttpClient(seenRequests);

    await HttpOverrides.runZoned(() async {
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
          home: const AdminItemCreateScreen(),
        ),
      );
      await _pumpAdminItemCreateScreen(tester, waitForItems: true);

      final filter = find.byKey(const ValueKey('admin-items-group-filter'));
      expect(find.byType(AdminExpandableFilterChip<String>), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(find.text('Metal'), findsWidgets);
      expect(find.text('Plastic'), findsWidgets);
      await tester.tap(find.text('Homashyo').last);
      await _pumpAdminItemCreateScreen(tester);

      expect(
        seenRequests,
        contains('GET /v1/mobile/admin/items?group=Homashyo&limit=80'),
      );
      expect(find.text('Item 001'), findsOneWidget);
      expect(find.text('Item 002'), findsNothing);
      expect(find.text('Metal'), findsNothing);

      final list = find.descendant(
        of: find.byType(AdminItemsListTab),
        matching: find.byType(ListView),
      );
      await tester.drag(list, const Offset(0, -12000));
      await _pumpAdminItemCreateScreen(tester);
      expect(
        seenRequests,
        contains(
          'GET /v1/mobile/admin/items?group=Homashyo&limit=80&offset=80',
        ),
      );

      await tester.enterText(_appBarSearchEditable(), 'Item 161');
      await _pumpAdminItemCreateScreen(tester);
      expect(
        seenRequests,
        contains(
          'GET /v1/mobile/admin/items?q=Item+161&group=Homashyo&limit=80',
        ),
      );
      expect(find.widgetWithText(AdminSummaryCard, 'Item 161'), findsOneWidget);
      expect(find.text('Item 001'), findsNothing);

      await tester.ensureVisible(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barcha guruhlar').last);
      await _pumpAdminItemCreateScreen(tester);
      expect(
        seenRequests,
        contains('GET /v1/mobile/admin/items?q=Item+161&limit=80'),
      );
      expect(find.widgetWithText(AdminSummaryCard, 'Item 161'), findsOneWidget);
      expect(
          seenRequests.every((request) => request.startsWith('GET ')), isTrue);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets('changing groups ignores stale pages and restores filtered cache',
      (
    tester,
  ) async {
    final requests = <({String group, Completer<List<SupplierItem>> result})>[];
    final groups = Future<List<String>>.value(['Group A', 'Group B']);

    Future<void> pumpList() async {
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
          home: Scaffold(
            body: AdminItemsListTab(
              itemGroupsFuture: groups,
              loadItemsPage: ({
                required query,
                required group,
                required limit,
                required offset,
              }) {
                final result = Completer<List<SupplierItem>>();
                requests.add((group: group, result: result));
                return result.future;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> selectGroup(String name) async {
      await tester.tap(find.byKey(const ValueKey('admin-items-group-filter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(ValueKey('admin-items-group-option-$name')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await pumpList();
    await selectGroup('Group A');
    await selectGroup('Group B');
    await selectGroup('Group A');
    expect(requests.map((request) => request.group),
        ['', 'Group A', 'Group B', 'Group A']);

    requests.last.result.complete([
      SupplierItem.fromJson({
        ..._itemsPage(1, 1).single,
        'name': 'Fresh group A item',
        'item_group': 'Group A',
      }),
    ]);
    await tester.pumpAndSettle();
    for (final request in requests.take(3)) {
      request.result.complete([
        SupplierItem.fromJson({
          ..._itemsPage(1, 1).single,
          'name': 'Stale item',
        }),
      ]);
    }
    await tester.pumpAndSettle();
    expect(find.text('Fresh group A item'), findsOneWidget);
    expect(find.text('Stale item'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpList();
    await tester.pumpAndSettle();
    expect(requests, hasLength(4));
    expect(find.text('Fresh group A item'), findsOneWidget);
    final filter = tester.widget<AdminExpandableFilterChip<String>>(
      find.byType(AdminExpandableFilterChip<String>),
    );
    expect(filter.selectedValue, 'Group A');
    expect(filter.expanded, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('group catalog failure leaves the item list usable',
      (tester) async {
    final groups = Completer<List<String>>();
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
        home: Scaffold(
          body: AdminItemsListTab(
            itemGroupsFuture: groups.future,
            loadItemsPage: ({
              required query,
              required group,
              required limit,
              required offset,
            }) async =>
                [SupplierItem.fromJson(_itemsPage(1, 1).single)],
          ),
        ),
      ),
    );
    await tester.pump();
    groups.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Item 001'), findsOneWidget);
    expect(find.text('Mahsulot guruhlari yuklanmadi'), findsOneWidget);
    expect(find.byType(AdminExpandableFilterChip<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
