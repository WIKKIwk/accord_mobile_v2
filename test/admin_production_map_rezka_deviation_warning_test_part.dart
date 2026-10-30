part of 'admin_production_map_test_screen_test.dart';

void _registerRezkaDeviationWarningTests() {
  testWidgets('Rezka deviation: first WIP prints without confirmation',
      (tester) async {
    await _withRezkaDeviationDialog(tester, savedFirst: false,
        run: (fixture) async {
      await fixture.fill(0, kg: '126');
      await fixture.print(0);
      expect(fixture.warning, findsNothing);
      expect(fixture.saves, hasLength(1));
      expect(fixture.saves.single['rezka_record_frame_index'], 1);
      expect(fixture.printerSelections, 1);
    });
  });

  testWidgets(
      'Rezka deviation: saved issues do not become the first measured reference',
      (tester) async {
    await _withRezkaDeviationDialog(tester, savedFirstIssue: true,
        run: (fixture) async {
      await fixture.fill(1, kg: '126');
      await fixture.print(1);
      expect(fixture.warning, findsNothing);
      expect(fixture.saves, hasLength(1));
      expect(fixture.saves.single['rezka_record_frame_index'], 2);
    });
  });

  testWidgets(
      'Rezka deviation: reopened out-of-order frames retain the server reference',
      (tester) async {
    await _withRezkaDeviationDialog(tester,
        referenceFrameIndex: 3,
        initialFrames: [
          for (final index in [1, 3])
            {
              'frame_index': index,
              'batch_id': 'pinned-roll-$index',
              'qr_payload': 'QR-pinned-$index',
              'input': {
                'produced_qty': 1000.0,
                'gross_qty': index == 3 ? 100.0 : 20.0,
                'bobina_kg': 0.5,
                'diameter': 50.0
              }
            },
        ], run: (fixture) async {
      expect(double.parse(fixture.value(3, 'kg')), 100,
          reason:
              'Autofill must preserve the first saved reference, not lowest slot');
      await fixture.fill(1, kg: '100');
      await fixture.print(1);
      expect(fixture.warning, findsNothing);
      expect(fixture.saves, hasLength(1));
    });
  });

  for (final entry in <String, String>{
    'kg high': '23',
    'kg low': '17',
    'meter high': '1101',
    'meter low': '899',
    'diameter high': '56',
    'diameter low': '44',
  }.entries) {
    testWidgets(
        'Rezka deviation: ${entry.key} warns only on Print and cancel preserves the draft',
        (tester) async {
      await _withRezkaDeviationDialog(tester, run: (fixture) async {
        await fixture.fill(1);
        final field = entry.key.split(' ').first;
        await fixture.edit(1, field, entry.value);
        if (field == 'kg') await fixture.edit(1, 'meter', '1000');
        expect(fixture.warning, findsNothing,
            reason: 'Typing never opens a warning');
        await fixture.print(1);
        expect(fixture.warning, findsOneWidget);
        expect(fixture.saves, isEmpty);
        expect(fixture.printerSelections, 0);
        expect(
            find.descendant(
                of: fixture.warning,
                matching: find.textContaining(entry.value)),
            findsWidgets);
        await tester.tap(find.byKey(const ValueKey('rezka-deviation-edit')));
        await tester.pumpAndSettle();
        expect(fixture.warning, findsNothing);
        expect(fixture.value(1, field), entry.value);
        expect(fixture.saves, isEmpty);
        expect(fixture.reprints, 0);
        expect(tester.widget<TextFormField>(fixture.field(1, field)).enabled,
            isTrue);
        fixture.expectCorrectionFocus(1, field);
      });
    });
  }

  for (final upper in [false, true]) {
    testWidgets(
        'Rezka deviation: exact ${upper ? "+" : "-"}10 percent boundaries print normally',
        (tester) async {
      await _withRezkaDeviationDialog(tester, run: (fixture) async {
        await fixture.fill(1,
            kg: upper ? '22' : '18',
            meter: upper ? '1100' : '900',
            diameter: upper ? '55' : '45');
        await fixture.print(1);
        expect(fixture.warning, findsNothing);
        expect(fixture.saves, hasLength(1));
        expect(fixture.saves.single['rezka_record_frame_index'], 2);
      });
    });
  }

  testWidgets(
      'Rezka deviation: confirmed abnormal WIP saves once and reprints without another warning',
      (tester) async {
    await _withRezkaDeviationDialog(tester, run: (fixture) async {
      await fixture.fill(1, kg: '126');
      await fixture.print(1);
      expect(fixture.warning, findsOneWidget);
      expect(fixture.saves, isEmpty);
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.warning, findsNothing);
      expect(fixture.saves, hasLength(1));
      final input =
          (fixture.saves.single['rezka_frames'] as List).single as Map;
      expect(input['gross_qty'], 126);
      expect(fixture.reprints, 1);
      await fixture.print(1);
      expect(fixture.warning, findsNothing);
      expect(fixture.saves, hasLength(1));
      expect(fixture.reprints, 2);
    });
  });

  testWidgets(
      'Rezka deviation: Edit is above confirmation with full-width buttons',
      (tester) async {
    await _withRezkaDeviationDialog(tester, run: (fixture) async {
      await fixture.fill(1, kg: '126');
      await fixture.print(1);
      expect(fixture.warning, findsOneWidget);
      final edit =
          tester.getRect(find.byKey(const ValueKey('rezka-deviation-edit')));
      final confirm =
          tester.getRect(find.byKey(const ValueKey('rezka-deviation-confirm')));
      expect(edit.bottom, lessThan(confirm.top));
      expect(edit.left, confirm.left);
      expect(edit.right, confirm.right);
      expect(
          confirm.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-edit')));
      await tester.pumpAndSettle();
      fixture.expectCorrectionFocus(1, 'kg');
    });
  });

  for (final bulk in [false, true]) {
    testWidgets(
        'Rezka deviation: ${bulk ? "bulk confirmation" : "Print"} asks each measurement separately before saving',
        (tester) async {
      await _withRezkaDeviationDialog(tester, run: (fixture) async {
        await fixture.fill(1, kg: '126', meter: '1500', diameter: '56');
        if (bulk) {
          await fixture.fill(2);
          await fixture.fill(3);
          await fixture.confirm();
        } else {
          await fixture.print(1);
        }
        const values = ['126 kg', '1500 m', '56 mm'];
        for (final value in values) {
          expect(fixture.warning, findsOneWidget);
          for (final candidate in values) {
            expect(
                find.descendant(
                    of: fixture.warning, matching: find.text(candidate)),
                candidate == value ? findsOneWidget : findsNothing);
          }
          expect(fixture.saves, isEmpty);
          expect(fixture.finalActions, isEmpty);
          await tester
              .tap(find.byKey(const ValueKey('rezka-deviation-confirm')));
          await tester.pumpAndSettle();
        }
        expect(fixture.warning, findsNothing);
        expect(bulk ? fixture.finalActions : fixture.saves, hasLength(1));
      });
    });
  }

  testWidgets(
      'Rezka deviation: correcting labels one by one advances to the next invalid field',
      (tester) async {
    await _withRezkaDeviationDialog(tester, run: (fixture) async {
      await fixture.fill(1, kg: '23');
      await fixture.fill(2, meter: '1500');
      await fixture.fill(3, diameter: '56');
      for (final entry in [
        (1, 'kg', '23 kg', '20'),
        (2, 'meter', '1500 m', '1000'),
        (3, 'diameter', '56 mm', '50'),
      ]) {
        await fixture.confirm();
        expect(fixture.warning, findsOneWidget);
        expect(
            find.descendant(
                of: fixture.warning,
                matching: find.text('${entry.$1 + 1}-kadr')),
            findsOneWidget);
        expect(
            find.descendant(of: fixture.warning, matching: find.text(entry.$3)),
            findsOneWidget);
        expect(fixture.saves, isEmpty);
        expect(fixture.finalActions, isEmpty);
        await tester.tap(find.byKey(const ValueKey('rezka-deviation-edit')));
        await tester.pumpAndSettle();
        fixture.expectCorrectionFocus(entry.$1, entry.$2);
        await fixture.edit(entry.$1, entry.$2, entry.$4);
      }
      await fixture.confirm();
      expect(fixture.warning, findsNothing);
      expect(fixture.finalActions, hasLength(1));
    });
  });

  testWidgets(
      'Rezka deviation: correcting one field keeps approval of a different unchanged field',
      (tester) async {
    await _withRezkaDeviationDialog(tester, run: (fixture) async {
      await fixture.fill(1, kg: '23', meter: '1500');
      await fixture.fill(2, diameter: '56');
      await fixture.fill(3);
      await fixture.confirm();
      expect(find.descendant(of: fixture.warning, matching: find.text('23 kg')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-confirm')));
      await tester.pumpAndSettle();
      expect(
          find.descendant(of: fixture.warning, matching: find.text('1500 m')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-edit')));
      await tester.pumpAndSettle();
      fixture.expectCorrectionFocus(1, 'meter');
      await fixture.edit(1, 'meter', '1000');
      await fixture.confirm();
      expect(find.descendant(of: fixture.warning, matching: find.text('56 mm')),
          findsOneWidget,
          reason: 'The unchanged confirmed 23 kg must not be asked again');
      expect(fixture.finalActions, isEmpty);
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-edit')));
      await tester.pumpAndSettle();
      fixture.expectCorrectionFocus(2, 'diameter');
      await fixture.edit(2, 'diameter', '50');
      await fixture.confirm();
      expect(fixture.warning, findsNothing);
      expect(fixture.finalActions, hasLength(1));
      final inputs = fixture.finalActions.single['rezka_frames'] as List;
      expect((inputs[1] as Map)['gross_qty'], 23);
      expect((inputs[1] as Map)['produced_qty'], 1000);
    });
  });

  testWidgets(
      'Rezka deviation: bulk confirmation checks unsaved frames before submitting',
      (tester) async {
    await _withRezkaDeviationDialog(tester, run: (fixture) async {
      for (final index in [1, 2, 3]) {
        await fixture.fill(index, kg: index == 2 ? '126' : '20');
      }
      final confirm = find.widgetWithText(FilledButton, 'Tasdiqlash');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(fixture.warning, findsOneWidget);
      expect(fixture.saves, isEmpty);
      expect(fixture.finalActions, isEmpty);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      tester.testTextInput.hide();
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-edit')));
      await tester.pumpAndSettle();
      expect(fixture.value(2, 'kg'), '126');
      expect(fixture.finalActions, isEmpty);
      fixture.expectCorrectionFocus(2, 'kg');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.finalActions, hasLength(1));
      final inputs = fixture.finalActions.single['rezka_frames'] as List;
      expect((inputs[2] as Map)['gross_qty'], 126);
    });
  });

  testWidgets(
      'Rezka deviation: refreshed correction replaces the stale reference',
      (tester) async {
    await _withRezkaDeviationDialog(tester, run: (fixture) async {
      await fixture.fill(1, kg: '12.6');
      final corrected = fixture.frames.first['input'] as Map<String, dynamic>;
      corrected['gross_qty'] = 12.6;
      await fixture.print(1);
      expect(fixture.warning, findsNothing);
      expect(fixture.saves, hasLength(1));
      expect((fixture.saves.single['rezka_frames'] as List).single,
          containsPair('gross_qty', 12.6));
      await fixture.edit(2, 'kg', '6.3');
      expect(fixture.value(2, 'meter'), '500',
          reason: 'Autofill must use the corrected reference ratio as well');
    });
  });

  testWidgets(
      'Rezka deviation: changing an acknowledged draft requires a fresh bulk warning',
      (tester) async {
    await _withRezkaDeviationDialog(tester, run: (fixture) async {
      await fixture.fill(1, kg: '23');
      await fixture.fill(2, kg: '24');
      await fixture.fill(3);
      final confirm = find.widgetWithText(FilledButton, 'Tasdiqlash');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.descendant(of: fixture.warning, matching: find.text('23 kg')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-confirm')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: fixture.warning, matching: find.text('24 kg')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-edit')));
      await tester.pumpAndSettle();
      expect(fixture.finalActions, isEmpty);
      await fixture.edit(1, 'kg', '25');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.descendant(of: fixture.warning, matching: find.text('25 kg')),
          findsOneWidget);
      expect(fixture.finalActions, isEmpty);
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-edit')));
      await tester.pumpAndSettle();
    });
  });

  testWidgets(
      'Rezka deviation: cancelling a queued outlier preserves it and prints the next card',
      (tester) async {
    await _withRezkaDeviationDialog(tester, run: (fixture) async {
      await fixture.fill(1, kg: '126');
      await fixture.fill(2);
      final blocked = Completer<void>();
      fixture.nextReprintBlock = blocked;
      await fixture.print(0);
      expect(fixture.reprints, 1);
      await fixture.print(1);
      await fixture.print(2);
      expect(fixture.saves, isEmpty);
      blocked.complete();
      await tester.pumpAndSettle();
      expect(fixture.warning, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-edit')));
      await tester.pumpAndSettle();
      expect(fixture.warning, findsNothing);
      expect(fixture.value(1, 'kg'), '126');
      expect(
          tester.widget<TextFormField>(fixture.field(1, 'kg')).enabled, isTrue);
      expect(fixture.saves, hasLength(1));
      expect(fixture.saves.single['rezka_record_frame_index'], 3);
      expect(fixture.frames.map((frame) => frame['frame_index']), [1, 3]);
      expect(fixture.reprints, 2);
      expect(fixture.finalActions, isEmpty);
      fixture.expectCorrectionFocus(1, 'kg');
    });
  });

  testWidgets(
      'Rezka deviation: Edit focuses the first differing measurement without changing values',
      (tester) async {
    await _withRezkaDeviationDialog(tester, run: (fixture) async {
      await fixture.fill(1, kg: '126', meter: '1500', diameter: '56');
      await fixture.print(1);
      expect(fixture.warning, findsOneWidget);
      tester.testTextInput.hide();
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-edit')));
      await tester.pumpAndSettle();
      fixture.expectCorrectionFocus(1, 'kg');
      expect(fixture.value(1, 'kg'), '126');
      expect(fixture.value(1, 'meter'), '1500');
      expect(fixture.value(1, 'diameter'), '56');
      expect(fixture.saves, isEmpty);
    });
  });

  testWidgets(
      'Rezka deviation: correction focus waits for the next queued warning to close',
      (tester) async {
    await _withRezkaDeviationDialog(tester, run: (fixture) async {
      await fixture.fill(1, kg: '126');
      await fixture.fill(2, kg: '127');
      final blocked = Completer<void>();
      fixture.nextReprintBlock = blocked;
      await fixture.print(0);
      await fixture.print(1);
      await fixture.print(2);
      blocked.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-edit')));
      await tester.pumpAndSettle();
      expect(fixture.warning, findsOneWidget);
      expect(
          find.descendant(of: fixture.warning, matching: find.text('127 kg')),
          findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse,
          reason:
              'The prior correction must not open a keyboard under a warning');
      await tester.tap(find.byKey(const ValueKey('rezka-deviation-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.warning, findsNothing);
      fixture.expectCorrectionFocus(1, 'kg');
      expect(fixture.value(1, 'kg'), '126');
      expect(fixture.saves.single['rezka_record_frame_index'], 3);
    });
  });

  for (final correctedKg in [12.6, 126.0]) {
    testWidgets(
        'Rezka deviation: reference corrected to $correctedKg while warning is open is checked again before save',
        (tester) async {
      await _withRezkaDeviationDialog(tester, run: (fixture) async {
        await fixture.fill(1, kg: '126');
        await fixture.print(1);
        expect(fixture.warning, findsOneWidget);
        (fixture.frames.first['input'] as Map<String, dynamic>)['gross_qty'] =
            correctedKg;
        await tester.tap(find.byKey(const ValueKey('rezka-deviation-confirm')));
        await tester.pumpAndSettle();
        if (correctedKg == 12.6) {
          expect(fixture.warning, findsOneWidget);
          expect(fixture.saves, isEmpty);
          expect(
              find.descendant(
                  of: fixture.warning, matching: find.textContaining('12.6')),
              findsOneWidget);
          await tester
              .tap(find.byKey(const ValueKey('rezka-deviation-confirm')));
          await tester.pumpAndSettle();
        }
        expect(fixture.warning, findsNothing);
        expect(fixture.saves, hasLength(1));
        expect((fixture.saves.single['rezka_frames'] as List).single,
            containsPair('gross_qty', 126));
      });
    });
  }

  testWidgets('Rezka deviation: first draft is exempt during bulk confirmation',
      (tester) async {
    await _withRezkaDeviationDialog(tester, savedFirst: false,
        run: (fixture) async {
      for (var index = 0; index < 4; index++) {
        await fixture.fill(index, kg: '126');
      }
      final confirm = find.widgetWithText(FilledButton, 'Tasdiqlash');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(fixture.warning, findsNothing);
      expect(fixture.finalActions, hasLength(1));
    });
  });
}

class _RezkaDeviationFixture {
  _RezkaDeviationFixture(this.tester, this.frames, {this.referenceFrameIndex});

  final WidgetTester tester;
  final List<Map<String, dynamic>> frames;
  final int? referenceFrameIndex;
  final saves = <Map<String, dynamic>>[];
  final finalActions = <Map<String, dynamic>>[];
  var reprints = 0;
  var printerSelections = 0;
  Completer<void>? nextReprintBlock;
  Finder get warning => find.byKey(const ValueKey('rezka-deviation-warning'));
  Finder field(int index, String name) =>
      find.byKey(ValueKey('rezka-frame-$index-$name'));
  String value(int index, String name) =>
      tester.widget<TextFormField>(field(index, name)).controller!.text;

  void expectCorrectionFocus(int index, String name) {
    final input = tester.widget<EditableText>(find.descendant(
        of: field(index, name), matching: find.byType(EditableText)));
    expect(input.focusNode.hasPrimaryFocus, isTrue,
        reason: 'Edit should focus the measurement shown in the warning');
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.testTextInput.setClientArgs?['inputType'],
        containsPair('name', 'TextInputType.number'));
    expect(tester.testTextInput.setClientArgs?['inputType'],
        containsPair('decimal', true));
    final rect = tester.getRect(field(index, name));
    final availableHeight =
        (tester.view.physicalSize.height - tester.view.viewInsets.bottom) /
            tester.view.devicePixelRatio;
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(availableHeight));
  }

  Future<void> edit(int index, String name, String text) async {
    await tester.ensureVisible(field(index, name));
    await tester.enterText(field(index, name), text);
    await tester.pumpAndSettle();
  }

  Future<void> fill(int index,
      {String meter = '1000', String kg = '20', String diameter = '50'}) async {
    await edit(index, 'kg', kg);
    await edit(index, 'meter', meter);
    await edit(index, 'bobina', '0.5');
    await edit(index, 'diameter', diameter);
  }

  Future<void> print(int index) async {
    final target = find.byKey(ValueKey('rezka-frame-$index-print'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> confirm() async {
    final target = find.widgetWithText(FilledButton, 'Tasdiqlash');
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }
}

Future<void> _withRezkaDeviationDialog(WidgetTester tester,
    {bool savedFirst = true,
    bool savedFirstIssue = false,
    int? referenceFrameIndex,
    List<Map<String, dynamic>>? initialFrames,
    required Future<void> Function(_RezkaDeviationFixture) run}) async {
  const order = 'zakaz-rezka-deviation';
  const cycle = 'rezka-deviation-cycle';
  await TestModeController.instance.setEnabled(true);
  AppSession.instance.profile = const SessionProfile(
    role: UserRole.aparatchi,
    displayName: 'Rezka operatori',
    legalName: '',
    ref: 'rezka-deviation-worker',
    phone: '',
    avatarUrl: '',
    capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
    assignedApparatus: [_rezkaId],
  );
  await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
      id: order,
      title: 'Rezka deviation',
      productCode: 'DEVIATION',
      apparatusId: _rezkaId,
      product: 'Deviation rolls'));
  await MobileApi.instance
      .adminSaveProductionMapSequence(apparatus: _rezkaId, orderIds: [order]);
  await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: _rezkaId, orderId: order, action: 'start');
  final frames = initialFrames ??
      <Map<String, dynamic>>[
        if (savedFirst)
          {
            'frame_index': 1,
            'batch_id': savedFirstIssue ? '' : 'deviation-roll-1',
            'qr_payload': savedFirstIssue ? '' : 'QR-deviation-1',
            'input': savedFirstIssue
                ? {'issue_note': 'Kadr yirtilgan'}
                : {
                    'produced_qty': 1000.0,
                    'gross_qty': 20.0,
                    'bobina_kg': 0.5,
                    'diameter': 50.0
                  },
          },
      ];
  setMobileApiTestModeQueueActionControlFixture(
    apparatus: _rezkaId,
    orderId: order,
    control: _inProgressQueueControl(
      allowRollComplete: true,
      rezkaOutputKadrCounts: [1, 1, 1, 1],
      rezkaOutputReport: AdminRezkaOutputReport.tryFromJson({
        'cycle_id': cycle,
        'frames': frames,
        'reference_frame_index': referenceFrameIndex
      }),
    ),
  );
  await _usePhoneViewport(tester);
  tester.view.physicalSize = const Size(500, 1080);
  final fixture = _RezkaDeviationFixture(tester, frames,
      referenceFrameIndex: referenceFrameIndex);
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/raw-material-assignments')) {
      return http.Response('[]', 200);
    }
    if (request.url.path.endsWith('/rezka-output-report')) {
      return http.Response(
          jsonEncode({
            'ok': true,
            'apparatus': _rezkaId,
            'order_id': order,
            'rezka_output_report': {
              'cycle_id': cycle,
              'frames': frames,
              'reference_frame_index': fixture.referenceFrameIndex
            },
            'kadr_counts': [1, 1, 1, 1],
            'session_status': 'active',
            'order_control': 'active',
            'epoch': 'deviation-test',
            'rev': 1,
          }),
          200);
    }
    if (request.url.path.endsWith('/order-scan-bootstrap'))
      return http.Response('', 404);
    if (request.method == 'GET') {
      return http.Response(
          jsonEncode(_rezkaAutofillSnapshot(order, cycle, frames)), 200);
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.url.path.endsWith('/queue-action')) {
      final index = body['rezka_record_frame_index'] as int?;
      if (index == null) {
        fixture.finalActions.add(body);
        return http.Response('{"error":"store_failed"}', 500);
      }
      fixture.saves.add(body);
      expect(frames.any((frame) => frame['frame_index'] == index), isFalse);
      frames.add({
        'frame_index': index,
        'batch_id': 'deviation-roll-$index',
        'qr_payload': 'QR-deviation-$index',
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
              }
            },
          }),
          200);
    }
    expect(request.url.path, endsWith('/progress-qr/reprint'));
    fixture.reprints++;
    final block = fixture.nextReprintBlock;
    fixture.nextReprintBlock = null;
    if (block != null) await block.future;
    return http.Response(
        jsonEncode({
          'ok': true,
          'batch': {
            'id': body['progress_batch_id'],
            'apparatus': _rezkaId,
            'order_id': order,
            'qr_payload': body['qr_payload'],
          }
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
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
          progressDriverUrlPicker: (_) async {
            fixture.printerSelections++;
            return 'http://printer.test';
          }),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rezka'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worker-order-$order')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rulonni yechish'));
    await tester.pumpAndSettle();
    await TestModeController.instance.setEnabled(false);
    await run(fixture);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, () => client);
}
