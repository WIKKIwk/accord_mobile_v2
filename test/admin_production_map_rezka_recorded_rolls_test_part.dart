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
      await tester.tap(find.byKey(const ValueKey('worker-order-$order')));
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

  testWidgets(
      'Rezka pause shows Bobina tare error inline and revalidates both weights',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await AppSession.instance.setSession(
      token: 'rezka-bobina-validation-worker',
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Rezka operatori',
        legalName: '',
        ref: 'rezka-bobina-validation-worker',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_rezkaId],
      ),
    );
    const order = 'zakaz-rezka-bobina-validation';
    const cycle = 'rezka-bobina-validation-cycle';
    final map = _productionOrderMap(
      id: order,
      title: 'Bobina validation',
      productCode: 'RBV',
      apparatusId: _rezkaId,
      product: 'Bobina validation product',
    );
    await MobileApi.instance.adminSaveProductionMap(
      map.copyWith(
        nodes: [
          for (final node in map.nodes)
            node.apparatusId == _rezkaId
                ? node.copyWith(rezkaKadrCount: 1)
                : node,
        ],
      ),
    );
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
        rezkaOutputKadrCounts: const [1],
        rezkaOutputReport: const AdminRezkaOutputReport(cycleId: cycle),
      ),
    );

    var printerSelections = 0;
    final theme = ThemeData(useMaterial3: true);
    await _usePhoneViewport(tester);
    tester.view.physicalSize = const Size(500, 1080);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
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
        progressDriverUrlPicker: (_) async {
          printerSelections += 1;
          return null;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rezka'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('worker-order-$order')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rulonni yechish'));
    await tester.pumpAndSettle();

    expect(find.text('Pauza miqdori'), findsOneWidget);
    Finder field(String name) => find.byKey(ValueKey('rezka-frame-0-$name'));
    Future<void> edit(String name, String value) async {
      await tester.ensureVisible(field(name));
      await tester.enterText(field(name), value);
      await tester.pumpAndSettle();
    }

    const error = 'Bobina vazni umumiy vazndan katta bo‘lmasligi kerak';
    await edit('meter', '54');
    await edit('kg', '448');
    await edit('bobina', '544');
    await edit('diameter', '45');
    expect(find.text(error), findsNothing);

    await tester.ensureVisible(find.text('Tasdiqlash'));
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
    expect(find.text(error), findsOneWidget);
    expect(printerSelections, 0);
    expect(
      (await MobileApi.instance.adminProductionMapQueueSnapshot())
          .queueStates[_rezkaId]?[order],
      'in_progress',
    );
    expect(
        tester.widget<TextFormField>(field('bobina')).controller!.text, '544');
    final bobinaDecorator = tester.widget<InputDecorator>(
      find
          .descendant(
              of: field('bobina'), matching: find.byType(InputDecorator))
          .first,
    );
    expect(bobinaDecorator.decoration.errorText, error);
    expect(
      (bobinaDecorator.decoration.errorBorder! as OutlineInputBorder)
          .borderSide
          .color,
      theme.colorScheme.error,
    );

    await edit('kg', '600');
    expect(find.text(error), findsNothing);
    await edit('kg', '448');
    expect(find.text(error), findsOneWidget);
    await edit('bobina', '448');
    expect(find.text(error), findsNothing);

    await tester.ensureVisible(find.text('Tasdiqlash'));
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
    expect(printerSelections, 1);
    expect(find.text('Pauza miqdori'), findsNothing);
    expect(
      (await MobileApi.instance.adminProductionMapQueueSnapshot())
          .queueStates[_rezkaId]?[order],
      'in_progress',
    );
    expect(tester.takeException(), isNull);
  });

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
      if (request.url.path.endsWith('/rezka-output-report')) {
        return http.Response('', 404);
      }
      if (request.url.path.endsWith('/order-scan-bootstrap')) {
        return http.Response('', 404);
      }
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
              'apparatus': _rezkaId,
              'order_id': order,
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
      expect(find.byKey(const ValueKey('rezka-deviation-warning')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-confirm')));
      await tester.pumpAndSettle();
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

  for (final action in ['pause', 'complete']) {
    testWidgets(
        'Rezka $action print queue preserves retries and ${action == 'pause' ? 'automatically pauses' : 'keeps manual confirmation'}',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Rezka operatori',
        legalName: '',
        ref: 'rezka-print-queue-worker',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_rezkaId],
      );
      final order = 'zakaz-rezka-print-queue-$action';
      final cycle = 'rezka-print-queue-cycle-$action';
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: order,
        title: 'Queued Rezka rolls',
        productCode: 'QUEUE',
        orderNumber: '0023',
        apparatusId: _rezkaId,
        product: 'Queued Rezka rolls',
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _rezkaId, orderIds: [order]);
      await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _rezkaId, orderId: order, action: 'start');
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: _rezkaId,
        orderId: order,
        control: _inProgressQueueControl(
          allowRollComplete: true,
          rezkaOutputKadrCounts: [1, 1],
          rezkaOutputReport: AdminRezkaOutputReport(cycleId: cycle),
        ),
      );
      await _usePhoneViewport(tester);

      final frames = <Map<String, dynamic>>[];
      final events = <String>[];
      final firstPrintStarted = Completer<void>();
      final releaseFirstPrint = Completer<void>();
      final finalActions = <Map<String, dynamic>>[];
      var queueState = 'in_progress';
      var firstPrintAttempts = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/rezka-output-report')) {
          return http.Response('', 404);
        }
        if (request.url.path.endsWith('/order-scan-bootstrap')) {
          return http.Response('', 404);
        }
        if (request.method == 'GET') {
          return http.Response(
              jsonEncode(_rezkaAutofillSnapshot(order, cycle, frames,
                  kadrCounts: const [1, 1], state: queueState)),
              200);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/queue-action')) {
          if (body['rezka_record_frame_index'] == null) {
            finalActions.add(body);
            events.add('finalize:${body['action']}');
            queueState = 'paused';
            return http.Response(
                jsonEncode({
                  'states': {order: queueState}
                }),
                200);
          }
          final index = body['rezka_record_frame_index'] as int;
          events.add('save:$index');
          frames.add({
            'frame_index': index,
            'batch_id': 'queued-roll-$index',
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
        final batchId = body['progress_batch_id']?.toString() ?? '';
        events.add('print:$batchId');
        if (batchId == 'queued-roll-1' && firstPrintAttempts++ == 0) {
          firstPrintStarted.complete();
          await releaseFirstPrint.future;
          return http.Response('{"error":"print_failed"}', 500);
        }
        return http.Response(
            jsonEncode({
              'ok': true,
              'batch': {
                'batch_id': batchId,
                'apparatus': _rezkaId,
                'order_id': order,
                'qr_payload': body['qr_payload'],
              },
            }),
            200);
      });

      Finder field(int index, String name) =>
          find.byKey(ValueKey('rezka-frame-$index-$name'));
      Future<void> edit(int index, String name, String value) async {
        final target = field(index, name);
        await tester.ensureVisible(target);
        await tester.enterText(target, value);
        await tester.pumpAndSettle();
      }

      Future<void> pumpUntil(bool Function() condition) async {
        for (var attempt = 0; attempt < 50 && !condition(); attempt += 1) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        expect(condition(), isTrue);
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
        await tester.tap(find.byKey(ValueKey('worker-order-$order')));
        await tester.pumpAndSettle();
        await tester
            .tap(find.text(action == 'pause' ? 'Rulonni yechish' : 'Tugatish'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        await edit(0, 'meter', '1000');
        await edit(0, 'kg', '20');
        await edit(0, 'bobina', '0.5');
        await edit(0, 'diameter', '45');
        await TestModeController.instance.setEnabled(false);

        final firstPrint = find.byKey(const ValueKey('rezka-frame-0-print'));
        await tester.ensureVisible(firstPrint);
        await tester.tap(firstPrint);
        await pumpUntil(() => firstPrintStarted.isCompleted);
        expect(tester.widget<TextFormField>(field(1, 'kg')).enabled, isTrue);

        // A sibling can be edited and queued while the first printer job waits.
        await edit(1, 'kg', '18');
        await edit(1, 'bobina', '0.75');
        await edit(1, 'diameter', '40');
        expect(tester.widget<TextFormField>(field(1, 'meter')).controller!.text,
            '900');
        final secondPrint = find.byKey(const ValueKey('rezka-frame-1-print'));
        await tester.ensureVisible(secondPrint);
        await tester.tap(secondPrint);
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(field(1, 'kg')).enabled, isFalse);
        expect(find.textContaining('Navbatda'), findsOneWidget);
        expect(events, ['save:1', 'print:queued-roll-1']);

        releaseFirstPrint.complete();
        await pumpUntil(() => find
            .text(
                'Saqlandi. Chop etish tasdiqlanmadi — qayta chop etishingiz mumkin.')
            .evaluate()
            .isNotEmpty);
        expect(events, ['save:1', 'print:queued-roll-1']);
        expect(frames, hasLength(1));
        expect(finalActions, isEmpty);
        expect(tester.widget<IconButton>(firstPrint).onPressed, isNotNull);
        expect(tester.widget<IconButton>(secondPrint).onPressed, isNull);

        await tester.tap(firstPrint);
        await pumpUntil(() => find
            .byKey(const ValueKey('rezka-deviation-warning'))
            .evaluate()
            .isNotEmpty);
        await tester.tap(find.byKey(const ValueKey('rezka-deviation-confirm')));
        await pumpUntil(() => events.length >= 5);
        if (action == 'pause') {
          await pumpUntil(() => finalActions.isNotEmpty);
          await tester.pumpAndSettle();
          expect(finalActions, hasLength(1));
          final submitted = finalActions.single;
          expect(submitted['action'], 'pause');
          expect(submitted['rezka_record_frame_index'], isNull);
          expect(submitted['rezka_output_cycle'], cycle);
          expect(submitted['rezka_frames'],
              frames.map((frame) => frame['input']).toList());
          expect(find.byKey(const ValueKey('rezka-frame-0-kg')), findsNothing);
          expect(find.text('Pauza miqdori'), findsNothing);
          expect(find.widgetWithText(FilledButton, 'Davom ettirish'),
              findsOneWidget);
        } else {
          await pumpUntil(() =>
              find
                  .text('Chop etildi · QRni shu rulonga yopishtiring')
                  .evaluate()
                  .length ==
              2);
          expect(finalActions, isEmpty);
          expect(
              find.byKey(const ValueKey('rezka-frame-0-kg')), findsOneWidget);
          expect(
              tester
                  .widget<FilledButton>(
                      find.widgetWithText(FilledButton, 'Tasdiqlash'))
                  .onPressed,
              isNotNull);
        }
        expect(events, [
          'save:1',
          'print:queued-roll-1',
          'print:queued-roll-1',
          'save:2',
          'print:queued-roll-2',
          if (action == 'pause') 'finalize:pause',
        ]);
        expect(frames, hasLength(2));
        final secondInput = frames.last['input'] as Map<String, dynamic>;
        expect(secondInput['produced_qty'], 900);
        expect(secondInput['gross_qty'], 18);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }

  testWidgets(
      'Rezka pause waits for every individual roll print before finalizing',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Rezka operatori',
      legalName: '',
      ref: 'rezka-sequential-print-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [_rezkaId],
    );
    const order = 'zakaz-rezka-sequential-print';
    const cycle = 'rezka-sequential-print-cycle';
    await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
      id: order,
      title: 'Sequential Rezka rolls',
      productCode: 'SEQ',
      orderNumber: '0024',
      apparatusId: _rezkaId,
      product: 'Sequential Rezka rolls',
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
    final finalActions = <Map<String, dynamic>>[];
    final printedBatches = <String>[];
    var failLastPrint = true;
    var queueState = 'in_progress';
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/rezka-output-report') ||
          request.url.path.endsWith('/order-scan-bootstrap')) {
        return http.Response('', 404);
      }
      if (request.method == 'GET') {
        return http.Response(
            jsonEncode(_rezkaAutofillSnapshot(order, cycle, frames,
                state: queueState)),
            200);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path.endsWith('/queue-action')) {
        final index = body['rezka_record_frame_index'] as int?;
        if (index == null) {
          finalActions.add(body);
          queueState = 'paused';
          return http.Response(
              jsonEncode({
                'states': {order: queueState}
              }),
              200);
        }
        expect(body['action'], 'roll_complete');
        expect(frames.any((frame) => frame['frame_index'] == index), isFalse);
        frames.add({
          'frame_index': index,
          'batch_id': 'sequential-roll-$index',
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
      final batchId = body['progress_batch_id'] as String;
      printedBatches.add(batchId);
      if (batchId == 'sequential-roll-4' && failLastPrint) {
        return http.Response('{"error":"print_failed"}', 500);
      }
      return http.Response(
          jsonEncode({
            'ok': true,
            'batch': {
              'batch_id': batchId,
              'apparatus': _rezkaId,
              'order_id': order,
              'qr_payload': body['qr_payload'],
            },
          }),
          200);
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
      await TestModeController.instance.setEnabled(false);
      for (var index = 0; index < 4; index++) {
        final print = find.byKey(ValueKey('rezka-frame-$index-print'));
        await tester.ensureVisible(print);
        await tester.tap(print);
        await tester.pumpAndSettle();
        expect(frames, hasLength(index + 1));
        expect(finalActions, isEmpty);
        expect(find.text('Pauza miqdori'), findsOneWidget);
      }
      expect(
          find.text(
              'Saqlandi. Chop etish tasdiqlanmadi — qayta chop etishingiz mumkin.'),
          findsOneWidget);
      expect(
          tester
              .widget<TextFormField>(
                  find.byKey(const ValueKey('rezka-frame-3-kg')))
              .enabled,
          isFalse);
      failLastPrint = false;
      final lastPrint = find.byKey(const ValueKey('rezka-frame-3-print'));
      await tester.ensureVisible(lastPrint);
      await tester.tap(lastPrint);
      await tester.pumpAndSettle();
      expect(finalActions, hasLength(1));
      expect(finalActions.single['action'], 'pause');
      expect(finalActions.single['rezka_output_cycle'], cycle);
      expect(finalActions.single['rezka_record_frame_index'], isNull);
      expect(finalActions.single['rezka_frames'],
          frames.map((frame) => frame['input']).toList());
      expect(frames, hasLength(4));
      expect(printedBatches, [
        'sequential-roll-1',
        'sequential-roll-2',
        'sequential-roll-3',
        'sequential-roll-4',
        'sequential-roll-4',
      ]);
      expect(find.text('Pauza miqdori'), findsNothing);
      expect(
          find.widgetWithText(FilledButton, 'Davom ettirish'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}

Map<String, dynamic> _rezkaAutofillSnapshot(
        String order, String cycle, List<Map<String, dynamic>> frames,
        {List<int> kadrCounts = const [1, 1, 1, 1],
        String state = 'in_progress'}) =>
    {
      'sequences': {
        _rezkaId: [order]
      },
      'visible_order_ids': {
        _rezkaId: [order]
      },
      'queue_states': {
        _rezkaId: {order: state}
      },
      'stage_states': {},
      'queue_policies': [],
      'queue_action_controls': {
        _rezkaId: {
          order: {
            'state': state,
            'allowed_actions': state == 'paused'
                ? ['resume']
                : ['pause', 'detach_roll', 'roll_complete', 'complete'],
            'previous_stage_ready': true,
            'complete_requires_full_report': false,
            'rezka_output_kadr_counts': kadrCounts,
            'rezka_output_report': {'cycle_id': cycle, 'frames': frames},
            'interaction': {
              'mode': state,
              'resume_input_required': false,
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
