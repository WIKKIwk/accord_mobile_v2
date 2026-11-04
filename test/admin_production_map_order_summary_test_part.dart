part of 'admin_production_map_test_screen_test.dart';

CalculateOrderTemplate _summaryCalculation({bool multipleProducts = false}) =>
    CalculateOrderTemplate.fromJson({
      'id': 'summary-calculation',
      'source_map_id': 'zakaz-summary',
      'order_number': '0309',
      'code': '0309',
      'item_code': 'SUMMARY-1',
      'product': 'Summary product',
      'frame_product_size_mm': 200,
      'frame_count': 2,
      'width_mm': 415,
      'kg': 400,
      'waste_percent': 5,
      'note': 'Qatlamlar tartibi saqlansin',
      'layers': [
        {'material': 'PET', 'micron': '12'},
        {'material': 'BOPP', 'micron': '20'},
        {'material': 'PE', 'micron': '40'},
        {'material': 'CPP', 'micron': '25'},
      ],
      if (multipleProducts)
        'products': [
          {
            'id': 'p1',
            'item_code': 'SKU-A',
            'product': 'First product',
            'frame_product_size_mm': 80,
            'frame_count': 2
          },
          {
            'id': 'p2',
            'item_code': 'SKU-B',
            'product': 'Second product',
            'frame_product_size_mm': 120,
            'frame_count': 2
          },
        ],
    });

Future<void> _openExpectedOrderSummary(WidgetTester tester) async {
  await MobileApi.instance.adminSaveProductionMap(
    _productionOrderMap(
      id: 'zakaz-summary',
      title: 'Summary product',
      productCode: 'SUMMARY-1',
      apparatusId: _godexId,
      apparatusName: 'Paynet',
      product: 'Summary product',
      orderNumber: '0309',
      rollCount: 5,
      widthMm: 415,
    ).copyWith(orderKg: 400, baseLength: 18000),
  );
  await _usePhoneViewport(tester);
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
    home: const AdminProductionMapOrdersScreen(),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(
    const ValueKey('sequence-row-apparatus:test:godex-demo-zakaz-summary'),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kutilayotgan buyurtma ko‘rsatkichlari'));
  await tester.pumpAndSettle();
}

void _registerOrderSummaryTests() {
  for (final closed in [false, true]) {
    testWidgets('Rezka master can update print side when closed is $closed',
        (tester) async {
      const id = 'zakaz-0312';
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.rezkaMaster,
        displayName: 'Rezka master',
        legalName: '',
        ref: 'master',
        phone: '',
        avatarUrl: '',
        capabilities: ['rezka.master.access', 'apparatus.queue.read'],
        assignedApparatus: [_rezkaId],
      );
      await TestModeController.instance.setEnabled(false);
      var standard = true;
      var writes = 0;
      final map = _productionOrderMap(
        id: id,
        title: 'Rezka print side',
        orderNumber: '0312',
        productCode: 'SIDE',
        apparatusId: _rezkaId,
        product: 'Print side',
      );
      await _usePhoneViewport(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
            queueSnapshotLoader: () async => AdminApparatusQueueSnapshot(
              maps: [ProductionMapSaved(
                map: map.copyWith(standardPrintSide: standard),
                program: ProductionMapProgram(
                  mapId: id, productCode: 'SIDE', operations: const [],
                ),
              )],
              sequences: const {_rezkaId: [id]},
              visibleOrderIds: const {_rezkaId: [id]},
              queueStates: {_rezkaId: {id: closed ? 'completed' : 'pending'}},
              queuePolicies: const {},
              queueActionControls: {
                _rezkaId: {id: _freshStartQueueControl()},
              },
              orderControls: const {},
              revision: writes + 1,
              epoch: 'rezka-print-side-test',
            ),
            apparatusLoader: () async => const [
              AdminApparatus(id: _rezkaId, name: 'Rezka', operation: 'cut'),
            ],
            liveEventsLoader: () => const Stream.empty(),
          ),
        ));
        await _pumpCompletedWorkFrames(tester);
        if (closed) {
          final tab = find.text('Tugallangan');
          await tester.ensureVisible(tab);
          await tester.tap(tab);
          await _pumpCompletedWorkFrames(tester);
        }
        final row = find.byKey(closed
            ? const ValueKey(('worker-completed-order', id, _rezkaId))
            : const ValueKey('worker-order-$id'));
        final side = find.byKey(const ValueKey('rezka-master-print-side'));
        await tester.longPress(row);
        await _pumpCompletedWorkFrames(tester);
        expect(tester.widget<SwitchListTile>(side).value, isTrue);
        for (final key in [
          'calculate-duplicate-rezka-labels',
          'calculate-include-bobina-in-net',
        ]) {
          expect(
            find.byKey(ValueKey(key)),
            closed ? findsNothing : findsOneWidget,
          );
        }
        await tester.ensureVisible(side);
        await tester.tap(side);
        await _pumpCompletedWorkFrames(tester);
        await tester.tap(find.text(
          AppLocalizations(const Locale('uz')).productionText('worker.action.confirm'),
        ).last);
        await _pumpCompletedWorkFrames(tester);
        expect(writes, 1);
        expect(tester.widget<SwitchListTile>(side).value, isFalse);
        Navigator.of(tester.element(side)).pop();
        await _pumpCompletedWorkFrames(tester);
        await tester.longPress(row);
        await _pumpCompletedWorkFrames(tester);
        expect(tester.widget<SwitchListTile>(side).value, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }, () => MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/completed-orders')) {
          return http.Response(jsonEncode({'completed_orders': [
            if (closed) {
              'apparatus': _rezkaId, 'order_id': id, 'completed_at_unix': 100,
            },
          ]}), 200);
        }
        if (path.endsWith('/rezka-master/print-side')) {
          expect(request.method, 'PUT');
          expect(jsonDecode(request.body), {
            'order_id': id,
            'previous_standard_print_side': true,
            'standard_print_side': false,
          });
          standard = false;
          writes++;
          return http.Response('{"standard_print_side":false}', 200);
        }
        return http.Response('{}', 200);
      }));
    });
  }

  for (final standard in [true, false, null]) {
    testWidgets('worker expected summary shows print side $standard',
        (tester) async {
      const orderId = 'zakaz-summary-print-side';
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Bosmachi',
        legalName: '',
        ref: 'worker-summary-print-side',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_print7Id],
      );
      final saved = await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: orderId,
          title: 'Print side order',
          productCode: 'SIDE',
          apparatusId: _print7Id,
          product: 'Print side product',
          baseLength: 1000,
          rollCount: 2,
          widthMm: 515,
        ).copyWith(standardPrintSide: standard),
      );
      final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
      final snapshot = AdminApparatusQueueSnapshot(
        maps: [saved],
        sequences: const {_print7Id: [orderId]},
        visibleOrderIds: const {_print7Id: [orderId]},
        queueStates: const {
          _print7Id: {orderId: 'pending'},
        },
        queuePolicies: const {},
        queueActionControls: {
          _print7Id: {orderId: _freshStartQueueControl()},
        },
        orderControls: const {},
        revision: 1,
        epoch: 'summary-print-side',
      );
      await _usePhoneViewport(tester);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
          queueSnapshotLoader: () async => snapshot,
          apparatusLoader: () async => apparatus,
          liveEventsLoader: () => const Stream.empty(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final summary = find.text('Kutilayotgan natija');
      expect(summary, findsOneWidget);
      expect(find.text('Taraf'), findsNothing);
      await tester.ensureVisible(summary);
      await tester.tap(summary);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Taraf'), findsOneWidget);
      final value = find.text(standard == false ? 'Nostandart' : 'Standart');
      expect(value, findsOneWidget);
      expect(tester.widget<Text>(value).style?.fontWeight,
          standard == false ? FontWeight.w700 : FontWeight.w500);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
  testWidgets(
      'admin expected summary shows materials and width before estimated metrics',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance
        .upsertCalculateOrderTemplate(_summaryCalculation());
    await _openExpectedOrderSummary(tester);
    expect(find.text('18000 metr'), findsOneWidget);
    expect(find.text('400 kg'), findsOneWidget);
    for (final label in ['Val', 'Kadr soni', 'Bitta kadr eni']) {
      expect(find.text(label), findsNothing);
    }
    final details =
        find.byKey(const ValueKey('production-order-calculation-details'));
    for (final value in [
      '415 mm',
      '5 %',
      'PET · 12 mikron',
      'BOPP · 20 mikron',
      'PE · 40 mikron',
      'CPP · 25 mikron',
      '4-qatlam',
      'Qatlamlar tartibi saqlansin'
    ]) {
      expect(find.descendant(of: details, matching: find.text(value)),
          findsOneWidget);
    }
    for (final value in ['2 ta', '200 mm']) {
      expect(find.descendant(of: details, matching: find.text(value)),
          findsNothing);
    }
    final materialsTitle = find.text('Kerakli xomashyolar');
    final lastLayer = find.text('CPP · 25 mikron');
    final materialWidth = find.text('Xomashyo eni');
    final separator =
        find.descendant(of: details, matching: find.byType(Divider)).first;
    final estimatedSubtitle =
        find.text('Buyurtma bo‘yicha taxminiy ma’lumotlar');
    final length = find.text('18000 metr');
    expect(tester.getBottomLeft(materialsTitle).dy,
        lessThan(tester.getTopLeft(find.text('PET · 12 mikron')).dy));
    expect(tester.getBottomLeft(lastLayer).dy,
        lessThan(tester.getTopLeft(materialWidth).dy));
    expect(tester.getBottomLeft(materialWidth).dy,
        lessThan(tester.getTopLeft(separator).dy));
    expect(tester.getBottomLeft(separator).dy,
        lessThanOrEqualTo(tester.getTopLeft(estimatedSubtitle).dy));
    expect(tester.getBottomLeft(estimatedSubtitle).dy,
        lessThan(tester.getTopLeft(length).dy));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'admin expected summary preserves different frame widths per product',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _summaryCalculation(multipleProducts: true),
    );
    await _openExpectedOrderSummary(tester);
    expect(find.text('4 ta'), findsNothing);
    expect(find.text('First product'), findsOneWidget);
    expect(find.text('SKU-A · 2 ta kadr × 80 mm'), findsOneWidget);
    expect(find.text('Second product'), findsOneWidget);
    expect(find.text('SKU-B · 2 ta kadr × 120 mm'), findsOneWidget);
    expect(find.text('Bitta kadr eni'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'admin expected summary retries missing saved calculation without guessing materials',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    // Another order's recipe for this product must not be shown.
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _summaryCalculation()
          .copyWith(sourceMapId: 'zakaz-other', orderNumber: '9999'),
    );
    await _openExpectedOrderSummary(tester);
    expect(find.text('18000 metr'), findsOneWidget);
    expect(find.text('PET · 12 mikron'), findsNothing);
    final retry = find.widgetWithText(TextButton, 'Qayta yuklash');
    expect(retry, findsOneWidget);
    await MobileApi.instance
        .upsertCalculateOrderTemplate(_summaryCalculation());
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('PET · 12 mikron'), findsOneWidget);
    expect(retry, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (description, group, status, count) in [
    ('adds a single Rezka with 1+2 frames', false, 200, 3),
    ('adds a Rezka group with 1+2 frames per machine', true, 200, 3),
    ('blocks a missing calculation', false, 404, null),
    ('blocks an unrecoverable legacy calculation', false, 409, null),
    ('blocks a missing frame count despite a saved width', false, 200, null),
    ('blocks a fractional frame count', false, 200, 2.5),
  ]) {
    testWidgets('Rezka order summary $description', (tester) async {
      const map = ProductionMapDefinition(
        id: 'zakaz-rezka-fixture',
        productCode: 'REZKA-FIXTURE',
        title: 'Test product',
        orderNumber: '9001',
        nodes: [
          ProductionMapNode(
            id: 'start',
            kind: 'start',
            title: 'Start',
            x: 420,
            y: 32,
          ),
          ProductionMapNode(
            id: 'end',
            kind: 'end',
            title: 'End',
            x: 420,
            y: 164,
          ),
        ],
        edges: [ProductionMapEdge(from: 'start', to: 'end')],
      );
      var summaryReads = 0;
      ProductionMapDefinition? saved;
      await _usePhoneViewport(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminProductionMapTestScreen(savedMap: map),
        ));
        await tester.pumpAndSettle();
        await _tapMapTool(tester, 'Rezka');
        await tester.pumpAndSettle();
        await tester.tap(find.text(group ? 'Skip' : 'Rezka A'));
        await tester.pumpAndSettle();

        expect(summaryReads, 1);
        final save = find.text('Saqlash');
        expect(find.text('Rezka sozlash'), findsOneWidget);
        if (count != 3) {
          expect(find.textContaining('Buyurtmada kadr soni topilmadi'),
              findsOneWidget);
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(find.text('Rezka sozlash'), findsOneWidget);
          expect(saved, isNull);
        } else {
          expect(find.text('Kadr 3'), findsOneWidget);
          expect(find.text('Kadr 4'), findsNothing);
          await tester.tap(find.byKey(const ValueKey('rezka-frame-join-1')));
          await tester.pumpAndSettle();
          expect(find.text('Kadr 1'), findsOneWidget);
          expect(find.text('Kadr 2-3'), findsOneWidget);
          await tester.tap(save);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('production-map-save')));
          await tester.pumpAndSettle();
          final nodes = saved!.nodes.where((node) => node.kind == 'apparatus');
          expect(nodes, hasLength(group ? 2 : 1));
          for (final node in nodes) {
            expect(node.rezkaKadrCount, 3);
            expect(node.rezkaFrameGroups, [1, 2]);
          }
          expect(find.text('Map saqlandi. №9001 buyurtmasi yangilandi.'),
              findsOneWidget);
          await tester.pump(const Duration(seconds: 5));
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
          () => MockClient((request) async {
                final path = request.url.path;
                if (path == '/v1/mobile/admin/apparatus') {
                  return http.Response(
                      jsonEncode([
                        for (final (id, name) in [
                          (_rezkaId, 'Rezka A'),
                          ('apparatus:test:rezka-extra', 'Rezka B'),
                        ])
                          {
                            'apparatus_id': id,
                            'display': {'display_name': name},
                            'source_revision': 1,
                            'source_aasx_sha256': 'a' * 64,
                            'execution_profile': {
                              'operation': 'cut',
                              'technology': 'slitting',
                            },
                          },
                      ]),
                      200);
                }
                if (path == '/v1/mobile/admin/production-maps/order-summary') {
                  summaryReads++;
                  expect(request.url.queryParameters, {'id': map.id});
                  return http.Response(
                    status == 200
                        ? jsonEncode({
                            'template': {
                              'source_map_id': map.id,
                              'width_mm': 1095,
                              if (count != null) 'frame_count': count,
                            },
                          })
                        : '{}',
                    status,
                  );
                }
                if (path == '/v1/mobile/admin/production-maps' &&
                    request.method == 'PUT') {
                  saved = ProductionMapDefinition.fromJson(
                    jsonDecode(request.body) as Map<String, dynamic>,
                  );
                  return http.Response(
                    jsonEncode({'map': saved!.toJson(), 'program': {}}),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    },
                  );
                }
                fail('Unexpected request: ${request.method} ${request.url}');
              }));
    });
  }
}
