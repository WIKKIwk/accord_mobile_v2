part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerQrErrorTests() {
  const orderId = 'zakaz-frozen-wip';
  const qr = 'QR-BOSMA-WAITING-WIP';
  final l10n = AppLocalizations(const Locale('uz'));
  final scenarios = <String, String>{
    'frozen-lamination': 'worker.freeze.named',
    'frozen-cold-glue': 'worker.freeze.named',
    'frozen-rezka': 'worker.freeze.named',
    'frozen-before-route-error': 'worker.freeze.named',
    'frozen-server': 'worker.freeze.named',
    'frozen-scoped-server': 'worker.freeze.named',
    'frozen-legacy-error': 'worker.freeze.named',
    'freeze-requested': 'worker.qr.freeze_requested',
    'frozen-after-lookup': 'worker.freeze.named',
    'frozen-after-lookup-route-error': 'worker.freeze.named',
    'not-found': 'worker.qr.not_found',
    'not-accepted': 'worker.qr.not_accepted',
    'no-assignment': 'worker.qr.no_assignment',
    'catalog-missing': 'worker.qr.catalog_missing',
    'timeout': 'worker.error.network_timeout',
    'connection': 'worker.qr.connection',
    'unauthorized': 'worker.qr.session_expired',
    'forbidden': 'worker.qr.forbidden',
    'server': 'worker.qr.server',
    'invalid-json': 'worker.qr.invalid_response',
    'invalid-batch': 'worker.qr.invalid_response',
    'incomplete-batch': 'worker.qr.invalid_response',
    'unconfirmed': 'worker.qr.invalid_response',
    'unknown-error': 'worker.qr.lookup_failed',
    'future-stage-visible': 'worker.qr.stage_not_reached',
    'future-stage-hidden': 'worker.qr.stage_not_reached',
    'future-stage-remapped': 'worker.qr.stage_not_reached',
    'passed-stage-hidden': 'worker.qr.route_unassigned',
    'missing-map': 'worker.qr.order_unavailable',
    'map-read-failed': 'worker.qr.server',
  };
  for (final scenario in scenarios.entries) {
    testWidgets('worker QR precise notice: ${scenario.key}', (tester) async {
      final futureStage = scenario.key.startsWith('future-stage');
      final foreignStage = futureStage || scenario.key == 'passed-stage-hidden' ||
          scenario.key == 'missing-map' || scenario.key == 'map-read-failed';
      final hiddenOrder = foreignStage && scenario.key != 'future-stage-visible';
      await TestModeController.instance.setEnabled(false);
      final consumer = scenario.key == 'frozen-cold-glue'
          ? _coldGlueId
          : scenario.key == 'frozen-rezka'
              ? _rezkaId
              : _lamination1Id;
      AppSession.instance.profile = SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Worker',
        legalName: '',
        ref: 'qr-notice-worker',
        phone: '',
        avatarUrl: '',
        capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: scenario.key == 'no-assignment' ? [] : [consumer],
      );
      final map = ProductionMapDefinition.fromJson({
        'id': orderId,
        'order_number': '0042',
        'title': 'Frozen WIP',
        'product_code': 'FROZEN-WIP',
        'nodes': [
          {'id': 'start', 'kind': 'start', 'title': 'Start'},
          {
            'id': 'bosma',
            'kind': 'apparatus',
            'title': 'Bosma 9',
            'apparatus_id': _print9Id
          },
          {
            'id': 'lamination',
            'kind': 'apparatus',
            'title': 'Laminatsiya 1',
            'apparatus_id': scenario.key == 'frozen-cold-glue'
                ? _coldGlueId
                : _lamination1Id
          },
          {
            'id': 'rezka',
            'kind': 'apparatus',
            'title': 'Rezka',
            'apparatus_id': _rezkaId
          },
          {'id': 'end', 'kind': 'end', 'title': 'End'},
        ],
        'edges': [
          {'from': 'start', 'to': 'bosma'},
          if (futureStage) ...[
            {'from': 'bosma', 'to': 'rezka'},
            {'from': 'rezka', 'to': 'lamination'},
            {'from': 'lamination', 'to': 'end'},
          ] else ...[
            {'from': 'bosma', 'to': 'lamination'},
            {'from': 'lamination', 'to': 'rezka'},
            {'from': 'rezka', 'to': 'end'},
          ],
        ],
      });
      var scanned = false;
      var scopedLookups = 0;
      var legacyControlReads = 0;
      var mapReads = 0;
      var workMutations = 0;
      final qrRequests = <Map<String, dynamic>>[];
      AdminOrderControlState controlState() {
        if (scenario.key == 'frozen-scoped-server') {
          return AdminOrderControlState.active;
        }
        if (scenario.key == 'freeze-requested') {
          return AdminOrderControlState.freezeRequested;
        }
        if (scenario.key.startsWith('frozen-') &&
            (!scenario.key.startsWith('frozen-after-lookup') || scanned)) {
          return AdminOrderControlState.frozen;
        }
        return AdminOrderControlState.active;
      }

      final saved = ProductionMapSaved.fromJson(
          {'map': map.toJson(), 'program': <String, dynamic>{}});
      AdminApparatusQueueSnapshot snapshot() => AdminApparatusQueueSnapshot(
            revision: scanned ? 2 : 1, epoch: 'qr-errors',
            maps: hiddenOrder ? [] : [saved],
            sequences: {
              consumer: hiddenOrder ? [] : [orderId]
            },
            visibleOrderIds: {
              consumer: hiddenOrder ? [] : [orderId]
            },
            queueStates: {
              if (!hiddenOrder) _print9Id: {
                orderId: controlState().isFrozen ? 'frozen' : 'in_progress'
              }
            },
            queuePolicies: const {},
            orderControls: {if (!hiddenOrder) orderId: controlState()},
            // There is deliberately no downstream frozen/action-control fixture.
            queueActionControls: const {},
          );
      Map<String, dynamic> sequenceJson() => {
            'rev': scanned ? 2 : 1,
            'epoch': 'qr-errors',
            'maps': [
              if (!hiddenOrder) {'map': map.toJson(), 'program': {}}
            ],
            'sequences': {
              consumer: hiddenOrder ? [] : [orderId]
            },
            'visible_order_ids': {
              consumer: hiddenOrder ? [] : [orderId]
            },
            'queue_states': {
              if (!hiddenOrder) _print9Id: {
                orderId: controlState().isFrozen ? 'frozen' : 'in_progress'
              }
            },
            'queue_policies': [],
            'queue_action_controls': {},
            'order_controls': {
              if (!hiddenOrder) orderId: {'state': controlState().apiValue}
            },
            'frozen_orders_by_apparatus': {},
            'order_statuses': {},
          };
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
          onGenerateRoute: (_) => MaterialPageRoute<String>(
            builder: (context) => Scaffold(
                body: TextButton(
              key: const ValueKey('return-notice-qr'),
              onPressed: () => Navigator.of(context).pop(qr),
              child: const Text('Scan WIP'),
            )),
          ),
          home: AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
            queueSnapshotLoader: () async => snapshot(),
            apparatusLoader: () async => [
              const AdminApparatus(
                  id: _print9Id, name: 'Bosma 9', operation: 'print'),
              if (scenario.key != 'catalog-missing')
                AdminApparatus(
                    id: consumer,
                    name: foreignStage ? 'Laminatsiya 1' : 'Worker machine',
                    operation: 'laminate'),
              if (foreignStage)
                const AdminApparatus(id: _rezkaId, name: 'Rezka', operation: 'cut'),
            ],
            liveEventsLoader: () => const Stream.empty(),
          ),
        ));
        await tester.pumpAndSettle();
        final scan = tester
            .widget<AparatchiDock>(find.byType(AparatchiDock))
            .onQrScanRequested!();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('return-notice-qr')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await scan;
        await tester.pump(const Duration(milliseconds: 300));
        final message = l10n.productionText(scenario.value,
            values: const {'order': 'Frozen WIP', 'destination': 'Rezka',
              'current': 'Laminatsiya 1'});
        expect(scenario.key == 'passed-stage-hidden'
            ? find.textContaining(message) : find.text(message), findsOneWidget,
            reason: tester
                .widgetList<Text>(find.byType(Text))
                .map((text) => text.data)
                .toList()
                .toString());
        if (futureStage || scenario.key == 'passed-stage-hidden') {
          expect(find.text(l10n.productionText('worker.qr.order_unavailable')),
              findsNothing);
        }
        if (scenario.key == 'passed-stage-hidden') {
          expect(find.textContaining('hali sizning bosqichingizga yetib kelmagan'),
              findsNothing);
        }
        expect(mapReads, hiddenOrder ? 1 : 0);
        expect(workMutations, 0);
        expect(find.text(l10n.productionText('worker.error.assigned_machine')),
            findsNothing);
        expect(
            find.byWidgetPredicate((widget) =>
                widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet'),
            findsNothing);
        expect(scopedLookups,
            ['unconfirmed', 'frozen-scoped-server'].contains(scenario.key) ? 1 : 0);
        expect(qrRequests, isNotEmpty);
        for (final body in qrRequests) {
          expect(body['require_active_order'],
              scenario.key == 'frozen-legacy-error' && body == qrRequests.last
                  ? null : true);
          expect(body['qr_payload'], qr);
        }
        if (scenario.key.startsWith('frozen-') &&
                !scenario.key.startsWith('frozen-after-lookup') &&
                scenario.key != 'frozen-server' &&
                scenario.key != 'frozen-scoped-server' &&
                scenario.key != 'frozen-legacy-error' ||
            scenario.key == 'freeze-requested') {
          expect(legacyControlReads, 1);
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
                  if (scoped) scopedLookups++;
                  scanned = true;
                  if (scenario.key == 'frozen-server' ||
                      (scenario.key == 'frozen-scoped-server' && scoped) ||
                      (scenario.key == 'frozen-legacy-error' &&
                          body['require_active_order'] == true)) {
                    return http.Response(jsonEncode({
                      'error': 'order_frozen',
                      if (scenario.key != 'frozen-legacy-error')
                        'order_title': 'Frozen WIP',
                    }), 409);
                  }
                  switch (scenario.key) {
                    case 'timeout':
                      throw TimeoutException('QR timeout');
                    case 'connection':
                      throw http.ClientException('Connection interrupted');
                    case 'not-found':
                      return http.Response(
                          '{"error":"progress_batch_not_found"}', 400);
                    case 'not-accepted':
                      return http.Response(
                          '{"error":"progress_batch_not_accepted"}', 400);
                    case 'unauthorized':
                      return http.Response('', 401);
                    case 'forbidden':
                      return http.Response('', 403);
                    case 'server':
                      return http.Response('Gateway failure', 502);
                    case 'invalid-json':
                      return http.Response('not JSON', 200);
                    case 'invalid-batch':
                      return http.Response('{"batch":null}', 200);
                    case 'incomplete-batch':
                      return http.Response(
                          '{"active_order_validated":true,"batch":{}}', 200);
                    case 'unknown-error':
                      return http.Response(
                          '{"error":"undocumented_error"}', 400);
                  }
                  return http.Response(
                      jsonEncode({
                        // Simulate old servers for global-freeze precedence tests.
                        if (!scenario.key.startsWith('frozen-') &&
                                scenario.key != 'freeze-requested' ||
                            scenario.key.startsWith('frozen-after-lookup') ||
                            scenario.key == 'frozen-scoped-server')
                          'active_order_validated': true,
                        'batch': {
                          'batch_id': 'bosma-output',
                          'order_id': orderId,
                          'apparatus':
                              consumer == _rezkaId || scenario.key == 'passed-stage-hidden'
                                  ? _lamination1Id : _print9Id,
                          'next_apparatus': foreignStage &&
                                  scenario.key != 'future-stage-remapped'
                              ? _rezkaId : consumer,
                          'qr_payload': qr,
                          'wip_status': 'waiting',
                          'payload_json': {
                            'production_stage_node_id':
                                consumer == _rezkaId ? 'lamination' : 'bosma',
                            'next_stage_node_id':
                                scenario.key == 'future-stage-remapped'
                                    ? 'removed-stage'
                                    : consumer == _rezkaId || foreignStage
                                        ? 'rezka' : 'lamination'
                          }
                        },
                        if (scenario.key == 'frozen-before-route-error' ||
                            scenario.key == 'frozen-after-lookup-route-error')
                          'input_route_error':
                              'wip_route_destination_unresolved'
                        else
                          'input_route': {
                            'source_stage_node_id':
                                consumer == _rezkaId || scenario.key == 'passed-stage-hidden'
                                    ? 'lamination' : 'bosma',
                            'stage_node_id':
                                consumer == _rezkaId || foreignStage ? 'rezka' : 'lamination',
                            'consumer_apparatus_ids': [foreignStage ? _rezkaId : consumer],
                            'map_fingerprint': 'qr-errors-map',
                            'remapped': scenario.key == 'future-stage-remapped',
                          },
                      }),
                      200);
                }
                if (request.url.path.endsWith('/queue-action')) workMutations++;
                if (request.url.path.endsWith('/production-maps') &&
                    request.url.queryParameters['id'] == orderId) {
                  mapReads++;
                  if (scenario.key == 'missing-map') {
                    return http.Response('{"error":"map_not_found"}', 404);
                  }
                  if (scenario.key == 'map-read-failed') {
                    return http.Response('{"error":"server_error"}', 503);
                  }
                  return http.Response(
                      jsonEncode({'map': map.toJson(), 'program': {}}), 200);
                }
                if (request.url.path.endsWith('/sequence')) {
                  legacyControlReads++;
                  return http.Response(jsonEncode(sequenceJson()), 200);
                }
                if (request.url.path.endsWith('/completed-orders')) {
                  return http.Response('{"completed_orders":[]}', 200);
                }
                if (request.url.path
                    .endsWith('/completion-request-decisions')) {
                  return http.Response('{"decisions":[]}', 200);
                }
                return http.Response('{}', 200);
              }));
    });
  }
}
