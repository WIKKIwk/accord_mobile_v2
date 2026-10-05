part of 'admin_item_create_screen_test.dart';

void _setItemMoveCapabilities(List<String> capabilities) {
  AppSession.instance.profile = SessionProfile(
    role: UserRole.admin,
    displayName: 'Admin',
    legalName: 'Admin',
    ref: 'ADMIN-001',
    phone: '',
    avatarUrl: '',
    capabilities: capabilities,
  );
}

Future<void> _pumpItemSelectionScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
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
    onGenerateRoute: (settings) {
      if (settings.name != AppRoutes.adminItemDetail) return null;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Details ${settings.arguments}')),
          body: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Return to items'),
          ),
        ),
      );
    },
  ));
  await _pumpAdminItemCreateScreen(tester, waitForItems: true);
}

Future<void> _chooseItemMoveGroup(WidgetTester tester, String group) async {
  await tester.tap(find.byKey(const ValueKey('admin-items-group-filter')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('admin-items-group-option-$group')));
  await _pumpAdminItemCreateScreen(tester);
}

void _registerAdminItemSelectionTests() {
  testWidgets('item selection mode toggles rows after the first selection',
      (tester) async {
    _setItemMoveCapabilities(['admin.access', 'catalog.item.bulk_move']);
    final client = _ItemSelectionHttpClient();
    await HttpOverrides.runZoned(() async {
      await _pumpItemSelectionScreen(tester);
      final normalFab =
          find.byKey(const ValueKey('app-primary-navigation-button'));
      final moveFab = find.byKey(const ValueKey('admin-items-move-fab'));
      expect(find.byType(TabBar), findsNothing);
      expect(moveFab, findsNothing);
      final normalRect = tester.getRect(normalFab);

      await tester.tap(find.text('Item 001'));
      await tester.pumpAndSettle();
      expect(find.text('Details ITEM-001'), findsOneWidget);
      await tester.tap(find.text('Return to items'));
      await _pumpAdminItemCreateScreen(tester);
      expect(moveFab, findsNothing);

      await tester
          .tap(find.byKey(const ValueKey('admin-item-select-ITEM-001')));
      await tester.pumpAndSettle();
      expect(find.text('Tanlangan: 1 ta'), findsOneWidget);
      expect(normalFab, findsNothing);
      expect(moveFab, findsOneWidget);
      final moveRect = tester.getRect(moveFab);
      expect(moveRect.right, normalRect.right);
      expect(moveRect.bottom, normalRect.bottom);
      expect(moveRect.height, normalRect.height);
      expect(moveRect.width, greaterThan(normalRect.width));

      await tester.longPress(find.text('Item 002'));
      await tester.pumpAndSettle();
      expect(find.text('Tanlangan: 2 ta'), findsOneWidget);
      // In selection mode, ordinary row taps toggle instead of opening details.
      await tester.tap(find.text('Item 002'));
      await tester.pumpAndSettle();
      expect(find.text('Details ITEM-002'), findsNothing);
      expect(find.text('Tanlangan: 1 ta'), findsOneWidget);
      await tester.tap(find.text('Item 002'));
      await tester.pumpAndSettle();
      expect(find.text('Tanlangan: 2 ta'), findsOneWidget);
      expect(
          tester
              .widget<AdminSummaryCard>(
                  find.widgetWithText(AdminSummaryCard, 'Item 002'))
              .showChevron,
          isFalse);
      await tester.tap(find.text('Item 001'));
      await tester.tap(find.text('Item 002'));
      await tester.pumpAndSettle();
      expect(moveFab, findsNothing);
      expect(normalFab, findsOneWidget);
      await tester.tap(find.text('Item 002'));
      await tester.pumpAndSettle();
      expect(find.text('Details ITEM-002'), findsOneWidget);
      await tester.tap(find.text('Return to items'));
      await _pumpAdminItemCreateScreen(tester);
      // Long press starts selection mode again, then a tap adds another item.
      await tester.longPress(find.text('Item 001'));
      await tester.tap(find.text('Item 002'));
      await tester.pumpAndSettle();
      expect(find.text('Tanlangan: 2 ta'), findsOneWidget);

      // All groups is a filter, never a move destination.
      await tester.tap(moveFab);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(client.moves, isEmpty);
      expect(find.text('Guruhni tanlang'), findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey('admin-items-group-option-Group B')));
      await _pumpAdminItemCreateScreen(tester);
      expect(find.text('Tanlangan: 2 ta'), findsOneWidget);
      expect(find.text('Item 001'), findsNothing);
      await tester.enterText(_appBarSearchEditable(), 'Item 004');
      await _pumpAdminItemCreateScreen(tester);
      expect(find.text('Tanlangan: 2 ta'), findsOneWidget);
      expect(find.widgetWithText(AdminSummaryCard, 'Item 004'), findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey('admin-items-clear-selection')));
      await tester.pumpAndSettle();
      expect(moveFab, findsNothing);
      expect(normalFab, findsOneWidget);
      expect(client.moves, isEmpty);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets(
      'item selection moves hidden items and restores plus after success',
      (tester) async {
    _setItemMoveCapabilities(['admin.access', 'catalog.item.bulk_move']);
    final client = _ItemSelectionHttpClient();
    final response = Completer<HttpClientResponse>();
    client.pendingMove = response;
    await HttpOverrides.runZoned(() async {
      await _pumpItemSelectionScreen(tester);
      await _chooseItemMoveGroup(tester, 'Group A');
      await tester
          .tap(find.byKey(const ValueKey('admin-item-select-ITEM-001')));
      await tester.longPress(find.text('Item 003'));
      await tester.pumpAndSettle();
      await _chooseItemMoveGroup(tester, 'Group B');
      expect(find.text('Item 001'), findsNothing);
      expect(find.text('Tanlangan: 2 ta'), findsOneWidget);
      final moveFab = find.byKey(const ValueKey('admin-items-move-fab'));
      await tester.tap(moveFab);
      await tester.pumpAndSettle();
      expect(find.text('2 ta mahsulotni “Group B” guruhiga o‘tkazilsinmi?'),
          findsOneWidget);
      final cancelRect = tester.getRect(
        find.byKey(const ValueKey('admin-items-move-cancel')),
      );
      final confirmRect = tester.getRect(
        find.byKey(const ValueKey('admin-items-move-confirm')),
      );
      final dialogRect = tester.getRect(find.byType(AlertDialog));
      expect(cancelRect.top, greaterThan(confirmRect.bottom));
      expect(cancelRect.center.dx, closeTo(dialogRect.center.dx, 0.01));
      await tester.tap(find.byKey(const ValueKey('admin-items-move-cancel')));
      await tester.pumpAndSettle();
      expect(client.moves, isEmpty);
      expect(moveFab, findsOneWidget);

      await tester.tap(moveFab);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-items-move-confirm')));
      await _pumpAdminItemCreateScreen(tester);
      expect(client.moves, hasLength(1));
      expect(client.moves.single['item_codes'], ['ITEM-001', 'ITEM-003']);
      expect(client.moves.single['item_group'], 'Group B');
      expect(tester.widget<FloatingActionButton>(moveFab).onPressed, isNull);
      // Selection and destination cannot change during submission.
      await tester
          .tap(find.byKey(const ValueKey('admin-item-select-ITEM-002')));
      await tester.tap(find.byKey(const ValueKey('admin-items-group-filter')));
      await tester.pump();
      expect(find.text('Tanlangan: 2 ta'), findsOneWidget);
      expect(
          tester
              .widget<AdminExpandableFilterChip<String>>(
                  find.byType(AdminExpandableFilterChip<String>))
              .expanded,
          isFalse);
      response.complete(client.successResponse());
      await _pumpAdminItemCreateScreen(tester);
      await tester.pumpAndSettle();
      expect(moveFab, findsNothing);
      expect(find.byKey(const ValueKey('app-primary-navigation-button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('admin-items-clear-selection')),
          findsNothing);
      expect(find.text('Item 001'), findsOneWidget);
      expect(find.text('Item 003'), findsOneWidget);
      expect(find.text('2 ta mahsulot ko‘chirildi'), findsOneWidget);
      expect(
          client.seenRequests.where(
              (r) => r == 'GET /v1/mobile/admin/items?group=Group+B&limit=80'),
          hasLength(2));
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets(
      'item selection keeps only failed items after partial move and errors',
      (tester) async {
    _setItemMoveCapabilities(['admin.access', 'catalog.item.bulk_move']);
    final client = _ItemSelectionHttpClient()..failedCodes = ['ITEM-003'];
    await HttpOverrides.runZoned(() async {
      await _pumpItemSelectionScreen(tester);
      await tester
          .tap(find.byKey(const ValueKey('admin-item-select-ITEM-001')));
      await tester.longPress(find.text('Item 003'));
      await _chooseItemMoveGroup(tester, 'Group B');
      final moveFab = find.byKey(const ValueKey('admin-items-move-fab'));
      await tester.tap(moveFab);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-items-move-confirm')));
      await _pumpAdminItemCreateScreen(tester);
      expect(find.text('Tanlangan: 1 ta'), findsOneWidget);
      expect(find.text('Ko‘chirish (1)'), findsOneWidget);
      expect(find.text('1 ta ko‘chirildi, 1 ta xato'), findsOneWidget);
      expect(find.text('Item 001'), findsOneWidget);
      expect(find.text('Item 003'), findsNothing);
      client.rejectMove = true;
      await tester.tap(moveFab);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-items-move-confirm')));
      await _pumpAdminItemCreateScreen(tester);
      expect(client.moves.last['item_codes'], ['ITEM-003']);
      expect(find.text('Tanlangan: 1 ta'), findsOneWidget);
      expect(moveFab, findsOneWidget);
      expect(tester.widget<FloatingActionButton>(moveFab).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets(
      'item selection requires move permission and supports move-only access',
      (tester) async {
    final client = _ItemSelectionHttpClient();
    await HttpOverrides.runZoned(() async {
      _setItemMoveCapabilities(['admin.access']);
      await _pumpItemSelectionScreen(tester);
      await tester
          .tap(find.byKey(const ValueKey('admin-item-select-ITEM-001')));
      await tester.pumpAndSettle();
      expect(find.text('Details ITEM-001'), findsOneWidget);
      await tester.tap(find.text('Return to items'));
      await _pumpAdminItemCreateScreen(tester);
      await tester.longPress(find.text('Item 002'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-items-move-fab')), findsNothing);
      expect(client.moves, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      _setItemMoveCapabilities(['catalog.item.read', 'catalog.item.bulk_move']);
      await _pumpItemSelectionScreen(tester);
      await tester
          .tap(find.byKey(const ValueKey('admin-item-select-ITEM-001')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('admin-items-move-fab')), findsOneWidget);
      expect(find.text('Tanlangan: 1 ta'), findsOneWidget);
      await tester.tap(find.text('Item 002'));
      await tester.pumpAndSettle();
      expect(find.text('Tanlangan: 2 ta'), findsOneWidget);
      expect(find.text('Details ITEM-002'), findsNothing);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });
}

class _ItemSelectionHttpClient extends _AdminItemCreateHttpClient {
  _ItemSelectionHttpClient() : super([]);
  final items = _itemsPage(1, 4)
      .map((item) => {
            ...item,
            'item_group':
                item['code'] == 'ITEM-001' || item['code'] == 'ITEM-003'
                    ? 'Group A'
                    : 'Group B',
          })
      .toList();
  final moves = <Map<String, dynamic>>[];
  List<String> failedCodes = [];
  bool rejectMove = false;
  Completer<HttpClientResponse>? pendingMove;

  HttpClientResponse successResponse() {
    final codes = (moves.last['item_codes'] as List).cast<String>();
    final updated = codes.where((code) => !failedCodes.contains(code)).toList();
    for (final item in items) {
      if (updated.contains(item['code'])) {
        item['item_group'] = moves.last['item_group'] as String;
      }
    }
    return _FakeHttpClientResponse(
        statusCode: HttpStatus.ok,
        body: jsonEncode({
          'item_group': moves.last['item_group'],
          'requested_count': codes.length,
          'updated_count': updated.length,
          'failed_count': codes.length - updated.length,
          'updated_item_codes': updated,
          'failed_item_codes': codes.where(failedCodes.contains).toList(),
        }));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (url.path == '/v1/mobile/admin/item-groups/tree') {
      return _FakeHttpClientRequest(
          response: _FakeHttpClientResponse(
        statusCode: HttpStatus.ok,
        body: jsonEncode([
          for (final group in ['Group A', 'Group B'])
            {
              'name': group,
              'item_group_name': group,
              'parent_item_group': '',
              'is_group': false
            },
        ]),
      ));
    }
    if (url.path == '/v1/mobile/admin/items' && method == 'GET') {
      seenRequests.add(
          '$method ${url.path}${url.query.isEmpty ? '' : '?${url.query}'}');
      final group = url.queryParameters['group'] ?? '';
      final query = url.queryParameters['q'] ?? '';
      return _FakeHttpClientRequest(
          response: _FakeHttpClientResponse(
        statusCode: HttpStatus.ok,
        body: jsonEncode(items
            .where((item) =>
                (group.isEmpty || item['item_group'] == group) &&
                (query.isEmpty || item['name']!.contains(query)))
            .toList()),
      ));
    }
    if (url.path == '/v1/mobile/admin/items/bulk-move-group' &&
        method == 'POST') {
      seenRequests.add('$method ${url.path}');
      return _ItemMoveBodyRequest((body) async {
        moves.add(body);
        if (rejectMove) {
          return _FakeHttpClientResponse(
              statusCode: HttpStatus.badRequest,
              body: jsonEncode({'error': 'Move rejected'}));
        }
        return pendingMove?.future ?? Future.value(successResponse());
      });
    }
    return super.openUrl(method, url);
  }
}

class _ItemMoveBodyRequest extends _FakeHttpClientRequest {
  _ItemMoveBodyRequest(this.respond)
      : super(
            response:
                _FakeHttpClientResponse(body: '{}', statusCode: HttpStatus.ok));
  final Future<HttpClientResponse> Function(Map<String, dynamic>) respond;
  final bytes = <int>[];
  @override
  void add(List<int> data) => bytes.addAll(data);
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      bytes.addAll(data);
    }
  }

  @override
  Future<HttpClientResponse> close() =>
      respond(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
}
