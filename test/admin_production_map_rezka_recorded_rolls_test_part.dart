part of 'admin_production_map_test_screen_test.dart';

void _registerRezkaRecordedRollTests() {
  for (final savedIssue in [false, true]) {
    testWidgets(
        'recorded Rezka roll ${savedIssue ? "issue" : "printed"} stays locked in pause and completion dialogs',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      await AppSession.instance.setSession(
          token: 'recorded-rolls-worker',
          profile: const SessionProfile(
            role: UserRole.aparatchi,
            displayName: 'Rezka operatori',
            legalName: '',
            ref: 'recorded-rolls-worker',
            phone: '',
            avatarUrl: '',
            capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
            assignedApparatus: [_rezkaId],
          ));
      const order = 'zakaz-rezka-recorded-dialog';
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: order,
        title: 'Recorded Rezka rolls',
        productCode: 'RZD-R',
        orderNumber: '0021',
        apparatusId: _rezkaId,
        product: 'Recorded Rezka rolls',
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _rezkaId, orderIds: [order]);
      await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _rezkaId, orderId: order, action: 'start');
      final report = AdminRezkaOutputReport.tryFromJson({
        'cycle_id': 'run-output-cycle-1',
        'frames': [
          {
            'frame_index': 1,
            'batch_id': savedIssue ? '' : 'recorded-roll-1',
            'qr_payload': savedIssue ? '' : 'QR-recorded-1',
            'input': savedIssue
                ? {'issue_note': 'Kadr yirtilgan'}
                : {
                    'produced_qty': 125.0,
                    'gross_qty': 12.0,
                    'bobina_kg': 0.5,
                    'diameter': 45.0
                  }
          }
        ],
      })!;
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: _rezkaId,
        orderId: order,
        control: _inProgressQueueControl(
          allowRollComplete: true,
          rezkaOutputKadrCounts: [1, 2],
          rezkaOutputReport: report,
          completeRequiresRezkaTotalWasteOnly: true,
        ),
      );
      await _usePhoneViewport(tester);
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
            progressDriverUrlPicker: (_) async => 'http://printer.test'),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rezka-active-paddon')), findsOneWidget);
      await tester.tap(find.text('Rezka'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('worker-order-$order')));
      await tester.pumpAndSettle();
      for (final action in ['Rulonni yechish', 'Tugatish', 'Rulonni yechish']) {
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(
            find.byKey(const ValueKey('rezka-frame-1-meter')), findsOneWidget);
        expect(
            find.text(savedIssue
                ? '0 ta rulon · 1 ta muammo · 1 ta kutilmoqda'
                : '1/2 rulon saqlandi · 1 ta kutilmoqda'),
            findsOneWidget);
        if (savedIssue) expect(find.text('Kadr yirtilgan'), findsOneWidget);
        for (final field in ['meter', 'kg', 'bobina', 'diameter']) {
          final saved = tester.widget<TextFormField>(
              find.byKey(ValueKey('rezka-frame-0-$field')));
          final pending = tester.widget<TextFormField>(
              find.byKey(ValueKey('rezka-frame-1-$field')));
          expect(saved.enabled, isFalse);
          expect(saved.controller!.text, savedIssue ? isEmpty : isNotEmpty);
          expect(pending.enabled, isTrue);
          expect(pending.controller!.text,
              savedIssue ? isEmpty : saved.controller!.text);
        }
        expect(
            find.byKey(const ValueKey('rezka-frame-0-print')), findsOneWidget);
        expect(
            find.byKey(const ValueKey('rezka-frame-1-print')), findsOneWidget);
        expect(
            tester
                .widget<IconButton>(
                    find.byKey(const ValueKey('rezka-frame-0-issue')))
                .onPressed,
            isNull);
        expect(
            tester
                .widget<IconButton>(
                    find.byKey(const ValueKey('rezka-frame-0-print')))
                .onPressed,
            savedIssue ? isNull : isNotNull);
        await tester
            .ensureVisible(find.byKey(const ValueKey('rezka-frame-1-issue')));
        await tester.tap(find.byKey(const ValueKey('rezka-frame-1-issue')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('rezka-frame-issue-note')),
            findsOneWidget);
        await tester
            .tap(find.byKey(const ValueKey('rezka-frame-issue-confirm')));
        await tester.pumpAndSettle();
        expect(find.text('Muammo izohini kiriting.'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Bekor qilish').last);
        await tester.pumpAndSettle();
        // Validate only the selected roll; incomplete siblings must stay editable.
        await tester.enterText(
            find.byKey(const ValueKey('rezka-frame-1-kg')), '');
        await tester
            .ensureVisible(find.byKey(const ValueKey('rezka-frame-1-print')));
        await tester.tap(find.byKey(const ValueKey('rezka-frame-1-print')));
        await tester.pumpAndSettle();
        expect(
            find.text(
                'Shu rulonning metraj, og‘irlik, babina va diametrini kiriting.'),
            findsOneWidget);
        expect(
            tester
                .widget<TextFormField>(
                    find.byKey(const ValueKey('rezka-frame-1-meter')))
                .enabled,
            isTrue);
        await tester.tap(find.text('Bekor qilish'));
        await tester.pumpAndSettle();
      }
      if (savedIssue) {
        expect(tester.takeException(), isNull);
        return;
      }
      await tester.tap(find.text('Rulonni yechish'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rezka-frame-0-print')));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Saqlandi. Chop etish tasdiqlanmadi — qayta chop etishingiz mumkin.'),
          findsOneWidget);
      expect(
          tester
              .widget<TextFormField>(
                  find.byKey(const ValueKey('rezka-frame-0-meter')))
              .enabled,
          isFalse);
      expect(
          tester
              .widget<TextFormField>(
                  find.byKey(const ValueKey('rezka-frame-1-meter')))
              .enabled,
          isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Rezka print autofills drafts and weight edits keep first ratio',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Rezka operatori',
      legalName: '',
      ref: 'rezka-autofill-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [_rezkaId],
    );
    const order = 'zakaz-rezka-autofill';
    const cycle = 'rezka-autofill-cycle';
    await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
      id: order,
      title: 'Autofill rolls',
      productCode: 'AUTO',
      orderNumber: '0022',
      apparatusId: _rezkaId,
      product: 'Autofill rolls',
    ));
    await MobileApi.instance
        .adminSaveProductionMapSequence(apparatus: _rezkaId, orderIds: [order]);
    await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: _rezkaId, orderId: order, action: 'start');
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
    final frames = <Map<String, dynamic>>[];
    final saves = <Map<String, dynamic>>[];
    var printCount = 0;
    var failSave = true;
    var failPrint = true;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
            jsonEncode(_rezkaAutofillSnapshot(order, cycle, frames)), 200);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path.endsWith('/queue-action')) {
        saves.add(body);
        if (failSave) return http.Response('{"error":"store_failed"}', 500);
        final index = body['rezka_record_frame_index'] as int;
        frames.add({
          'frame_index': index,
          'batch_id': 'saved-roll-$index',
          'qr_payload': 'QR-$index',
          'input': (body['rezka_frames'] as List).single,
        });
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
            }),
            200);
      }
      expect(request.url.path, endsWith('/progress-qr/reprint'));
      printCount++;
      if (failPrint) return http.Response('{"error":"print_failed"}', 500);
      return http.Response(
          jsonEncode({
            'ok': true,
            'batch': {
              'id': body['progress_batch_id'],
              'qr_payload': body['qr_payload'],
            },
          }),
          200);
    });

    Finder field(int index, String name) =>
        find.byKey(ValueKey('rezka-frame-$index-$name'));
    String value(int index, String name) =>
        tester.widget<TextFormField>(field(index, name)).controller!.text;
    Future<void> edit(int index, String name, String text) async {
      await tester.ensureVisible(field(index, name));
      await tester.enterText(field(index, name), text);
      await tester.pumpAndSettle();
    }

    Future<void> printRoll(int index) async {
      final button = find.byKey(ValueKey('rezka-frame-$index-print'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

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
          progressDriverUrlPicker: (_) async => 'http://printer.test',
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rezka'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('worker-order-$order')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rulonni yechish'));
      await tester.pumpAndSettle();
      await edit(0, 'meter', '1000');
      await edit(0, 'kg', '20');
      await edit(0, 'bobina', '0.5');
      await edit(0, 'diameter', '45');
      await edit(3, 'meter', '77');
      await edit(3, 'kg', '99');
      expect(value(1, 'meter'), isEmpty);
      expect(value(2, 'kg'), isEmpty);
      await TestModeController.instance.setEnabled(false);

      // Failed saves cannot supply a reference or fill other rolls.
      await printRoll(0);
      expect(frames, isEmpty);
      expect(value(1, 'meter'), isEmpty);
      expect(value(0, 'kg'), '20');
      failSave = false;
      await printRoll(0);
      expect(frames, hasLength(1));
      for (final index in [1, 2]) {
        for (final name in ['meter', 'kg', 'bobina', 'diameter']) {
          expect(value(index, name), value(0, name));
        }
      }
      expect(value(3, 'meter'), '77');
      expect(value(3, 'kg'), '99');
      expect(saves, hasLength(2));
      expect(printCount, 1);
      expect(tester.widget<TextFormField>(field(0, 'kg')).enabled, isFalse);

      await edit(1, 'kg', '18');
      expect(value(1, 'meter'), '900');
      expect(double.parse(value(2, 'meter')), 1000);
      expect(double.parse(value(0, 'kg')), 20);
      await tester.tapAt(const Offset(2, 2));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(value(1, 'kg'), '18');
      expect(value(1, 'meter'), '900');

      // Retrying only prints the saved QR and must preserve draft changes.
      failPrint = false;
      await printRoll(0);
      expect(saves, hasLength(2));
      expect(printCount, 2);
      expect(value(1, 'meter'), '900');
      await edit(1, 'meter', '800');
      await printRoll(1);
      expect(frames, hasLength(2));
      expect(frames.last['input']['produced_qty'], 800);
      expect(frames.last['input']['gross_qty'], 18);
      await edit(2, 'kg', '22');
      expect(value(2, 'meter'), '1100');
      await edit(2, 'kg', '18,5');
      expect(value(2, 'meter'), '925');
      await edit(2, 'kg', '');
      expect(value(2, 'meter'), isEmpty);
      await edit(2, 'kg', '0');
      expect(value(2, 'meter'), isEmpty);
      await edit(2, 'kg', '20');
      expect(value(2, 'meter'), '1000');
      expect(saves, hasLength(3));
      expect(printCount, 3);

      // Reopening uses the saved first roll, not the later edited roll.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Bekor qilish'));
      await tester.pumpAndSettle();
      expect(field(2, 'kg'), findsNothing);
      await tester.tap(find.text('Rulonni yechish'));
      await tester.pumpAndSettle();
      expect(double.parse(value(1, 'meter')), 800);
      expect(tester.widget<TextFormField>(field(1, 'kg')).enabled, isFalse);
      await edit(2, 'kg', '22');
      expect(value(2, 'meter'), '1100');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}

Map<String, dynamic> _rezkaAutofillSnapshot(
        String order, String cycle, List<Map<String, dynamic>> frames) =>
    {
      'sequences': {
        _rezkaId: [order]
      },
      'visible_order_ids': {
        _rezkaId: [order]
      },
      'queue_states': {
        _rezkaId: {order: 'in_progress'}
      },
      'stage_states': {},
      'queue_policies': [],
      'queue_action_controls': {
        _rezkaId: {
          order: {
            'state': 'in_progress',
            'allowed_actions': [
              'pause',
              'detach_roll',
              'roll_complete',
              'complete'
            ],
            'previous_stage_ready': true,
            'complete_requires_full_report': false,
            'rezka_output_kadr_counts': [1, 1, 1, 1],
            'rezka_output_report': {'cycle_id': cycle, 'frames': frames},
            'interaction': {
              'mode': 'in_progress',
              'start_materials_mode': 'hidden',
              'material_scan_required': false,
              'assigned_materials_display_only': true,
              'material_intake_allowed': false,
              'previous_wip_mode': 'not_required',
              'opening_wip_mode': 'not_required',
              'qolip_mode': 'not_required',
              'blocking_reason_code': '',
            },
          },
        },
      },
      'order_controls': {
        order: {'state': 'active'}
      },
      'order_statuses': {},
      'frozen_orders_by_apparatus': {},
    };
