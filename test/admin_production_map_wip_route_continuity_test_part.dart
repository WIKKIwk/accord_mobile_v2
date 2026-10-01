part of 'admin_production_map_test_screen_test.dart';

void _registerWipRouteContinuityTests() {
  const orderId = 'zakaz-0004';
  const oldQr = '400118DA2F17C3617F59DDC6';
  const rezka2 = 'apparatus:default:asset-011';
  final l10n = AppLocalizations(const Locale('uz'));

  for (final scenario in [
    'resolved-repeat',
    'resolved-refresh',
    'resolved-refresh-omitted',
    'resolved-refresh-ambiguous',
    'wip_route_source_unresolved',
    'wip_route_destination_unresolved',
    'wip_route_ambiguous',
    'empty-authoritative-route',
    'unassigned',
    'queue-blocked',
    'used',
    'in-use',
  ]) {
    testWidgets('old printed WIP QR after map edit: $scenario', (tester) async {
      await TestModeController.instance.setEnabled(false);
      AppSession.instance.profile = SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Rezka2 worker',
        legalName: '',
        ref: 'route-worker',
        phone: '',
        avatarUrl: '',
        capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [scenario == 'unassigned' ? _lamination1Id : rezka2],
      );
      final map = ProductionMapDefinition.fromJson({
        'id': orderId,
        'order_number': '0004',
        'title': 'Lazer guruch uzun don 2 kg',
        'product_code': 'LAZER',
        'nodes': [
          {'id': 'start', 'kind': 'start', 'title': 'Start'},
          {
            'id': 'laminatsiya_4',
            'kind': 'apparatus',
            'title': 'Laminatsiya1',
            'apparatus_id': _lamination1Id
          },
          {
            'id': 'apparatus_6',
            'kind': 'apparatus',
            'title': 'Rezka',
            'apparatus_id': _rezkaId,
            'alternative_group_id': 'alt_cut_6'
          },
          {
            'id': 'apparatus_7',
            'kind': 'apparatus',
            'title': 'Rezka2',
            'apparatus_id': rezka2,
            'alternative_group_id': 'alt_cut_6'
          },
          {'id': 'end', 'kind': 'end', 'title': 'End'},
        ],
        'edges': [
          {'from': 'start', 'to': 'laminatsiya_4'},
          {'from': 'laminatsiya_4', 'to': 'apparatus_6'},
          {'from': 'laminatsiya_4', 'to': 'apparatus_7'},
          {'from': 'apparatus_6', 'to': 'end'},
          {'from': 'apparatus_7', 'to': 'end'},
        ],
      });
      final saved = ProductionMapSaved.fromJson(
          {'map': map.toJson(), 'program': <String, dynamic>{}});
      final controlJson = {
        'state': 'pending',
        'stage_node_id': 'apparatus_7',
        'allowed_actions': scenario == 'queue-blocked' ? <String>[] : ['start'],
        'previous_stage': _lamination1Id,
        'previous_stage_ready': false,
        'complete_requires_full_report': false,
        'interaction': {
          'mode': scenario == 'queue-blocked'
              ? 'fresh_start_blocked'
              : 'fresh_start',
          'start_materials_mode': 'hidden',
          'material_scan_required': false,
          'assigned_materials_display_only': true,
          'material_intake_allowed': false,
          'previous_wip_mode': 'scan_required',
          'opening_wip_mode': 'not_required',
          'qolip_mode': 'not_required',
          'blocking_reason_code':
              scenario == 'queue-blocked' ? 'waiting_sequence' : '',
        },
      };
      final snapshot = AdminApparatusQueueSnapshot(
        revision: 1,
        epoch: 'route-test',
        maps: [saved],
        sequences: const {
          rezka2: [orderId]
        },
        visibleOrderIds: const {
          rezka2: [orderId]
        },
        queueStates: const {
          rezka2: {orderId: 'pending'}
        },
        queuePolicies: const {},
        orderControls: const {},
        queueActionControls: {
          rezka2: {
            orderId: AdminApparatusQueueOrderActionControl.fromJson(controlJson)
          }
        },
      );
      final sequenceJson = {
        'rev': 1,
        'epoch': 'route-test',
        'maps': [
          {'map': map.toJson(), 'program': <String, dynamic>{}}
        ],
        'sequences': {
          rezka2: [orderId]
        },
        'visible_order_ids': {
          rezka2: [orderId]
        },
        'queue_states': {
          rezka2: {orderId: 'pending'}
        },
        'stage_states': <String, dynamic>{},
        'queue_policies': [],
        'queue_action_controls': {
          rezka2: {orderId: controlJson}
        },
        'order_controls': <String, dynamic>{},
        'order_statuses': <String, dynamic>{},
        'frozen_orders_by_apparatus': <String, dynamic>{},
      };
      expect(snapshot.queueActionControls[rezka2]![orderId]!.contractValid,
          isTrue);
      final originalBatch = {
        'batch_id': 'immutable-lamination-roll',
        'order_id': orderId,
        'apparatus': _lamination1Id,
        'next_apparatus': _rezkaId,
        'qr_payload': oldQr,
        'produced_qty': 6170,
        'uom': 'm',
        'action': 'detach_roll',
        'wip_status': scenario == 'used'
            ? 'processed'
            : scenario == 'in-use'
                ? 'in_use'
                : 'waiting',
        'payload_json': {
          'production_stage_node_id': 'laminatsiya_4',
          'next_stage_node_id': 'rezka_5'
        },
      };
      final qrRequests = <Map<String, dynamic>>[];
      final startRequests = <Map<String, dynamic>>[];
      final liveEvents = StreamController<AdminProductionMapLiveSnapshot>();
      addTearDown(liveEvents.close);
      liveEvents.add(AdminProductionMapLiveSnapshot.fromJson({
        ...sequenceJson,
        'completed_orders': [],
        'completion_requests': [],
        'completion_request_decisions': [],
      }));
      var scannerRoutes = 0;
      await http.runWithClient(() async {
        await _usePhoneViewport(tester);
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: (settings) {
            expect(settings.name, AppRoutes.adminProgressQrScan);
            scannerRoutes++;
            return MaterialPageRoute<String>(
                builder: (context) => Scaffold(
                        body: TextButton(
                      key: const ValueKey('return-old-wip-qr'),
                      onPressed: () => Navigator.of(context).pop(oldQr),
                      child: const Text('Scan printed QR'),
                    )));
          },
          home: AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
            queueSnapshotLoader: () async => snapshot,
            apparatusLoader: () async => const [
              AdminApparatus(
                  id: _lamination1Id,
                  name: 'Laminatsiya1',
                  operation: 'laminate'),
              AdminApparatus(id: _rezkaId, name: 'Rezka', operation: 'cut'),
              AdminApparatus(id: rezka2, name: 'Rezka2', operation: 'cut'),
            ],
            liveEventsLoader: () => liveEvents.stream,
          ),
        ));
        await tester.pumpAndSettle();
        final repetitions = scenario == 'resolved-repeat' ? 2 : 1;
        for (var scan = 0; scan < repetitions; scan++) {
          final scanFuture = tester
              .widget<AparatchiDock>(find.byType(AparatchiDock))
              .onQrScanRequested!();
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('return-old-wip-qr')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await scanFuture;
          if (scenario.startsWith('resolved-')) {
            await tester.pumpAndSettle();
          } else {
            await tester.pump(const Duration(milliseconds: 300));
          }
          final detail = find.byWidgetPredicate((widget) =>
              widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet');
          if (scenario.startsWith('resolved-')) {
            expect(detail, findsOneWidget,
                reason:
                    'requests=$qrRequests texts=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}');
            expect(
                find.text(
                    l10n.productionText('worker.progress.previous.confirmed')),
                findsOneWidget);
            final start = find.widgetWithText(FilledButton, 'Boshlash');
            expect(start, findsOneWidget);
            expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
            expect(
                qrRequests.where((body) => body['apparatus'] == rezka2).length,
                greaterThanOrEqualTo((scan + 1) * 2));
            if (scenario.startsWith('resolved-refresh')) {
              await tester.ensureVisible(start);
              await tester.tap(start);
              await tester.pumpAndSettle();
              await tester.pump(const Duration(milliseconds: 500));
              await tester.pumpAndSettle();
              expect(startRequests, hasLength(1));
              expect(startRequests.single['qr_payload'], oldQr);
              expect(startRequests.single['progress_batch_id'],
                  'immutable-lamination-roll');
              expect(
                  qrRequests
                      .where((body) => body['apparatus'] == rezka2)
                      .length,
                  greaterThanOrEqualTo(3),
                  reason:
                      'Refreshing the immutable list row must revalidate the accepted QR');
              expect(
                  tester.widget<FilledButton>(start).onPressed,
                  scenario == 'resolved-refresh-ambiguous'
                      ? isNull
                      : isNotNull);
            }
            Navigator.of(tester.element(start)).pop(false);
            await tester.pumpAndSettle();
          } else {
            expect(detail, findsNothing);
            final expectedText = scenario.startsWith('wip_route_')
                ? l10n.productionErrorMessage(scenario)
                : scenario == 'empty-authoritative-route'
                    ? l10n.productionErrorMessage(
                        'wip_route_destination_unresolved')
                    : scenario == 'queue-blocked'
                        ? l10n.productionText('worker.waiting.sequence')
                        : scenario == 'used'
                            ? l10n.productionText('worker.error.wip_used')
                            : scenario == 'in-use'
                                ? l10n.productionText('worker.error.wip_in_use')
                                : l10n.productionText(
                                    'worker.error.assigned_machine');
            expect(find.text(expectedText), findsOneWidget,
                reason:
                    'requests=$qrRequests texts=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}');
          }
        }
        expect(scannerRoutes, repetitions);
        expect(qrRequests.every((body) => body['qr_payload'] == oldQr), isTrue);
        for (final body
            in qrRequests.where((body) => body.containsKey('apparatus'))) {
          expect(body,
              {'qr_payload': oldQr, 'apparatus': rezka2, 'order_id': orderId});
        }
        if (scenario.startsWith('wip_route_') ||
            scenario == 'empty-authoritative-route' ||
            scenario == 'used' ||
            scenario == 'in-use' ||
            scenario == 'unassigned') {
          expect(qrRequests.where((body) => body.containsKey('apparatus')),
              isEmpty);
        }
        dismissAdminTopNotice();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/progress-qr/lookup')) {
                  final body =
                      (jsonDecode(request.body) as Map).cast<String, dynamic>();
                  qrRequests.add(body);
                  final scoped = body.containsKey('apparatus');
                  if (scoped &&
                      startRequests.isNotEmpty &&
                      scenario == 'resolved-refresh-ambiguous') {
                    return http.Response(
                        '{"error":"wip_route_ambiguous"}', 400);
                  }
                  return http.Response(
                      jsonEncode({
                        'batch': originalBatch,
                        if (scoped) ...{
                          'validated_apparatus': rezka2,
                          'validated_order_id': orderId
                        },
                        if (scenario.startsWith('wip_route_'))
                          'input_route_error': scenario
                        else if (scenario == 'empty-authoritative-route')
                          'input_route': null
                        else if (scenario != 'used' && scenario != 'in-use')
                          'input_route': {
                            'source_stage_node_id': 'laminatsiya_4',
                            'stage_node_id': 'apparatus_6',
                            'consumer_apparatus_ids': [_rezkaId, rezka2],
                            'map_fingerprint': 'edited-map',
                            'remapped': true,
                          },
                      }),
                      200);
                }
                if (request.url.path.endsWith('/queue-action')) {
                  startRequests.add((jsonDecode(request.body) as Map)
                      .cast<String, dynamic>());
                  return http.Response('{"error":"wip_route_changed"}', 400);
                }
                if (request.url.path.endsWith('/sequence')) {
                  return http.Response(jsonEncode(sequenceJson), 200);
                }
                if (request.url.path.endsWith('/wip-batches')) {
                  return http.Response(
                      jsonEncode({
                        'batches': scenario == 'resolved-refresh-omitted'
                            ? []
                            : [originalBatch],
                      }),
                      200);
                }
                if (request.url.path.endsWith('/completed-orders')) {
                  return http.Response('{"completed_orders":[]}', 200);
                }
                if (request.url.path.endsWith('/raw-material-assignments')) {
                  return http.Response('{"assignments":[]}', 200);
                }
                return http.Response('{"error":"not_found"}', 404);
              }));
    });
  }
}
