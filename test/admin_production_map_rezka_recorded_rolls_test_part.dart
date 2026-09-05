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
      await tester.tap(find.text('Rezka'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('rezka-recorded-dialog').first);
      await tester.pumpAndSettle();
      for (final action in ['Rulonni yechish', 'Tugatish', 'Rulonni yechish']) {
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
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
          expect(pending.controller!.text, isEmpty);
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
}
