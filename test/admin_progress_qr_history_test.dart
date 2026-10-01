import 'dart:io';
import 'dart:ui' as ui;

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_history_view.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_passport.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_scan_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _names = {
  'apparatus:default:print': 'Bosma 1',
  'apparatus:default:lam': 'Laminatsiya 1',
  'apparatus:default:cut': 'Rezka 1',
};

void main() {
  test('actual resources use exact scoped sessions and persisted plate lineage',
      () {
    final payload = _chain();
    final report = AdminProgressQrReport.fromJson(payload);
    final passport =
        buildProgressQrPassport(report, apparatusNamesById: _names);
    final text = passport.toPlainText();
    expect(text, contains('PET 12 micron · RAW-001'));
    expect(text, contains('CPP 25 micron · RAW-002'));
    expect(text, contains('PLATE-007'));
    expect(text, isNot(contains('Unrelated material')));
    expect(text, isNot(contains('PLANNED-ONLY')));
    expect(text, isNot(contains('stock:')));
    expect(text, isNot(contains('99999')));
    expect(report.sessionResources.first.rawMaterialsAvailable, isTrue);
    expect(text.indexOf('Ishlatilgan xomashyo'),
        lessThan(text.indexOf('1. Bosma')));
  });

  test(
      'unavailable material entries and legacy full-order resources stay hidden',
      () {
    final payload = _chain();
    payload['session_resources'][0]['raw_materials_available'] = false;
    final scoped =
        buildProgressQrPassport(AdminProgressQrReport.fromJson(payload));
    expect(scoped.toPlainText(), isNot(contains('PET 12 micron')));
    expect(scoped.toPlainText(), contains('Ayrim bosqichlarning'));
    payload.remove('history_scope');
    final legacy =
        buildProgressQrPassport(AdminProgressQrReport.fromJson(payload));
    expect(legacy.toPlainText(), isNot(contains('CPP 25 micron')));
    expect(
        legacy.toPlainText(), contains('Tasdiqlangan ma’lumot qayd etilmagan'));
  });

  test(
      'matching length correction is one fact and divergent fields remain separate',
      () {
    AdminProgressBatchCorrectionRecord correction(
            num before, num after, String uom) =>
        AdminProgressBatchCorrectionRecord.fromJson({
          'old_values': {
            'produced_qty': 15000,
            'finished_goods_meter': before,
            'uom': uom
          },
          'new_values': {
            'produced_qty': 16000,
            'finished_goods_meter': after,
            'uom': uom
          },
        });
    final matching = progressQrCorrectionChanges(correction(15000, 16000, 'm'));
    expect(matching, hasLength(1));
    expect(matching.single.label, 'Metraj (ishlab chiqarilgan va tayyor)');
    expect(matching.single.before, '15 000 m');
    expect(matching.single.after, '16 000 m');
    expect(progressQrCorrectionChanges(correction(14999, 15999, 'm')),
        hasLength(2));
    expect(progressQrCorrectionChanges(correction(15000, 16000, 'kg')),
        hasLength(2));
  });

  test('matching result length renders once without losing either meaning', () {
    final report = AdminProgressQrReport.fromJson(_chain());
    final stage = buildProgressQrPassport(report)
        .stages
        .singleWhere((stage) => stage.batchId == 'cut');
    expect(stage.lines.where((line) => line.value == '1 200 m'), hasLength(1));
    expect(stage.lines.any((line) => line.label == 'Tayyor mahsulot metraji'),
        isFalse);
    expect(
        stage.lines.any(
            (line) => line.label == 'Metraj (ishlab chiqarilgan va tayyor)'),
        isTrue);
  });
  test('lineage contract preserves causal order and exact-session workers', () {
    final report = AdminProgressQrReport.fromJson(_chain());
    final passport =
        buildProgressQrPassport(report, apparatusNamesById: _names);
    expect(report.hasScopedHistory, isTrue);
    expect(
        passport.stages.map((stage) => stage.batchId), ['print', 'lam', 'cut']);
    expect(passport.stages.first.workerNames, ['Ali', 'Vali']);
    expect(passport.stages[1].workerNames, ['Dilshod']);
    expect(passport.stages.where((stage) => stage.isScanned).single.batchId,
        'lam');
    expect(passport.stages.where((stage) => stage.isCurrent).single.batchId,
        'cut');
    expect(
        passport.stages[1].lines.any(
            (line) => line.label == 'Kirish bosqichlari' && line.value == '1'),
        isTrue);
    expect(
        passport.stages[1].lines.any(
            (line) => line.label == 'Chiqish bosqichlari' && line.value == '3'),
        isTrue);
    final exported = passport.toPlainText();
    expect(exported, isNot(contains('apparatus:')));
    expect(exported, isNot(contains('SIBLING-OUTPUT')));
    expect(exported, isNot(contains('Unrelated worker')));
    expect(exported, isNot(contains('99999')));
    expect(exported, contains('Tayyor mahsulot: 98 kg'));
    expect(passport.orderStatus, 'Ish jarayonida');
  });

  test(
      'branch frontiers and merge inputs stay explicit without choosing a sibling',
      () {
    final payload = _chain();
    final extraInput = _batch('merge-input', 'print', 'Hamkor');
    final branch = _batch('cut-2', 'cut', 'Bekzod', finalOutput: true);
    payload['progress_batches'] = [
      extraInput,
      ...payload['progress_batches'],
      branch
    ];
    payload['lineage_edges'] = [
      ...payload['lineage_edges'],
      {'parent_batch_id': 'merge-input', 'child_batch_id': 'lam'},
      {'parent_batch_id': 'lam', 'child_batch_id': 'cut-2'},
    ];
    payload['current_batches'] = [payload['current_batch'], branch];
    payload['current_batch'] = _batch('arbitrary-sibling', 'cut', 'Other');
    final passport = buildProgressQrPassport(
        AdminProgressQrReport.fromJson(payload),
        apparatusNamesById: _names);
    expect(passport.currentBatchStatus, isNull);
    expect(passport.stages.where((stage) => stage.isCurrent).length, 2);
    expect(
        passport.stages.where((stage) => stage.title == 'Rezka 1').length, 2);
    expect(passport.stages.any((stage) => stage.batchId == 'arbitrary-sibling'),
        isFalse);
    final lam = passport.stages.singleWhere((stage) => stage.batchId == 'lam');
    expect(
        lam.lines
            .where((line) => line.label == 'Kirish bosqichlari')
            .single
            .value,
        '1, 2');
    expect(
        lam.lines
            .where((line) => line.label == 'Chiqish bosqichlari')
            .single
            .value,
        '4, 5');
    final merge = lam.lines
        .singleWhere((line) => line.label == 'Birlashtirilgan kirishlar')
        .value;
    expect(merge, contains('PET 12 micron'));
    expect(merge, contains('BOPP 20 micron'));
    expect(merge, isNot(contains('99999')));
    expect(merge, isNot(contains('Unrelated material')));
  });

  test(
      'legacy full-order response cannot leak unrelated batches through UI or PDF',
      () {
    final payload = _chain()..remove('history_scope');
    payload['corrections'] = [
      {
        'batch_id': 'cut',
        'reason': 'UNRELATED-CORRECTION',
        'old_values': {'produced_qty': 99999},
        'new_values': {'produced_qty': 9},
      }
    ];
    final report = AdminProgressQrReport.fromJson(payload);
    final passport =
        buildProgressQrPassport(report, apparatusNamesById: _names);
    expect(passport.stages.map((stage) => stage.batchId), ['lam']);
    expect(passport.currentBatchStatus, isNull);
    expect(passport.stages.single.isCurrent, isFalse);
    expect(passport.isOldQr, isFalse);
    expect(passport.corrections, isEmpty);
    expect(passport.issues, isEmpty);
    expect(passport.historyNotice, isNotEmpty);
    final pdf = String.fromCharCodes(AdminProgressQrScanPdf.buildProgress(
        report,
        apparatusNamesById: _names));
    expect(pdf, isNot(contains('Ali')));
    expect(pdf, isNot(contains('Qobil')));
    expect(pdf, isNot(contains('UNRELATED-CORRECTION')));
    expect(pdf, isNot(contains('99999')));
  });

  test('missing provenance and unknown apparatus never fabricate a stage name',
      () {
    final payload = _chain()..['lineage_complete'] = false;
    final report = AdminProgressQrReport.fromJson(payload);
    final passport = buildProgressQrPassport(report);
    expect(passport.historyNotice, contains('tasdiqlanmagan'));
    expect(
        passport.stages
            .every((stage) => stage.title == 'Apparat nomi ko‘rsatilmagan'),
        isTrue);
    expect(passport.toPlainText(), isNot(contains('apparatus:')));
  });

  test('consumed roll without a verified output has no current frontier', () {
    final payload = _chain()
      ..['lineage_complete'] = false
      ..['current_batches'] = []
      ..['current_batch'] = null;
    final passport = buildProgressQrPassport(
        AdminProgressQrReport.fromJson(payload),
        apparatusNamesById: _names);
    expect(passport.currentBatchStatus, isNull);
    expect(passport.stages.any((stage) => stage.isCurrent), isFalse);
    expect(passport.isOldQr, isFalse);
    expect(passport.historyNotice, isNotEmpty);
  });

  for (final language in ['uz', 'en', 'ru']) {
    testWidgets('selected roll timeline is readable in $language',
        (tester) async {
      final locale = Locale(language);
      const narrowScreenshot =
          String.fromEnvironment('QR_HISTORY_NARROW_SCREENSHOT');
      final isNarrowCapture = narrowScreenshot.isNotEmpty && language == 'uz';
      await tester.binding.setSurfaceSize(
          Size(language == 'ru' || isNarrowCapture ? 360 : 430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        final fontLoader = FontLoader(AppTheme.fontFamily)
          ..addFont(rootBundle
              .load('assets/fonts/google_sans/GoogleSans-Regular.ttf'))
          ..addFont(
              rootBundle.load('assets/fonts/google_sans/GoogleSans-Medium.ttf'))
          ..addFont(
              rootBundle.load('assets/fonts/google_sans/GoogleSans-Bold.ttf'))
          ..addFont(
              rootBundle.load('assets/fonts/google_sans/GoogleSans-Italic.ttf'))
          ..addFont(rootBundle
              .load('assets/fonts/google_sans/GoogleSans-MediumItalic.ttf'))
          ..addFont(rootBundle
              .load('assets/fonts/google_sans/GoogleSans-BoldItalic.ttf'));
        await fontLoader.load();
        await GlobalMaterialLocalizations.delegate.load(locale);
        await GlobalCupertinoLocalizations.delegate.load(locale);
        for (final font in [
          (const String.fromEnvironment('QR_HISTORY_ICONS'), 'MaterialIcons'),
        ]) {
          if (font.$1.isNotEmpty) {
            await (FontLoader(font.$2)
                  ..addFont(File(font.$1)
                      .readAsBytes()
                      .then((bytes) => bytes.buffer.asByteData())))
                .load();
          }
        }
      });
      var shares = 0;
      var scans = 0;
      final theme = AppTheme.dark();
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                  language == 'ru' || isNarrowCapture ? 1.3 : 1)),
          child: RepaintBoundary(
              key: const ValueKey('history-capture'), child: child!),
        ),
        home: Scaffold(
            body: AdminProgressQrHistoryView(
          report: AdminProgressQrReport.fromJson(_chain()),
          apparatusNamesById: _names,
          sharing: false,
          onShare: () => shares++,
          onScanAgain: () => scans++,
        )),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNWidgets(2));
      expect(find.text('Bosma 1'), findsOneWidget);
      expect(find.text('Ali · Vali'), findsOneWidget);
      expect(find.text('Laminatsiya 1'), findsOneWidget);
      expect(find.text('Dilshod'), findsOneWidget);
      expect(find.text('Rezka 1'), findsOneWidget);
      expect(find.text('Qobil'), findsOneWidget);
      expect(find.textContaining('apparatus:'), findsNothing);
      expect(find.textContaining('SIBLING-OUTPUT'), findsNothing);
      expect(find.textContaining('worker.qr.passport.diameter'), findsNothing);
      expect(find.textContaining('PET 12 micron'), findsOneWidget);
      expect(find.textContaining('PLATE-007'), findsOneWidget);
      final worker = tester.getTopLeft(find.text('Ali · Vali'));
      final apparatus = tester.getTopLeft(find.text('Bosma 1'));
      expect(worker.dy, greaterThan(apparatus.dy));
      for (var index = 1; index <= 3; index++) {
        await tester
            .ensureVisible(find.byKey(ValueKey('qr-history-step-$index')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final localeStrings = AppLocalizations(locale);
      await tester.scrollUntilVisible(
          find.text(
              localeStrings.productionText('worker.qr.report.corrections')),
          300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find
          .text(localeStrings.productionText('worker.qr.report.corrections')));
      await tester.pumpAndSettle();
      final change = find.textContaining('15 000 m → 16 000 m');
      expect(change, findsOneWidget);
      await tester.ensureVisible(change);
      await tester.pumpAndSettle();
      const correctionScreenshot =
          String.fromEnvironment('QR_HISTORY_CORRECTION_SCREENSHOT');
      if (correctionScreenshot.isNotEmpty && language == 'uz') {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('history-capture')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(correctionScreenshot)
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      const screenshot = String.fromEnvironment('QR_HISTORY_SCREENSHOT');
      if (screenshot.isNotEmpty && language == 'uz') {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('history-capture')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(screenshot).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      if (isNarrowCapture) {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('history-capture')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(narrowScreenshot)
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.scrollUntilVisible(find.byIcon(Icons.ios_share_rounded), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byIcon(Icons.ios_share_rounded));
      await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
      expect(shares, 1);
      expect(scans, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Map<String, dynamic> _batch(String id, String machine, String worker,
        {bool finalOutput = false}) =>
    {
      'batch_id': id,
      'session_id': 'session-$id',
      'apparatus': 'apparatus:default:$machine',
      'order_id': 'order-0063',
      'label_item_name':
          'Kreko, apparat: apparatus:default:$machine, ish tugatildi',
      'executor_name': worker,
      'worker_display_name': worker,
      'produced_qty': 1200,
      'uom': 'm',
      'qr_payload': '4001$id',
      'started_at_unix': id == 'print' ? 1780000200 : 1780000100,
      'completed_at_unix': 1780000400,
      'status': 'completed',
      'action': 'complete',
      'wip_status': finalOutput ? 'waiting' : 'processed',
      'status_detail': {
        'work_status': 'completed',
        'flow_status': finalOutput ? 'free_wip' : 'consumed_by_next_stage'
      },
      if (finalOutput) 'finished_goods_kg': 98,
      if (finalOutput) 'finished_goods_meter': 1200,
      if (finalOutput) 'diameter': 30,
      'payload_json': {
        'qolip_codes': ['PLATE-007']
      },
    };

Map<String, dynamic> _chain() {
  final printing = _batch('print', 'print', 'Ali');
  final lamination = _batch('lam', 'lam', 'Dilshod');
  final cutting = _batch('cut', 'cut', 'Qobil', finalOutput: true);
  return {
    'history_scope': 'batch_lineage',
    'lineage_complete': true,
    'scanned_batch': lamination,
    'current_batch': cutting,
    'current_batches': [cutting],
    'is_stale': true,
    'progress_batches': [cutting, lamination, printing],
    'lineage_edges': [
      {'parent_batch_id': 'print', 'child_batch_id': 'lam'},
      {'parent_batch_id': 'lam', 'child_batch_id': 'cut'},
    ],
    'order': {
      'id': 'order-0063',
      'order_number': '0063',
      'title': 'Kreko',
      'customer_name': 'Accord',
      'order_kg': 300,
      'nodes': [],
      'edges': []
    },
    'order_status': {'order_status': 'in_progress'},
    'run_sessions': [
      {
        'session_id': 'session-print',
        'apparatus': 'apparatus:default:print',
        'worker_display_name': 'Vali',
        'payload_json': {
          'output_report': {'title': 'SIBLING-OUTPUT', 'qty': 99999}
        }
      },
      {
        'session_id': 'other-session',
        'apparatus': 'apparatus:default:print',
        'worker_display_name': 'Unrelated worker'
      },
    ],
    'session_resources': [
      for (final resource in [
        ('print', 'PET 12 micron', 'RAW-001'),
        ('lam', 'CPP 25 micron', 'RAW-002'),
        ('merge-input', 'BOPP 20 micron', 'RAW-003'),
        ('other', 'Unrelated material', 'RAW-OTHER'),
      ])
        {
          'session_id': 'session-${resource.$1}',
          'raw_materials_available': true,
          'raw_materials': [
            {
              'item_name': resource.$2,
              'barcode': resource.$3,
              'stock_id': 'stock:internal-id',
              'source_qty': 99999,
              'uom': 'kg',
            }
          ],
          'qolip_available': resource.$1 == 'print',
          'qolip_codes': ['PLATE-007'],
        },
    ],
    'corrections': [
      {
        'batch_id': 'print',
        'actor': {'display_name': 'Admin'},
        'reason': 'Metraj aniqlandi',
        'old_values': {
          'produced_qty': 15000,
          'finished_goods_meter': 15000,
          'uom': 'm'
        },
        'new_values': {
          'produced_qty': 16000,
          'finished_goods_meter': 16000,
          'uom': 'm'
        },
      }
    ],
  };
}
