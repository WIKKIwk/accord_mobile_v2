part of 'admin_production_map_test_screen_test.dart';

void _registerRezkaPrintOptimizationTests() {
  for (final scenario in [
    'local prepared label',
    'local older backend',
    'local mismatched label',
    'local printer failure',
    'save response lost',
    'wifi',
    'committed input conflict',
    'stale cycle',
    'frame resolved as issue',
    'legacy report endpoint',
    'changed frame layout',
    'report domain conflict',
  ]) {
    testWidgets('Rezka optimized print: $scenario', (tester) async {
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
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: order,
        title: 'Optimized Rezka rolls',
        productCode: 'FAST',
        orderNumber: '0024',
        apparatusId: _rezkaId,
        product: 'Optimized Rezka rolls',
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: _rezkaId,
        orderIds: [order],
      );
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: _rezkaId,
        orderId: order,
        action: 'start',
      );
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: _rezkaId,
        orderId: order,
        control: _inProgressQueueControl(
          allowRollComplete: true,
          rezkaOutputKadrCounts: [1, 1, 1, 1],
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
      if (scenario != 'wifi') SessionBluetoothPrinter.remember(printer);
      final events = <String>[];
      final frames = <Map<String, dynamic>>[];
      var nativeAttempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(nativeChannel, (call) async {
        if (call.method == 'pairedPrinters') {
          return [
            {'name': printer.name, 'address': printer.address}
          ];
        }
        expect(call.method, 'printLabel');
        expect(call.arguments, containsPair('epc', '40011890022F235A0000A1B2'));
        expect(call.arguments, containsPair('print_count', 1));
        events.add('native');
        return {
          'ok': scenario != 'local printer failure' || nativeAttempts++ > 0,
        };
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(nativeChannel, null);
        SessionBluetoothPrinter.forget();
      });

      Map<String, dynamic> label(String qr) => {
            'ok': true,
            'epc': qr,
            'label_kind': 'progress',
            'printer': 'xp-p323b',
            'print_mode': 'label',
            'print_count': 1,
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
          if (scenario == 'report domain conflict') {
            return http.Response(
                '{"error":"rezka_output_cycle_conflict"}', 409);
          }
          return http.Response(
              jsonEncode({
                'ok': true,
                'apparatus': _rezkaId,
                'order_id': order,
                'rezka_output_report': {
                  'cycle_id':
                      scenario == 'stale cycle' ? 'another-cycle' : cycle,
                  'frames': frames,
                },
                'kadr_counts': scenario == 'changed frame layout'
                    ? [1, 2, 1, 1]
                    : [1, 1, 1, 1],
                'session_status': 'active',
                'order_control': 'active',
                'epoch': 'print-test-server',
                'rev': 1,
              }),
              200);
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
          events.add('save');
          expect(body['rezka_output_cycle'], cycle);
          expect(body['rezka_record_frame_index'], 1);
          if (scenario != 'wifi') {
            expect(body['print_transport'], 'offline');
            expect(body['driver_url'], 'usb://local');
            expect(body['printer'], 'xp-p323b');
            expect(body['print_mode'], 'label');
          }
          final input = Map<String, dynamic>.from(
            (body['rezka_frames'] as List).single as Map,
          );
          if (scenario == 'committed input conflict') {
            input['gross_qty'] = 99;
          }
          frames.add({
            'frame_index': 1,
            'batch_id': 'optimized-roll-1',
            'qr_payload': '40011890022F235A0000A1B2',
            'input': input,
          });
          if (scenario == 'save response lost') {
            throw http.ClientException('connection closed after commit');
          }
          return http.Response(
            jsonEncode({
              'states': {order: 'in_progress'},
              'session': {
                'session_id': cycle,
                'payload_json': {
                  'rezka_output_cycle': cycle,
                  'rezka_output_report': frames,
                },
              },
              'print': scenario == 'local older backend'
                  ? null
                  : label(scenario == 'local mismatched label'
                      ? '40011890022F235A0000FFFF'
                      : '40011890022F235A0000A1B2'),
            }),
            200,
          );
        }
        expect(request.url.path, endsWith('/progress-qr/reprint'));
        events.add('reprint');
        expect(body['progress_batch_id'], 'optimized-roll-1');
        expect(body['qr_payload'], '40011890022F235A0000A1B2');
        return http.Response(
          jsonEncode({
            'ok': true,
            'batch': {
              'id': body['progress_batch_id'],
              'apparatus': _rezkaId,
              'order_id': order,
              'qr_payload': body['qr_payload'],
            },
            'print': label('40011890022F235A0000A1B2'),
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
                scenario == 'wifi' ? (_) async => 'http://printer.test' : null,
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rezka'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('worker-order-$order')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rulonni yechish'));
        await tester.pumpAndSettle();
        for (final field in {
          'meter': '1000',
          'kg': '20',
          'bobina': '0.5',
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
        await tester.tap(printButton);
        await tester.pumpAndSettle();

        if (scenario == 'local prepared label') {
          expect(events, ['read', 'save', 'native']);
        } else if (scenario == 'legacy report endpoint') {
          expect(events, ['unsupported', 'read', 'save', 'native']);
          events.clear();
          await tester.tap(printButton);
          await tester.pumpAndSettle();
          expect(events, ['read', 'reprint', 'native'],
              reason: 'unsupported report endpoint is probed only once');
        } else if (scenario == 'local older backend' ||
            scenario == 'local mismatched label') {
          expect(events, ['read', 'save', 'reprint', 'native']);
        } else if (scenario == 'wifi') {
          expect(events, ['read', 'save', 'reprint']);
        } else if (scenario == 'local printer failure' ||
            scenario == 'save response lost') {
          expect(
              events,
              scenario == 'local printer failure'
                  ? ['read', 'save', 'native', 'read']
                  : ['read', 'save', 'read']);
          expect(
              find.text(
                  'Saqlandi. Chop etish tasdiqlanmadi — qayta chop etishingiz mumkin.'),
              findsOneWidget);
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
        if (scenario == 'local prepared label' || scenario == 'wifi') {
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
