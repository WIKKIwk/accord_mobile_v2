part of 'admin_production_map_test_screen_test.dart';

void _registerOrderImageZoomTests() {
  for (final (role, apparatusId) in [
    (UserRole.admin, _print7Id),
    (UserRole.aparatchi, _print7Id),
    (UserRole.aparatchi, _lamination1Id),
    (UserRole.aparatchi, _rezkaId),
    (UserRole.aparatchi, _flexoId),
  ]) {
    testWidgets('order image legacy parity: ${role.name} $apparatusId',
        (tester) async {
      final thumb = await tester.runAsync(() => orderImageTestPng(256, 128));
      final full = await tester.runAsync(() => orderImageTestPng(1200, 600));
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      await TestModeController.instance.setEnabled(true);
      await CalculateOrderTemplateStore.instance.debugReset();
      await CalculateOrderTemplateStore.instance.load();
      addTearDown(CalculateOrderTemplateStore.instance.debugReset);
      // A loaded but empty/admin-only template list must never suppress a
      // worker's order image. Legacy maps have no explicit imageId.
      expect(CalculateOrderTemplateStore.instance.isLoaded, isTrue);
      AppSession.instance.profile = SessionProfile(
          role: role,
          displayName: 'Viewer',
          legalName: '',
          ref: 'legacy-viewer',
          phone: '',
          avatarUrl: '',
          capabilities: const [
            'apparatus.queue.read',
            'apparatus.queue.manage'
          ],
          assignedApparatus: [
            apparatusId
          ]);
      const orderId = 'zakaz-image-legacy';
      final saved = await MobileApi.instance.adminSaveProductionMap(
          _productionOrderMap(
              id: orderId,
              title: 'Legacy image',
              productCode: 'LEGACY',
              apparatusId: apparatusId,
              product: 'Legacy'));
      expect(saved.map.imageId, isEmpty);
      final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
      final snapshot = AdminApparatusQueueSnapshot(maps: [
        saved
      ], sequences: {
        apparatusId: [orderId]
      }, visibleOrderIds: {
        apparatusId: [orderId]
      }, queueStates: {
        apparatusId: {orderId: 'pending'}
      }, queuePolicies: const {}, queueActionControls: {
        apparatusId: {orderId: _freshStartQueueControl()}
      }, orderControls: const {}, revision: 1, epoch: 'legacy-image');
      await _usePhoneViewport(tester);
      await TestModeController.instance.setEnabled(false);
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminProductionMapOrdersScreen(
              readOnly: role != UserRole.admin,
              workerMode: role != UserRole.admin,
              queueSnapshotLoader: () async => snapshot,
              apparatusLoader: () async => apparatus,
              liveEventsLoader: () => const Stream.empty()),
        ));
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
        final cover = find.byType(AdminOrderCoverThumb).first;
        expect(cover, findsOneWidget);
        await _pumpOrderImagePixels(tester, cover, 256);
        expect(
            tester
                .widgetList<RawImage>(
                    find.descendant(of: cover, matching: find.byType(RawImage)))
                .any((image) => image.image?.width == 256),
            isTrue);
        await tester.longPress(cover);
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
        expect(
            tester
                .widgetList<RawImage>(find.descendant(
                    of: find.byType(InteractiveViewer),
                    matching: find.byType(RawImage)))
                .any((image) => image.image?.width == 1200),
            isTrue);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        if (role != UserRole.admin) {
          await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
          await tester.pumpAndSettle();
          final photo = find
              .byKey(const ValueKey('production-order-detail-photo-thumbnail'));
          await _pumpOrderImagePixels(tester, photo, 256);
          expect(
              tester
                  .widgetList<RawImage>(find.descendant(
                      of: photo, matching: find.byType(RawImage)))
                  .any((image) => image.image?.width == 256),
              isTrue);
          await tester.tap(photo);
          await tester.pumpAndSettle();
          expect(
              tester
                  .widgetList<RawImage>(find.descendant(
                      of: find.byType(InteractiveViewer),
                      matching: find.byType(RawImage)))
                  .any((image) => image.image?.width == 1200),
              isTrue);
        }
        final imageRequests = requests
            .where((request) => request.url.path.endsWith('/order-image/view'))
            .toList();
        expect(imageRequests, hasLength(2),
            reason: 'one thumbnail + one full; sheet reuses both');
        expect(
            imageRequests.every((request) =>
                request.url.queryParameters['order_id'] == orderId),
            isTrue);
        expect(
            requests.any((request) =>
                request.url.path.endsWith('/calculate/orders/image/view')),
            isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                requests.add(request);
                if (request.url.path.endsWith('/order-image/view')) {
                  return http.Response.bytes(
                      request.url.queryParameters['variant'] == 'thumb-v1'
                          ? thumb!
                          : full!,
                      200,
                      headers: {'content-type': 'image/png'});
                }
                return http.Response('{"error":"forbidden"}', 403);
              }));
    });
  }

  testWidgets(
      'order image bottom sheet zoom requests full resolution instead of stretching thumbnail',
      (tester) async {
    final full = await tester.runAsync(() => orderImageTestPng(1200, 600));
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Image worker',
        legalName: '',
        ref: 'zoom-worker',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_print7Id]);
    const orderId = 'zakaz-image-bottom-sheet';
    final saved = await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
                id: orderId,
                title: 'Zoom image',
                productCode: 'ZOOM',
                apparatusId: _print7Id,
                product: 'Zoom product')
            .copyWith(imageId: 'full-quality-image'));
    final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
    final snapshot = AdminApparatusQueueSnapshot(maps: [
      saved
    ], sequences: const {
      _print7Id: [orderId]
    }, visibleOrderIds: const {
      _print7Id: [orderId]
    }, queueStates: const {
      _print7Id: {orderId: 'pending'}
    }, queuePolicies: const {}, queueActionControls: {
      _print7Id: {orderId: _freshStartQueueControl()}
    }, orderControls: const {}, revision: 1, epoch: 'image-test');
    await _usePhoneViewport(tester);
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
            queueSnapshotLoader: () async => snapshot,
            apparatusLoader: () async => apparatus,
            liveEventsLoader: () => const Stream.empty()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
      await tester.pumpAndSettle();
      final thumbnail =
          find.byKey(const ValueKey('production-order-detail-photo-thumbnail'));
      expect(thumbnail, findsOneWidget);
      await TestModeController.instance.setEnabled(false);
      await tester.tap(thumbnail);
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      final imageRequests = requests
          .where((request) => request.url.path.endsWith('/order-image/view'))
          .toList();
      expect(imageRequests, hasLength(1));
      expect(imageRequests.single.url.queryParameters,
          {'order_id': orderId, 'image_id': 'full-quality-image'});
      expect(
          tester
              .widgetList<RawImage>(find.descendant(
                  of: find.byType(InteractiveViewer),
                  matching: find.byType(RawImage)))
              .any((image) => image.image?.width == 1200),
          isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              requests.add(request);
              return request.url.path.endsWith('/order-image/view')
                  ? http.Response.bytes(full!, 200,
                      headers: {'content-type': 'image/png'})
                  : http.Response('{"error":"forbidden"}', 403);
            }));
  });
}

Future<void> _pumpOrderImagePixels(
    WidgetTester tester, Finder area, int width) async {
  // Native image decoding runs outside the widget test's fake clock.
  for (var attempt = 0; attempt < 25; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (tester
        .widgetList<RawImage>(
            find.descendant(of: area, matching: find.byType(RawImage)))
        .any((image) => image.image?.width == width)) {
      return;
    }
  }
}
