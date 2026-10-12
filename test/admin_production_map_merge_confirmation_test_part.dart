part of 'admin_production_map_test_screen_test.dart';

void _registerMergeConfirmationTests() {
  for (final outcome in ['cancel', 'dismiss', 'confirm', 'rejected']) {
    testWidgets('worker merge requires explicit confirmation: $outcome',
        (tester) async {
      const orderId = 'zakaz-0002';
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Rezkachi',
        legalName: '',
        ref: 'merge-worker',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_rezkaId],
      );
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: orderId,
        orderNumber: '0002',
        title: 'Merge test',
        productCode: 'MERGE',
        product: 'Merge test',
        apparatusId: _rezkaId,
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _rezkaId, orderIds: const [orderId]);
      await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _rezkaId, orderId: orderId, action: 'start');
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: _rezkaId,
        orderId: orderId,
        control: _inProgressQueueControl(
          allowMerge: true,
          stageNodeId: 'apparatus',
          rezkaInputLineage: const [
            AdminRezkaInputLink(
                inputBatchId: 'private-current-wip',
                sequenceNo: 1,
                status: 'in_use'),
          ],
        ),
      );
      await _usePhoneViewport(tester);
      final mutations = <http.Request>[];
      final response = Completer<http.Response>();
      await http.runWithClient(() async {
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
              liveEventsLoader: () => const Stream.empty()),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rezka'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Merge test').first);
        await tester.pumpAndSettle();
        await TestModeController.instance.setEnabled(false);
        final mergeButton =
            find.byKey(const ValueKey('production-order-merge-action'));
        await tester.ensureVisible(mergeButton);
        await tester.tap(mergeButton);
        await tester.pumpAndSettle();
        final scan = tester
            .widget<ProductionQuickScannerPanel>(
                find.byType(ProductionQuickScannerPanel))
            .onCodeDetected;
        final pendingScan = scan('ROLL-002');
        await tester.pumpAndSettle();
        expect(mutations, isEmpty,
            reason: 'scanning a QR alone must never send a merge');
        expect(find.byType(ProductionQuickScannerPanel), findsNothing);
        expect(find.text('2-rulonni 1-rulonning davomiga ulaysizmi?'),
            findsOneWidget);
        expect(find.text('QR: ROLL-002'), findsOneWidget);
        expect(find.text('Buyurtma №0002'), findsOneWidget);
        expect(find.textContaining('ortga qaytarib bo‘lmaydi'), findsOneWidget);
        expect(find.textContaining('private-current-wip'), findsNothing);
        // A duplicate or late camera callback must not create another prompt.
        await scan('ROLL-002');
        await scan('ROLL-003');
        await tester.pump();
        expect(find.byKey(const ValueKey('production-merge-confirm-dialog')),
            findsOneWidget);
        expect(mutations, isEmpty);
        if (outcome == 'cancel' || outcome == 'dismiss') {
          if (outcome == 'cancel') {
            await tester
                .tap(find.byKey(const ValueKey('production-merge-cancel')));
          } else {
            await tester.tapAt(const Offset(2, 2));
          }
          await tester.pumpAndSettle();
          await pendingScan;
          await scan('ROLL-002');
          await tester.pumpAndSettle();
          expect(mutations, isEmpty);
          expect(find.byType(ProductionQuickScannerPanel), findsNothing);
          expect(find.textContaining('davomiga ulandi.'), findsNothing);
          // The worker can deliberately reopen scanning and try again.
          await tester.tap(mergeButton);
          await tester.pumpAndSettle();
          final retry = tester
              .widget<ProductionQuickScannerPanel>(
                  find.byType(ProductionQuickScannerPanel))
              .onCodeDetected('ROLL-002');
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('production-merge-confirm-dialog')),
              findsOneWidget);
          await tester
              .tap(find.byKey(const ValueKey('production-merge-cancel')));
          await tester.pumpAndSettle();
          await retry;
          expect(mutations, isEmpty);
        } else {
          await tester
              .tap(find.byKey(const ValueKey('production-merge-confirm')));
          await tester.pump();
          await scan('ROLL-003');
          expect(mutations, hasLength(1));
          final payload = jsonDecode(mutations.single.body) as Map;
          expect(payload['action'], 'merge');
          expect(payload['qr_payload'], 'ROLL-002');
          expect(payload['order_id'], orderId);
          expect(payload['apparatus'], _rezkaId);
          response.complete(outcome == 'rejected'
              ? http.Response('{"error":"merge_input_already_used"}', 409)
              : http.Response(
                  jsonEncode({
                    'ok': true,
                    'states': {orderId: 'in_progress'},
                    'order_control': {'state': 'active'},
                  }),
                  200));
          await tester.pumpAndSettle();
          if (outcome == 'rejected') {
            final guidance =
                find.byKey(const ValueKey('production-wip-guidance-dialog'));
            expect(guidance, findsOneWidget);
            expect(
                find.descendant(
                    of: guidance,
                    matching: find.text(AppLocalizations(const Locale('uz'))
                        .productionText(
                            'worker.error.merge_input_already_used'))),
                findsOneWidget);
            await _closeInlineWipGuidance(tester);
          }
          await pendingScan;
          expect(mutations, hasLength(1));
          expect(find.text('2-rulon 1-rulonning davomiga ulandi.'),
              outcome == 'confirm' ? findsOneWidget : findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 30));
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/queue-action')) {
                  mutations.add(request);
                  return response.future;
                }
                if (request.url.path.endsWith('/order-scan-bootstrap')) {
                  return http.Response('', 404);
                }
                if (request.url.path.endsWith('/lookup')) {
                  final payload = jsonDecode(request.body) as Map;
                  return http.Response(
                      jsonEncode({
                        'active_order_validated': true,
                        if (payload.containsKey('apparatus'))
                          'validated_apparatus': payload['apparatus'],
                        if (payload.containsKey('order_id'))
                          'validated_order_id': payload['order_id'],
                        'batch': {
                          'batch_id': 'private-next-wip',
                          'order_id': orderId,
                          'apparatus': _print9Id,
                          'action': 'detach_roll',
                          'status': 'roll_detached',
                          'qr_payload': payload['qr_payload'],
                          'produced_qty': 100,
                          'uom': 'm',
                          'wip_status': 'waiting',
                          'next_apparatus': _rezkaId,
                          'payload_json': {'next_stage_node_id': 'apparatus'},
                        },
                      }),
                      200);
                }
                if (request.url.path.endsWith('/sequence')) {
                  return http.Response(
                      jsonEncode({
                        'sequences': {
                          _rezkaId: [orderId]
                        },
                        'visible_order_ids': {
                          _rezkaId: [orderId]
                        },
                        'queue_states': {
                          _rezkaId: {orderId: 'in_progress'}
                        },
                        'queue_policies': [],
                        'stage_states': {},
                        'order_controls': {},
                        'order_statuses': {},
                        'frozen_orders_by_apparatus': {},
                        'queue_action_controls': {
                          _rezkaId: {
                            orderId: {
                              'state': 'in_progress',
                              'allowed_actions': [
                                'pause',
                                'detach_roll',
                                'merge',
                                'complete',
                                'freeze'
                              ],
                              'stage_node_id': 'apparatus',
                              'previous_stage_ready': true,
                              'complete_requires_full_report': false,
                              'rezka_input_lineage': [
                                {
                                  'input_batch_id': 'private-current-wip',
                                  'source_kind': 'progress_batch',
                                  'sequence_no': 1,
                                  'status': 'in_use'
                                },
                              ],
                              'interaction': {
                                'mode': 'in_progress',
                                'start_materials_mode': 'hidden',
                                'material_scan_required': false,
                                'assigned_materials_display_only': true,
                                'material_intake_allowed': false,
                                'previous_wip_mode': 'not_required',
                                'opening_wip_mode': 'not_required',
                                'qolip_mode': 'not_required',
                              },
                            }
                          }
                        },
                      }),
                      200);
                }
                if (request.url.path.endsWith('/raw-material-assignments')) {
                  return http.Response('[]', 200);
                }
                if (request.url.path.endsWith('/wip-batches')) {
                  return http.Response('{"batches":[]}', 200);
                }
                return http.Response('{"error":"store_failed"}', 503);
              }));
    });
  }
}
