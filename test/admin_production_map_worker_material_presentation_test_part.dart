part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerMaterialPresentationTests() {
  const orderId = 'zakaz-mat-01';
  const unassigned = 'Ushbu buyurtma uchun homashyo biriktirilmagan';
  const notDelivered = 'Apparat oldiga homashyo olib kelinmagan';
  const notReady = 'Biriktirilgan homashyoni hozir qabul qilib bo‘lmaydi';

  Future<void> open(
    WidgetTester tester, {
    required List<String> statuses,
    int requiredCount = 0,
    int matchedCount = 0,
    bool scanSatisfied = false,
    bool blocked = false,
    bool materialRequired = true,
    bool groupsPolicy = false,
    bool holdLoading = false,
    bool failRead = false,
    required Future<void> Function(List<http.Request> requests) verify,
  }) async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Bosmachi',
      legalName: '',
      ref: 'worker-material-presentation',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [_print9Id],
    );
    await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
      id: orderId,
      title: 'Apachi',
      productCode: 'MPR',
      product: 'Apachi',
      apparatusId: _print9Id,
    ));
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: _print9Id,
      orderIds: const [orderId],
    );
    setMobileApiTestModeQueueActionControlFixture(
      apparatus: _print9Id,
      orderId: orderId,
      control: _freshStartQueueControl(materialScanRequired: materialRequired),
    );
    await _usePhoneViewport(tester);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        workerMode: true,
        liveEventsLoader: () => const Stream.empty(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_fixtureApparatusName(_print9Id)));
    await tester.pumpAndSettle();

    final requests = <http.Request>[];
    final assignments = [
      // The endpoint includes assignments for other apparatus as well.
      {
        'order_id': orderId,
        'apparatus': _print7Id,
        'barcode': 'OTHER-MACHINE',
        'execution_status': 'ready',
      },
      for (var n = 0; n < statuses.length; n++)
        {
          'order_id': orderId,
          'apparatus': _print9Id,
          'barcode': 'RM-PRESENTATION-$n',
          'item_name': 'CPP',
          'item_group': 'Rulon',
          'execution_status': statuses[n],
          'stock_status': statuses[n] == 'consumed' ? 'consumed' : 'available',
          'stock_qty': statuses[n] == 'consumed' ? 0 : 20,
          'stock_uom': 'kg',
        },
    ];
    final usable = assignments.skip(1).where((assignment) => !const {
          'consumed',
          'unavailable'
        }.contains(assignment['execution_status']));
    final staged = usable.where((assignment) =>
        const {'ready', 'in_use'}.contains(assignment['execution_status']));
    final requirementsResponse = http.Response(
      jsonEncode({
        'policy': groupsPolicy ? 'requirement_groups' : 'state_all',
        'requires_material': materialRequired,
        'material_scan_required': materialRequired,
        'assigned_barcodes': usable.map((row) => row['barcode']).toList(),
        'staged_barcodes': staged.map((row) => row['barcode']).toList(),
        'required_scan_count': requiredCount,
        'matched_scan_count': matchedCount,
        'assignments_satisfied': statuses.isNotEmpty || !materialRequired,
        'scan_satisfied': scanSatisfied,
        'assignments': assignments,
        'start_assignments': staged.toList(),
      }),
      200,
    );
    final loading = holdLoading ? Completer<http.Response>() : null;
    await http.runWithClient(() async {
      await TestModeController.instance.setEnabled(false);
      await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
      if (loading != null) {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(unassigned), findsNothing);
        expect(find.text(notDelivered), findsNothing);
        expect(find.text('0/0'), findsNothing);
        expect(find.byKey(const ValueKey('material-alert:$orderId:$_print9Id')),
            findsNothing);
        loading.complete(requirementsResponse);
      }
      await _waitForWorkerMaterialRead(tester);
      await verify(requests);
      expect(requests.where((request) => request.method != 'GET'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              requests.add(request);
              if (request.url.path.endsWith('/order-scan-bootstrap')) {
                return http.Response('', 404);
              }
              if (request.url.path.endsWith('/sequence')) {
                return http.Response(
                    jsonEncode({
                      'sequences': {
                        _print9Id: [orderId]
                      },
                      'visible_order_ids': {
                        _print9Id: [orderId]
                      },
                      'queue_states': {
                        _print9Id: {orderId: 'pending'}
                      },
                      'stage_states': {},
                      'queue_policies': [],
                      'queue_action_controls': {
                        _print9Id: {
                          orderId: {
                            'state': 'pending',
                            'allowed_actions': blocked ? [] : ['start'],
                            'previous_stage_ready': true,
                            'complete_requires_full_report': false,
                            'interaction': {
                              'mode': blocked
                                  ? 'fresh_start_blocked'
                                  : 'fresh_start',
                              'start_materials_mode':
                                  materialRequired ? 'scan_required' : 'hidden',
                              'material_scan_required': materialRequired,
                              'assigned_materials_display_only': true,
                              'material_intake_allowed': false,
                              'previous_wip_mode': 'not_required',
                              'opening_wip_mode': 'not_required',
                              'qolip_mode': 'not_required',
                              'blocking_reason_code': blocked
                                  ? 'raw_material_assignment_required'
                                  : '',
                            },
                          },
                        },
                      },
                      'order_controls': {
                        orderId: {'state': 'active'}
                      },
                      'order_statuses': {},
                      'frozen_orders_by_apparatus': {},
                    }),
                    200);
              }
              if (request.url.path
                  .endsWith('/raw-material-start-requirements')) {
                if (failRead) {
                  return http.Response(
                      jsonEncode({
                        'error': 'raw_material_rule_load_failed',
                        'message': 'Homashyo ma’lumotini o‘qib bo‘lmadi',
                      }),
                      503);
                }
                return loading?.future ?? requirementsResponse;
              }
              if (request.url.path.endsWith('/material-link-requests')) {
                return http.Response(
                    jsonEncode({
                      'candidates': [
                        {
                          'barcode': 'FREE-ROLL',
                          'item_name': 'CPP',
                          'qty': 10,
                          'uom': 'kg'
                        }
                      ],
                      'requests': [],
                    }),
                    200);
              }
              return http.Response('{"items":[]}', 200);
            }));
  }

  for (final blocked in [false, true]) {
    testWidgets('worker material presentation: unassigned, blocked=$blocked',
        (tester) async {
      await open(tester, statuses: const [], blocked: blocked,
          verify: (requests) async {
        expect(find.text(unassigned), findsOneWidget);
        expect(
            find.text('Ish boshlash uchun homashyo topilmadi'), findsNothing);
        expect(find.text('Majburiy homashyo guruhlari to‘liq biriktirilmagan'),
            findsNothing);
        expect(find.text('Biriktirilgan homashyolar'), findsNothing);
        expect(find.text('0/0'), findsNothing);
        expect(find.byKey(const ValueKey('material-alert:$orderId:$_print9Id')),
            findsOneWidget);
        expect(find.text('Ulash uchun so‘rov'), findsOneWidget);
        expect(find.text('Orderga ulanmagan rulonlar'), findsNothing);
        final linkButton =
            find.widgetWithText(OutlinedButton, 'Ulash uchun so‘rov');
        final alertButton = find.descendant(
          of: find.byKey(const ValueKey('material-alert:$orderId:$_print9Id')),
          matching: find.byType(OutlinedButton),
        );
        const buttonShape = RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        );
        for (final finder in [linkButton, alertButton]) {
          expect(
              tester.widget<OutlinedButton>(finder).style?.shape?.resolve({}),
              buttonShape);
        }
        final explanation = find.text(
            'Apparat oldidagi 1 ta mos rulondan keraklisini tanlab so‘rov yuboring');
        final buttonGap = tester.getTopLeft(alertButton).dy -
            tester.getBottomLeft(linkButton).dy;
        final explanationGap = tester.getTopLeft(linkButton).dy -
            tester.getBottomLeft(explanation).dy;
        expect(buttonGap, 10);
        expect(explanationGap, buttonGap);
        if (!blocked) {
          expect(
              tester
                  .widget<FilledButton>(
                      find.widgetWithText(FilledButton, 'Boshlash'))
                  .style
                  ?.shape
                  ?.resolve({}),
              buttonShape);
          expect(
              tester
                  .widget<FilledButton>(
                      find.widgetWithText(FilledButton, 'Boshlash'))
                  .onPressed,
              isNull);
        }
      });
    });
  }

  for (final scenario in [
    (
      name: 'awaiting delivery',
      statuses: ['awaiting_delivery'],
      required: 0,
      matched: 0,
      satisfied: false,
      groups: false,
      status: notDelivered,
      detail: ''
    ),
    (
      name: 'available but unscanned',
      statuses: ['ready'],
      required: 1,
      matched: 0,
      satisfied: false,
      groups: false,
      status: 'Biriktirilgan homashyolar',
      detail: ''
    ),
    (
      name: 'confirmed QR',
      statuses: ['ready'],
      required: 1,
      matched: 1,
      satisfied: true,
      groups: false,
      status: 'Biriktirilgan homashyolar',
      detail: ''
    ),
    (
      name: 'partial delivery',
      statuses: [
        'ready',
        'awaiting_delivery',
        'awaiting_delivery',
        'ready',
        'awaiting_delivery'
      ],
      required: 2,
      matched: 0,
      satisfied: false,
      groups: false,
      status: 'Biriktirilgan homashyolar',
      detail: '2 ta apparat oldida, 3 ta yetkazilishi kutilmoqda'
    ),
    (
      name: 'group policy retains server scan target',
      statuses: ['ready', 'awaiting_delivery'],
      required: 1,
      matched: 1,
      satisfied: true,
      groups: true,
      status: 'Biriktirilgan homashyolar',
      detail: '1 ta apparat oldida, 1 ta yetkazilishi kutilmoqda'
    ),
    (
      name: 'consumed material',
      statuses: ['consumed'],
      required: 0,
      matched: 0,
      satisfied: false,
      groups: false,
      status: 'Biriktirilgan homashyolar',
      detail: notReady
    ),
    (
      name: 'unavailable material',
      statuses: ['unavailable'],
      required: 0,
      matched: 0,
      satisfied: false,
      groups: false,
      status: 'Biriktirilgan homashyolar',
      detail: notReady
    ),
  ]) {
    testWidgets('worker material presentation: ${scenario.name}',
        (tester) async {
      await open(tester,
          statuses: scenario.statuses,
          requiredCount: scenario.required,
          matchedCount: scenario.matched,
          scanSatisfied: scenario.satisfied,
          groupsPolicy: scenario.groups, verify: (requests) async {
        expect(find.text(scenario.status), findsOneWidget);
        expect(find.text(unassigned), findsNothing);
        expect(
            find.text('Ish boshlash uchun homashyo topilmadi'), findsNothing);
        expect(find.text('0/0'), findsNothing);
        if (scenario.detail.isNotEmpty)
          expect(find.text(scenario.detail), findsOneWidget);
        if (scenario.required > 0) {
          expect(find.text('${scenario.matched}/${scenario.required}'),
              findsOneWidget);
          expect(find.text('Homashyo QR tasdiqlari'), findsOneWidget);
        } else {
          expect(
              find.byKey(
                  const ValueKey('production-start-materials-expansion')),
              findsNothing);
        }
        final header =
            find.byKey(const ValueKey('production-materials-expansion'));
        if (scenario.status == notDelivered) {
          expect(find.descendant(of: header, matching: find.text('ta')),
              findsNothing);
        } else {
          expect(
              find.descendant(
                  of: header,
                  matching: find.text('${scenario.statuses.length}')),
              findsOneWidget);
          expect(find.text(notDelivered), findsNothing);
        }
        expect(
            tester
                .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Boshlash'))
                .onPressed,
            scenario.satisfied ? isNotNull : isNull);
        await tester.ensureVisible(header);
        await tester.tap(header);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.textContaining('RM-PRESENTATION-0'), findsOneWidget);
        expect(find.textContaining('OTHER-MACHINE'), findsNothing);
        await tester.tap(header);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.textContaining('RM-PRESENTATION-0'), findsNothing);
        // Linking stays visible and its polling remains mounted when collapsed.
        expect(find.text('Ulash uchun so‘rov'), findsOneWidget);
        final polls = requests
            .where((r) => r.url.path.endsWith('/material-link-requests'))
            .length;
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(
            requests
                .where((r) => r.url.path.endsWith('/material-link-requests'))
                .length,
            greaterThan(polls));
      });
    });
  }

  testWidgets('worker material presentation: loading is not unassigned',
      (tester) async {
    await open(tester, statuses: const [], holdLoading: true,
        verify: (_) async {
      expect(find.text(unassigned), findsOneWidget);
    });
  });

  testWidgets('worker material presentation: failed read is not unassigned',
      (tester) async {
    await open(tester, statuses: const [], failRead: true, verify: (_) async {
      expect(find.text(unassigned), findsNothing);
      expect(find.text(notDelivered), findsNothing);
      final dynamic card = tester.widget(find.byWidgetPredicate((widget) =>
          widget.runtimeType.toString() == '_OrderStartUnifiedCard'));
      expect(card.materialsError, isNotEmpty);
      expect(find.text(card.materialsError as String), findsOneWidget);
      expect(find.text('0/0'), findsNothing);
      expect(find.byKey(const ValueKey('material-alert:$orderId:$_print9Id')),
          findsNothing);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Boshlash'))
              .onPressed,
          isNull);
    });
  });

  testWidgets(
      'worker material presentation: optional materials have no missing warning',
      (tester) async {
    await open(tester,
        statuses: const [],
        materialRequired: false,
        scanSatisfied: true, verify: (_) async {
      expect(find.text(unassigned), findsNothing);
      expect(find.text(notDelivered), findsNothing);
      expect(find.text('0/0'), findsNothing);
      expect(find.byKey(const ValueKey('material-alert:$orderId:$_print9Id')),
          findsNothing);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Boshlash'))
              .onPressed,
          isNotNull);
    });
  });
}

Future<void> _waitForWorkerMaterialRead(WidgetTester tester) async {
  // Background order captions can keep animating while this sheet is open.
  // Wait for the material read itself, rather than all app animations.
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    final cards = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_OrderStartUnifiedCard');
    if (cards.evaluate().isNotEmpty) {
      final dynamic card = tester.widget(cards);
      if (card.materialsLoading == false) {
        await tester.pump(const Duration(milliseconds: 350));
        return;
      }
    }
  }
  fail('Material read did not finish');
}
