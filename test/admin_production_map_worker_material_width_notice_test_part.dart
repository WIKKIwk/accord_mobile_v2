part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerMaterialWidthNoticeTests() {
  const orderId = 'zakaz-0003';
  const genericNotice =
      'Homashyo biriktirilgan, lekin rulon eni orderga kichik.';

  test('worker material width notice: assignment parsing and copy retain width',
      () {
    for (final width in <num?>[855, 855.5, null]) {
      final assignment = AdminRawMaterialAssignment.fromJson({
        'order_id': orderId,
        'apparatus': _print9Id,
        'barcode': 'RM-01',
        'execution_status': 'width_mismatch',
        if (width != null) 'roll_width_mm': width,
      });
      expect(assignment.rollWidthMm, width?.toDouble());
      final updated = assignment.copyWith(stockQty: 22);
      expect(updated.rollWidthMm, width?.toDouble());
      expect(updated.executionStatus, 'width_mismatch');
    }
  });

  for (final scenario in [
    (
      name: '855 mm rolls for 915 mm order',
      status: 'width_mismatch',
      width: 855.0,
      orderWidth: 915.0,
      satisfied: false,
      expected: '$genericNotice Rulon eni: 855 mm. Order eni: 915 mm.'
    ),
    (
      name: 'fractional widths',
      status: 'width_mismatch',
      width: 855.5,
      orderWidth: 915.25,
      satisfied: false,
      expected: '$genericNotice Rulon eni: 855.5 mm. Order eni: 915.25 mm.'
    ),
    (
      name: 'missing roll width',
      status: 'width_mismatch',
      width: null,
      orderWidth: 915.0,
      satisfied: false,
      expected: genericNotice
    ),
    (
      name: 'missing order width',
      status: 'width_mismatch',
      width: 855.0,
      orderWidth: null,
      satisfied: false,
      expected: genericNotice
    ),
    (
      name: 'oversized roll still waits for cutting',
      status: 'needs_cutting',
      width: 1830.0,
      orderWidth: 915.0,
      satisfied: false,
      expected:
          'Homashyo biriktirilgan, lekin apparatingizga katta. Rezka kutilmoqda'
    ),
    (
      name: 'other apparatus mismatch does not hide missing groups',
      status: 'ready',
      width: 915.0,
      orderWidth: 915.0,
      satisfied: false,
      expected: 'Majburiy homashyo guruhlari to‘liq biriktirilmagan'
    ),
    (
      name: 'ready material has no mismatch notice',
      status: 'ready',
      width: 915.0,
      orderWidth: 915.0,
      satisfied: true,
      expected: ''
    ),
  ]) {
    testWidgets('worker material width notice: ${scenario.name}',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Bosmachi',
        legalName: '',
        ref: 'worker-width-notice',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_print9Id],
      );
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: orderId,
        title: 'Apachi 900 gr',
        productCode: 'APACHI',
        product: 'Apachi',
        apparatusId: _print9Id,
        widthMm: scenario.orderWidth,
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: _print9Id,
        orderIds: const [orderId],
      );
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: _print9Id,
        orderId: orderId,
        control: _freshStartQueueControl(materialScanRequired: true),
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
        // The endpoint includes other apparatus' materials too.
        {
          'order_id': orderId,
          'apparatus': _print7Id,
          'barcode': 'OTHER',
          'execution_status': 'width_mismatch',
          'roll_width_mm': 700
        },
        for (var n = 1; n <= 2; n++)
          {
            'order_id': orderId,
            'apparatus': _print9Id,
            'barcode': 'RM-0$n',
            'item_code': 'Upakovka',
            'item_name': 'CPP',
            'item_group': 'Rulon',
            'execution_status': scenario.status,
            'roll_width_mm': scenario.width,
            'stock_status': 'available',
            'stock_qty': n == 1 ? 22 : 49.5,
            'stock_uom': 'kg'
          },
      ];
      await http.runWithClient(() async {
        await TestModeController.instance.setEnabled(false);
        await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
        await tester.pumpAndSettle();

        final card = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_OrderStartUnifiedCard',
        );
        expect(card, findsOneWidget);
        if (scenario.expected.isNotEmpty) {
          expect(
              find.descendant(of: card, matching: find.text(scenario.expected)),
              findsOneWidget);
        } else {
          expect(find.textContaining(genericNotice), findsNothing);
        }
        if (scenario.status == 'width_mismatch') {
          expect(
              find.text('Majburiy homashyo guruhlari to‘liq biriktirilmagan'),
              findsNothing);
          expect(find.text('0/0'), findsOneWidget);
        }
        final attached =
            find.byKey(const ValueKey('production-materials-expansion'));
        expect(find.descendant(of: attached, matching: find.text('2')),
            findsOneWidget);
        expect(find.descendant(of: attached, matching: find.text('ta')),
            findsOneWidget);
        expect(
            requests.where((request) =>
                request.url.path.endsWith('/raw-material-start-requirements')),
            hasLength(1));
        expect(requests.where((request) => request.method != 'GET'), isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                requests.add(request);
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
                              'allowed_actions': ['start'],
                              'previous_stage_ready': true,
                              'complete_requires_full_report': false,
                              'interaction': {
                                'mode': 'fresh_start',
                                'start_materials_mode': 'scan_required',
                                'material_scan_required': true,
                                'assigned_materials_display_only': true,
                                'material_intake_allowed': false,
                                'previous_wip_mode': 'not_required',
                                'opening_wip_mode': 'not_required',
                                'qolip_mode': 'not_required',
                                'blocking_reason_code': '',
                              },
                            }
                          }
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
                  return http.Response(
                      jsonEncode({
                        'policy': 'state_all',
                        'requires_material': false,
                        'material_scan_required': true,
                        'assigned_barcodes': ['rm-01', 'RM-02'],
                        'staged_barcodes':
                            scenario.satisfied ? ['RM-01', 'RM-02'] : [],
                        'required_scan_count': scenario.satisfied ? 2 : 0,
                        'matched_scan_count': 0,
                        'assignments_satisfied': scenario.satisfied,
                        'scan_satisfied': false,
                        'assignments': assignments,
                        'start_assignments': scenario.satisfied
                            ? assignments.skip(1).toList()
                            : [],
                      }),
                      200);
                }
                return http.Response('{"items":[]}', 200);
              }));
    });
  }
}
