part of 'admin_production_map_test_screen_test.dart';

Map<String, dynamic> _autoQolipControl(
    {bool automatic = true,
    int policyRevision = 1,
    bool materialScan = false}) {
  final control = scanControl();
  control['interaction'] = <String, dynamic>{
    ...(control['interaction'] as Map<String, dynamic>),
    'qolip_automatic_confirmation': automatic,
    'qolip_policy_revision': policyRevision,
    'start_materials_mode': materialScan ? 'scan_required' : 'hidden',
    'material_scan_required': materialScan,
  };
  return control;
}

Map<String, dynamic> _autoQolipData(
        {int sets = 1,
        bool rework = false,
        bool missing = false,
        int policyRevision = 1}) =>
    {
      'ok': true,
      'qolip': {
        'qolip_code': '',
        'automatic_confirmation_enabled': true,
        'policy_revision': policyRevision,
        'blocking_reason_code': rework ? 'qolip_in_rework' : missing ? 'qolip_scan_required' : '',
        'required_qolip_count': missing ? 0 : sets * 2,
        'required_qolip_codes': [
          if (!missing)
            for (var i = 1; i <= sets; i++) ...[
              'AUTO-A-' + i.toString(),
              'AUTO-B-' + i.toString()
            ]
        ],
        'required_qolips': [
          if (!missing)
            for (var i = 1; i <= sets; i++)
              for (final member in ['A', 'B'])
                {
                  'qolip_code': 'AUTO-' + member + '-' + i.toString(),
                  'color': member == 'A' ? 'BLACK' : 'CYAN',
                  'qolip_set_id': '95010000000' + i.toString(),
                  'is_extension': false,
                  'ready': !(rework && member == 'B'),
                  'blocking_reason_code':
                      rework && member == 'B' ? 'qolip_in_rework' : '',
                }
        ],
        'sets': [
          if (!missing)
            for (var i = 1; i <= sets; i++)
              {
                'set_id': '95010000000' + i.toString(),
                'fingerprint': i.toString().padLeft(64, '0'),
                'ready': !rework,
                'blocking_reason_code': rework ? 'qolip_in_rework' : '',
              }
        ],
      },
    };

Map<String, dynamic> _autoBootstrap(
    {int sets = 1,
    bool rework = false,
    bool missing = false,
    bool materialScan = false,
    bool automatic = true,
    int policyRevision = 1,
    int revision = 7}) {
  final body = scanBootstrap(revision: revision);
  body['control_state']['control'] = _autoQolipControl(
      automatic: automatic,
      policyRevision: policyRevision,
      materialScan: materialScan);
  body['sections']['qolips']['data'] = automatic
      ? _autoQolipData(
          sets: sets,
          rework: rework,
          missing: missing,
          policyRevision: policyRevision)
      : scanQolips();
  return body;
}

AdminProductionMapLiveSnapshot _autoLiveSnapshot(ProductionMapSaved order,
        {bool automatic = true,
        int revision = 7,
        int policyRevision = 1,
        bool materialScan = false}) =>
    AdminProductionMapLiveSnapshot.fromJson({
      ...scanSequence(),
      'rev': revision,
      'scope': 'worker-live-scope',
      'queue_action_controls': {
        scanApparatus: {
          scanOrder: _autoQolipControl(
              automatic: automatic,
              policyRevision: policyRevision,
              materialScan: materialScan)
        }
      },
      'maps': [
        {'map': order.map.toJson(), 'program': <String, dynamic>{}}
      ],
    });

Future<void> _openAutomaticQolipFixture(
    WidgetTester tester, _ScanBootstrapFixture fixture,
    {bool materialScan = false}) async {
  final snapshot = _autoLiveSnapshot(fixture.order, materialScan: materialScan);
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
        queueSnapshotLoader: () async => snapshot,
        apparatusLoader: () async => fixture.apparatus,
        liveEventsLoader: () => fixture.live.stream),
  ));
  await tester.pumpAndSettle();
  fixture.live.add(snapshot);
  await tester.pump();
  await tester.tap(find.text('7 ta rangli bosma aparat'));
  await tester.pumpAndSettle();
  await TestModeController.instance.setEnabled(false);
  await tester.tap(find.textContaining('scan-bootstrap').first);
  await tester.pump();
}

void _registerAutomaticQolipTests() {
  for (final outcome in [
    'single',
    'alternatives',
    'rework',
    'missing',
    'material'
  ]) {
    testWidgets('automatic mold start: ' + outcome, (tester) async {
      final fixture = await _prepareScanBootstrapFixture(tester);
      final material = outcome == 'material';
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        await _openAutomaticQolipFixture(tester, fixture,
            materialScan: material);
        await tester.pumpAndSettle();
        final button =
            find.byKey(const ValueKey('production-order-start-action'));
        final canStart = outcome == 'single';
        expect(tester.widget<FilledButton>(button).onPressed,
            canStart ? isNotNull : isNull);
        expect(find.byType(ProductionQuickScannerPanel),
            material ? findsOneWidget : findsNothing);
        if (outcome == 'single' || material) {
          expect(find.byKey(const ValueKey('production-qolip-auto-status')),
              findsOneWidget);
          expect(find.byKey(const ValueKey('production-qolip-auto-AUTO-A-1')),
              findsOneWidget);
          expect(find.byKey(const ValueKey('production-qolip-auto-AUTO-B-1')),
              findsOneWidget);
        }
        if (outcome == 'alternatives') {
          final choice = find.byKey(
              const ValueKey('production-qolip-set-select-950100000002'));
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pumpAndSettle();
          expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
          expect(find.byKey(const ValueKey('production-qolip-auto-status')),
              findsOneWidget);
          expect(find.byKey(const ValueKey('production-qolip-auto-AUTO-A-1')),
              findsNothing);
          expect(find.byKey(const ValueKey('production-qolip-auto-AUTO-A-2')),
              findsOneWidget);
        }
        if (outcome == 'rework') {
          expect(find.byKey(const ValueKey('production-qolip-auto-status')),
              findsNothing);
          final good =
              find.byKey(const ValueKey('production-qolip-auto-AUTO-A-1'));
          final away =
              find.byKey(const ValueKey('production-qolip-auto-AUTO-B-1'));
          expect(
              find.descendant(
                  of: good, matching: find.byIcon(Icons.check_circle_rounded)),
              findsOneWidget);
          expect(
              find.descendant(
                  of: away, matching: find.byIcon(Icons.warning_amber_rounded)),
              findsOneWidget);
          expect(find.textContaining('peredelkada'), findsWidgets);
        }
        if (outcome == 'missing') {
          expect(find.text('Mahsulotga qolip biriktirilmagan'), findsWidgets);
          expect(find.byKey(const ValueKey('production-qolip-auto-status')),
              findsNothing);
        }
        if (canStart || outcome == 'alternatives') {
          final dynamic content = tester.widget(find.byWidgetPredicate((w) =>
              w.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));
          content.onStart();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final writes =
              requests.where((r) => r.url.path.endsWith('/queue-action'));
          expect(writes, hasLength(1));
          final body = jsonDecode(writes.single.body) as Map;
          expect(body['qolip_confirmation'], {
            'method': 'automatic',
            'set_id':
                outcome == 'alternatives' ? '950100000002' : '950100000001',
            'fingerprint':
                (outcome == 'alternatives' ? '2' : '1').padLeft(64, '0'),
            'policy_revision': 1,
          });
          expect(body.containsKey('qolip_codes'), isFalse);
        } else {
          expect(requests.where((r) => r.url.path.endsWith('/queue-action')),
              isEmpty);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(const Duration(seconds: 11));
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                requests.add(request);
                if (request.url.path.endsWith('/order-scan-bootstrap')) {
                  return http.Response(
                      jsonEncode(_autoBootstrap(
                          sets: outcome == 'alternatives' ? 2 : 1,
                          rework: outcome == 'rework',
                          missing: outcome == 'missing',
                          materialScan: material)),
                      200);
                }
                if (request.url.path.endsWith('/qolip-validate')) {
                  return http.Response(
                      jsonEncode(_autoQolipData(
                          sets: outcome == 'alternatives' ? 2 : 1,
                          rework: outcome == 'rework',
                          missing: outcome == 'missing')),
                      200);
                }
                if (request.url.path.endsWith('/queue-action')) {
                  return http.Response('{"error":"apparatus_busy"}', 409);
                }
                return http.Response('{}', 200);
              }));
    });
  }
}

void _registerAutomaticQolipLiveTests() {
  for (final change in ['policy off', 'rework', 'late response']) {
    testWidgets('automatic mold start refreshes after ' + change,
        (tester) async {
      final fixture = await _prepareScanBootstrapFixture(tester);
      var automatic = true;
      var rework = false;
      var revision = 7;
      final pending = Completer<http.Response>();
      var requirementsReads = 0;
      await http.runWithClient(() async {
        await _openAutomaticQolipFixture(tester, fixture);
        if (change == 'late response') {
          await tester.pump(const Duration(milliseconds: 300));
          expect(requirementsReads, 1);
        } else {
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('production-qolip-auto-status')),
              findsOneWidget);
        }
        automatic = change == 'rework';
        rework = change == 'rework';
        revision = 8;
        fixture.live.add(_autoLiveSnapshot(fixture.order,
            automatic: automatic,
            revision: revision,
            policyRevision: automatic ? 1 : 2));
        await tester.pump();
        if (change == 'late response') {
          pending.complete(http.Response(jsonEncode(_autoQolipData()), 200));
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('production-qolip-auto-status')),
            findsNothing);
        final start =
            find.byKey(const ValueKey('production-order-start-action'));
        expect(tester.widget<FilledButton>(start).onPressed, isNull);
        expect(find.byType(ProductionQuickScannerPanel),
            automatic ? findsNothing : findsOneWidget);
        if (rework) {
          expect(find.textContaining('peredelkada'), findsWidgets);
          rework = false;
          revision = 9;
          fixture.live
              .add(_autoLiveSnapshot(fixture.order, revision: revision));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('production-qolip-auto-status')),
              findsOneWidget);
          expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(const Duration(seconds: 11));
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/order-scan-bootstrap')) {
                  final body = _autoBootstrap(
                      automatic: automatic,
                      rework: rework,
                      revision: revision,
                      policyRevision: automatic ? 1 : 2);
                  if (change == 'late response' && revision == 7) {
                    (body['sections'] as Map).remove('qolips');
                  }
                  return http.Response(jsonEncode(body), 200);
                }
                if (request.url.path.endsWith('/qolip-validate')) {
                  requirementsReads++;
                  if (change == 'late response' && automatic)
                    return pending.future;
                  return http.Response(
                      jsonEncode(automatic
                          ? _autoQolipData(rework: rework)
                          : scanQolips()),
                      200);
                }
                return http.Response('{}', 200);
              }));
    });
  }
}
