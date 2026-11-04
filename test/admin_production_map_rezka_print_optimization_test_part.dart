part of 'admin_production_map_test_screen_test.dart';

void _registerRezkaPrintOptimizationTests() {
  for (final scenario in [
    'local prepared label',
    'local duplicate label',
    'atomic duplicate peremotka label',
    'atomic peremotka older server',
    'intermediate duplicate label',
    'intermediate duplicate older backend',
    'intermediate duplicate stale stage',
    'final repeated duplicate label',
    'final repeated duplicate older backend',
    'final repeated duplicate unknown stage',
    'local older backend',
    'local duplicate older backend',
    'local mismatched label',
    'local printer failure',
    'local duplicate printer failure',
    'confirmation after printer failure',
    'confirmation retries temporary sync failure',
    'confirmation rejects changed cycle',
    'confirmation keeps drafts on babina mode conflict',
    'save response lost',
    'wifi',
    'wifi duplicate label',
    'committed input conflict',
    'stale cycle',
    'frame resolved as issue',
    'legacy report endpoint',
    'changed frame layout',
    'report domain conflict',
    'atomic cards skip repeated report reads',
    'atomic babina conflict preserves draft',
  ]) {
    testWidgets('Rezka optimized print: $scenario', (tester) async {
      final confirmRecovery = scenario.startsWith('confirmation ');
      final duplicateLabels = scenario.contains('duplicate');
      final isPeremotka = scenario.contains('peremotka');
      final supportsPeremotka =
          isPeremotka && scenario != 'atomic peremotka older server';
      final intermediate = scenario.startsWith('intermediate');
      final repeated = intermediate || scenario.startsWith('final repeated');
      final unknownStage = scenario.contains('unknown stage');
      final staleStage = scenario.contains('stale stage');
      final isWifi = scenario.startsWith('wifi');
      final isOlderBackend = scenario.contains('older backend');
      final isPrinterFailure = scenario.contains('printer failure');
      final atomicSave = scenario.startsWith('atomic ');
      final bulkModeConflict =
          scenario == 'confirmation keeps drafts on babina mode conflict';
      final modeConflict = bulkModeConflict ||
          scenario == 'atomic babina conflict preserves draft';
      final expectedCount = duplicateLabels && !intermediate ? 2 : 1;
      final requestedCount = staleStage ? 2 : (unknownStage ? 1 : expectedCount);
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Rezka operatori',
        legalName: '',
        ref: 'rezka-optimized-worker',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_rezkaId],
      );
      const order = 'zakaz-rezka-optimized-print';
      const cycle = 'rezka-optimized-cycle';
      var orderMap = _productionOrderMap(
        id: order,
        title: 'Optimized Rezka rolls',
        productCode: 'FAST',
        orderNumber: '0024',
        apparatusId: _rezkaId,
        product: 'Optimized Rezka rolls',
      ).copyWith(
        duplicateRezkaLabels: duplicateLabels,
        includeBobinaInNet: modeConflict,
      );
      await MobileApi.instance.adminSaveProductionMap(orderMap);
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: _rezkaId,
        orderIds: [order],
      );
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: _rezkaId,
        orderId: order,
        action: 'start',
      );
      if (repeated) {
        orderMap = orderMap.copyWith(
          nodes: [
            orderMap.nodes.first,
            orderMap.nodes[1],
            const ProductionMapNode(
              id: 'lamination',
              kind: 'apparatus',
              title: 'Lamination',
              apparatusId: _lamination1Id,
            ),
            const ProductionMapNode(
              id: 'final-rezka',
              kind: 'apparatus',
              title: 'Final Rezka',
              apparatusId: _rezkaId,
            ),
            orderMap.nodes.last,
          ],
          edges: const [
            ProductionMapEdge(from: 'start', to: 'apparatus'),
            ProductionMapEdge(from: 'apparatus', to: 'lamination'),
            ProductionMapEdge(from: 'lamination', to: 'final-rezka'),
            ProductionMapEdge(from: 'final-rezka', to: 'end'),
          ],
        );
        await MobileApi.instance.adminSaveProductionMap(orderMap);
      }
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: _rezkaId,
        orderId: order,
        control: _inProgressQueueControl(
          allowRollComplete: true,
          stageNodeId: repeated && !unknownStage
              ? (intermediate && !staleStage ? 'apparatus' : 'final-rezka')
              : modeConflict ? 'apparatus' : '',
          rezkaOutputKadrCounts: [1, 1, 1, 1],
          // The cached report on first open may predate the server's capability.
          rezkaOutputReport: const AdminRezkaOutputReport(cycleId: cycle),
        ),
      );
      await _usePhoneViewport(tester);

      const nativeChannel = MethodChannel('accord/bluetooth_printer');
      const printer = BluetoothPrinterProfile(
        name: 'XP-P323B',
        address: '00:11:22:33:44:55',
      );
      SessionBluetoothPrinter.forget();
      if (!isWifi) SessionBluetoothPrinter.remember(printer);
      final events = <String>[];
      final frames = <Map<String, dynamic>>[];
      var nativeAttempts = 0;
      var modeConflictSent = false;
      var confirming = false;
      var rejectConfirmationRead = false;
      Map<String, dynamic>? submittedFrames;
      final confirmationReadStarted = Completer<void>();
      final releaseConfirmationRead = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(nativeChannel, (call) async {
        if (call.method == 'pairedPrinters') {
          return [
            {'name': printer.name, 'address': printer.address}
          ];
        }
        expect(call.method, 'printLabel');
        final qr = atomicSave && !isPeremotka && nativeAttempts > 0
            ? '40011890022F235A0000A1B3'
            : '40011890022F235A0000A1B2';
        expect(call.arguments, containsPair('epc', qr));
        expect(call.arguments, containsPair('print_count', expectedCount));
        if (isPeremotka) {
          final lines = (call.arguments as Map)['progress_lines'] as List;
          expect(lines, contains(containsPair('text', 'HOLAT: PEREMOTKA')));
        }
        events.add('native');
        final retry = nativeAttempts++ > 0;
        return {
          'ok': (!isPeremotka && !isPrinterFailure && !confirmRecovery) || retry,
        };
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(nativeChannel, null);
        SessionBluetoothPrinter.forget();
      });

      Map<String, dynamic> label(String qr, {int? count}) => {
            'ok': true,
            'epc': qr,
            'label_kind': 'progress',
            if (isPeremotka) 'item_name': 'PEREMOTKA - Optimized Rezka rolls',
            'printer': 'xp-p323b',
            'print_mode': 'label',
            'print_count': count ?? (isOlderBackend ? 1 : expectedCount),
            'gross_qty': 20,
            'progress_qty': 1000,
            'progress_unit': 'm',
          };
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/rezka-output-report')) {
          if (scenario == 'legacy report endpoint') {
            events.add('unsupported');
            return http.Response('', 404);
          }
          events.add('read');
          if (confirmRecovery && frames.isNotEmpty) {
            if ((!confirming &&
                    scenario != 'confirmation after printer failure') ||
                rejectConfirmationRead) {
              return http.Response('{"error":"store_failed"}', 500);
            }
            if (confirming) {
              if (!confirmationReadStarted.isCompleted) {
                confirmationReadStarted.complete();
              }
              await releaseConfirmationRead.future;
            }
          }
          if (scenario == 'report domain conflict') {
            return http.Response(
                '{"error":"rezka_output_cycle_conflict"}', 409);
          }
          return http.Response(
              jsonEncode({
                'ok': true,
                if (atomicSave) 'atomic_frame_save': true,
                if (supportsPeremotka) 'peremotka_supported': true,
                'apparatus': _rezkaId,
                'order_id': order,
                'rezka_output_report': {
                  'cycle_id': scenario == 'stale cycle' ||
                          (confirming &&
                              scenario == 'confirmation rejects changed cycle')
                      ? 'another-cycle'
                      : cycle,
                  'frames': frames,
                  if (atomicSave || bulkModeConflict)
                    'include_bobina_in_net': modeConflict && !modeConflictSent,
                },
                'kadr_counts': scenario == 'changed frame layout'
                    ? [1, 2, 1, 1]
                    : [1, 1, 1, 1],
                'session_status': 'active',
                'order_control': 'active',
                'epoch': 'print-test-server',
                'rev': 1,
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (request.url.path.endsWith('/order-scan-bootstrap')) {
          events.add('read');
          final snapshot = _rezkaAutofillSnapshot(
            order,
            scenario == 'stale cycle' ? 'another-cycle' : cycle,
            frames,
          );
          return http.Response(
            jsonEncode({
              'ok': true,
              'control_state': {
                'apparatus': _rezkaId,
                'order_id': order,
                'rev': 1,
                'epoch': 'print-test-server',
                'scope': 'rezka-print-scope',
                'control': snapshot['queue_action_controls'][_rezkaId][order],
                'queue_state': 'in_progress',
                'stage_states': {},
                'order_control': 'active',
              },
              'sections': {},
            }),
            200,
          );
        }
        if (request.method == 'GET') {
          events.add('read');
          return http.Response(
              jsonEncode(_rezkaAutofillSnapshot(order, cycle, frames)), 200);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/queue-action')) {
          if (confirmRecovery && body['rezka_record_frame_index'] == null) {
            submittedFrames = body;
            if (bulkModeConflict) {
              return http.Response(
                '{"error":"rezka_bobina_mode_changed","include_bobina_in_net":false}',
                409,
              );
            }
            return http.Response('{"error":"store_failed"}', 500);
          }
          events.add('save');
          expect(body['rezka_output_cycle'], cycle);
          final index = atomicSave ? frames.length + 1 : 1;
          expect(body['rezka_record_frame_index'], index);
          if (atomicSave) {
            expect(body['rezka_expected_epoch'], 'print-test-server');
            expect(body['rezka_expected_kadr_counts'], [1, 1, 1, 1]);
          }
          if (isPeremotka) {
            expect(body['printer'], anyOf(isNull, isEmpty));
          } else if (!isWifi) {
            expect(body['print_transport'], 'offline');
            expect(body['driver_url'], 'usb://local');
            expect(body['printer'], 'xp-p323b');
            expect(body['print_mode'], 'label');
          }
          final input = Map<String, dynamic>.from(
            (body['rezka_frames'] as List).single as Map,
          );
          if (isPeremotka) {
            expect(input, containsPair('peremotka_reason', 'Notekis o‘ralgan'));
          }
          if (modeConflict && index == 2 && !modeConflictSent) {
            expect(input['bobina_kg'], isNull);
            modeConflictSent = true;
            return http.Response(
              '{"error":"rezka_bobina_mode_changed","include_bobina_in_net":false}',
              409,
            );
          }
          if (scenario == 'committed input conflict') {
            input['gross_qty'] = 99;
          }
          final qr = index == 1
              ? '40011890022F235A0000A1B2'
              : '40011890022F235A0000A1B3';
          frames.add({
            'frame_index': index,
            'batch_id': 'optimized-roll-$index',
            'qr_payload': qr,
            'input': input,
          });
          if (scenario == 'save response lost') {
            throw http.ClientException('connection closed after commit');
          }
          return http.Response(
            jsonEncode({
              'states': {order: 'in_progress'},
              if (atomicSave)
                'progress_batch': {
                  'batch_id': 'optimized-roll-$index',
                  'apparatus': _rezkaId,
                  'order_id': order,
                  'qr_payload': qr,
                  'payload_json': {
                    'rezka_output_kind': 'frame',
                    if (modeConflict && !modeConflictSent)
                      'include_bobina_in_net': true,
                  },
                },
              'session': {
                'session_id': cycle,
                'payload_json': {
                  'rezka_output_cycle': cycle,
                  'rezka_output_report': frames,
                },
              },
              'print': isOlderBackend
                  ? null
                  : label(scenario == 'local mismatched label'
                      ? '40011890022F235A0000FFFF'
                      : qr),
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        expect(request.url.path, endsWith('/progress-qr/reprint'));
        events.add('reprint');
        expect(body['progress_batch_id'], 'optimized-roll-1');
        expect(body['qr_payload'], '40011890022F235A0000A1B2');
        expect(body['print_count'], requestedCount);
        expect(body['automatic_rezka_labels'], isTrue);
        return http.Response(
          jsonEncode({
            'ok': true,
            'batch': {
              'id': body['progress_batch_id'],
              'apparatus': _rezkaId,
              'order_id': order,
              'qr_payload': body['qr_payload'],
            },
            'print': label('40011890022F235A0000A1B2', count: expectedCount),
          }),
          200,
        );
      });

      await http.runWithClient(() async {
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
          home: AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
            progressDriverUrlPicker:
                isWifi ? (_) async => 'http://printer.test' : null,
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rezka'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('worker-order-$order')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rulonni yechish'));
        await tester.pumpAndSettle();
        if (repeated && !staleStage) {
          expect(
            find.text('Har bir rulon uchun 2 ta yorliq: bobina ichi va rulon ustiga.'),
            intermediate || unknownStage ? findsNothing : findsOneWidget,
          );
        }
        for (final field in {
          'meter': '1000',
          'kg': '20',
          if (!modeConflict) 'bobina': '0.5',
          'diameter': '45',
        }.entries) {
          final target = find.byKey(ValueKey('rezka-frame-0-${field.key}'));
          await tester.ensureVisible(target);
          await tester.enterText(target, field.value);
          await tester.pumpAndSettle();
        }
        if (scenario == 'frame resolved as issue') {
          frames.add({
            'frame_index': 1,
            'batch_id': '',
            'qr_payload': '',
            'input': {'issue_note': 'Another device resolved this frame'},
          });
        }
        await TestModeController.instance.setEnabled(false);
        events.clear();
        final printButton = find.byKey(const ValueKey('rezka-frame-0-print'));
        await tester.ensureVisible(printButton);
        if (isPeremotka) {
          await tester.longPress(printButton);
          await tester.pumpAndSettle();
          expect(find.text('1-rulonni peremotkaga qoldiraymi?'), findsOneWidget);
          await tester.enterText(
            find.byKey(const ValueKey('rezka-peremotka-reason')),
            'Notekis o‘ralgan',
          );
          await tester.tap(find.byKey(const ValueKey('rezka-peremotka-confirm')));
          await tester.pumpAndSettle();
          if (!supportsPeremotka) {
            expect(events, ['read']);
            expect(frames, isEmpty);
            expect(
              find.text('Peremotka uchun serverni yangilash kerak.'),
              findsOneWidget,
            );
            await tester.pumpWidget(const SizedBox.shrink());
            return;
          }
          expect(events, ['read', 'save', 'reprint', 'native', 'read']);
          expect(find.text('Peremotka · Notekis o‘ralgan'), findsOneWidget);
          expect(frames, hasLength(1));
          events.clear();
          await tester.tap(printButton);
          await tester.pumpAndSettle();
          expect(events, ['read', 'reprint', 'native']);
          expect(frames, hasLength(1));
          await tester.pumpWidget(const SizedBox.shrink());
          return;
        }
        await tester.tap(printButton);
        await tester.pumpAndSettle();

        if (atomicSave) {
          expect(events, ['read', 'save', 'native']);
          events.clear();
          final secondPrint = find.byKey(const ValueKey('rezka-frame-1-print'));
          await tester.ensureVisible(secondPrint);
          await tester.tap(secondPrint);
          await tester.pumpAndSettle();
          if (modeConflict) {
            expect(events, ['save']);
            expect(frames, hasLength(1));
            expect(find.byKey(const ValueKey('rezka-frame-0-bobina')), findsNothing);
            for (final field in {'meter': 1000, 'kg': 20, 'diameter': 45}.entries) {
              final input = tester.widget<TextFormField>(
                find.byKey(ValueKey('rezka-frame-1-${field.key}')),
              );
              expect(double.parse(input.controller!.text), field.value);
            }
            final tare = find.byKey(const ValueKey('rezka-frame-1-bobina'));
            await tester.ensureVisible(tare);
            await tester.enterText(tare, '0.5');
            await tester.ensureVisible(secondPrint);
            await tester.tap(secondPrint);
            await tester.pumpAndSettle();
            expect(frames.last['input'], containsPair('bobina_kg', 0.5));
          }
          expect(events, modeConflict ? ['save', 'save', 'native'] : ['save', 'native']);
          expect(frames, hasLength(2));
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          return;
        }

        if (confirmRecovery) {
          final confirm = find.widgetWithText(FilledButton, 'Tasdiqlash');
          void expectFilledRolls() {
            for (var index = 0; index < 4; index++) {
              for (final field in [
                'meter',
                'kg',
                if (!modeConflict) 'bobina',
                'diameter',
              ]) {
                expect(
                  tester
                      .widget<TextFormField>(find.byKey(
                        ValueKey('rezka-frame-$index-$field'),
                      ))
                      .controller!
                      .text,
                  isNotEmpty,
                );
              }
            }
          }

          expectFilledRolls();
          expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
          confirming = true;
          if (scenario == 'confirmation retries temporary sync failure') {
            rejectConfirmationRead = true;
            await tester.tap(confirm);
            await tester.pumpAndSettle();
            expect(submittedFrames, isNull);
            expectFilledRolls();
            expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
            expect(
                find.text(AppLocalizations.of(tester.element(confirm))
                    .productionText('worker.error.sync')),
                findsOneWidget);
            rejectConfirmationRead = false;
          }
          await tester.tap(confirm);
          for (var attempt = 0;
              attempt < 50 && !confirmationReadStarted.isCompleted;
              attempt++) {
            await tester.pump(const Duration(milliseconds: 25));
          }
          expect(confirmationReadStarted.isCompleted, isTrue);
          await tester.pump();
          expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
          expect(tester.widget<IconButton>(printButton).onPressed, isNull);
          expect(
              tester
                  .widget<OutlinedButton>(find.widgetWithText(
                    OutlinedButton,
                    'Bekor qilish',
                  ))
                  .onPressed,
              isNull);
          releaseConfirmationRead.complete();
          await tester.pumpAndSettle();
          if (scenario == 'confirmation rejects changed cycle') {
            expect(submittedFrames, isNull);
            expectFilledRolls();
            expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
          } else if (bulkModeConflict) {
            expect(submittedFrames, isNotNull);
            expectFilledRolls();
            expect(find.byKey(const ValueKey('rezka-frame-0-bobina')), findsNothing);
            final tare = tester.widget<TextFormField>(
              find.byKey(const ValueKey('rezka-frame-1-bobina')),
            );
            expect(tare.enabled, isTrue);
            expect(tare.controller!.text, isEmpty);
          } else {
            expect(submittedFrames, isNotNull);
            expect(submittedFrames!['rezka_output_cycle'], cycle);
            expect(submittedFrames!['rezka_record_frame_index'], isNull);
            final inputs = submittedFrames!['rezka_frames'] as List;
            expect(inputs, hasLength(4));
            for (final input in inputs) {
              expect(input, containsPair('produced_qty', 1000));
              expect(input, containsPair('gross_qty', 20));
              expect(input, containsPair('bobina_kg', 0.5));
              expect(input, containsPair('diameter', 45));
            }
            expect(
                find.byKey(const ValueKey('rezka-frame-1-kg')), findsNothing);
          }
          expect(frames, hasLength(1),
              reason: 'The saved roll must not duplicate');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          return;
        }

        if (scenario == 'local prepared label' ||
            scenario == 'local duplicate label' ||
            scenario == 'intermediate duplicate label' ||
            scenario == 'final repeated duplicate label') {
          expect(events, ['read', 'save', 'native']);
        } else if (scenario == 'legacy report endpoint') {
          expect(events, ['unsupported', 'read', 'save', 'native']);
          events.clear();
          await tester.tap(printButton);
          await tester.pumpAndSettle();
          expect(events, ['read', 'reprint', 'native'],
              reason: 'unsupported report endpoint is probed only once');
        } else if (isOlderBackend || unknownStage || staleStage ||
            scenario == 'local mismatched label') {
          expect(events, ['read', 'save', 'reprint', 'native']);
        } else if (isWifi) {
          expect(events, ['read', 'save', 'reprint']);
        } else if (isPrinterFailure ||
            scenario == 'save response lost') {
          expect(
              events,
              isPrinterFailure
                  ? ['read', 'save', 'native', 'read']
                  : ['read', 'save', 'read']);
          expect(
              find.text(
                  'Saqlandi. Chop etish tasdiqlanmadi — qayta chop etishingiz mumkin.'),
              findsOneWidget);
          for (var index = 0; index < 4; index++) {
            for (final field in ['meter', 'kg', 'bobina', 'diameter']) {
              expect(
                tester
                    .widget<TextFormField>(find.byKey(
                      ValueKey('rezka-frame-$index-$field'),
                    ))
                    .controller!
                    .text,
                isNotEmpty,
              );
            }
          }
          expect(
            tester
                .widget<FilledButton>(find.widgetWithText(
                  FilledButton,
                  'Tasdiqlash',
                ))
                .onPressed,
            isNotNull,
            reason: 'Filled rolls must be confirmable without reopening',
          );
          events.clear();
          await tester.tap(printButton);
          await tester.pumpAndSettle();
          expect(events, ['read', 'reprint', 'native']);
          expect(frames, hasLength(1));
        } else if (scenario == 'committed input conflict') {
          expect(events, ['read', 'save', 'read']);
          expect(tester.widget<IconButton>(printButton).onPressed, isNull);
        } else {
          expect(events, ['read', 'read']);
          expect(tester.widget<IconButton>(printButton).onPressed, isNull);
        }
        if (scenario == 'local prepared label' || isWifi) {
          // Reopening keeps the committed card locked without a post-save read.
          await tester.tap(find.widgetWithText(OutlinedButton, 'Bekor qilish'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Rulonni yechish'));
          await tester.pumpAndSettle();
          final weight = tester.widget<TextFormField>(
            find.byKey(const ValueKey('rezka-frame-0-kg')),
          );
          expect(weight.enabled, isFalse);
          expect(double.parse(weight.controller!.text), 20);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }
}
