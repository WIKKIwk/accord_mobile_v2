import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_qr_preview_screen.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/widgets/werka_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _receipt = <String, dynamic>{
  'warehouse': 'WH-1',
  'accepted_by_display_name': 'Omborchi',
  'accepted_at_unix': 1700000000,
};
WerkaWipPreview _preview({
  bool eligible = true,
  String status = 'waiting',
  String token = 'snapshot-1',
  List<String> warehouses = const ['WH-1'],
  Map<String, dynamic>? receipt,
}) =>
    WerkaWipPreview.fromJson({
      'batch': {
        'batch_id': 'wip-1',
        'apparatus': 'apparatus:default:asset-010',
        'qr_payload': 'QR-wip-1',
        'order_id': 'order-1',
        'label_item_name': 'Mahsulot',
        'wip_status': status,
        'finished_goods_kg': 12.125,
        'finished_goods_meter': 400,
        'current_location': receipt == null ? 'Rezka 1' : 'WH-1',
        'worker_display_name': 'Ishchi',
      },
      'warehouses': warehouses,
      'can_receive': eligible,
      'snapshot_token': token,
      'receipt': receipt,
    });

Future<void> _show(
  WidgetTester tester, {
  WerkaWipPreview? preview,
  Future<WerkaQrPreview> Function(String)? load,
  Future<Map<String, dynamic>> Function(WerkaWipPreview, String)? receive,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() async {
    await GlobalMaterialLocalizations.delegate.load(const Locale('uz'));
    await GlobalCupertinoLocalizations.delegate.load(const Locale('uz'));
  });
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('uz'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ],
    home: WerkaWipPreviewScreen(
        code: 'QR-wip-1',
        initialPreview: preview ?? _preview(),
        loadPreview: load,
        receive: receive),
  ));
  await tester.pumpAndSettle();
}

Finder get _accept => find.byKey(const ValueKey('werka-wip-receive'));
Finder get _confirm => find.byKey(const ValueKey('werka-wip-confirm'));
Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(_accept);
  await tester.tap(_accept);
  await tester.pumpAndSettle();
  await tester.tap(_confirm);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening WIP and cancelling confirmation performs no write',
      (tester) async {
    var writes = 0;
    await _show(tester, receive: (_, __) async {
      writes++;
      return _receipt;
    });
    expect(writes, 0);
    expect(find.text('12.125 kg • 400 m'), findsOneWidget);
    expect(find.text('Buyurtma: order-1'), findsOneWidget);
    await tester.tap(_accept);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(tester.widget<FilledButton>(_accept).onPressed, isNotNull);
  });

  testWidgets('double taps use one snapshot and one receipt', (tester) async {
    final completion = Completer<Map<String, dynamic>>();
    var writes = 0;
    await _show(tester, receive: (preview, warehouse) {
      writes++;
      expectSync(preview.snapshotToken, 'snapshot-1');
      expectSync(warehouse, 'WH-1');
      return completion.future;
    });
    final action = tester.widget<FilledButton>(_accept).onPressed!;
    action();
    action();
    await tester.pumpAndSettle();
    expect(_confirm, findsOneWidget);
    await tester.tap(_confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    action();
    expect(writes, 1);
    expect(find.byKey(const ValueKey('werka-wip-error')), findsNothing,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '));
    expect(tester.widget<FilledButton>(_accept).onPressed, isNull);
    expect(
        tester
            .widget<PopScope>(find.byKey(const ValueKey('werka-wip-pop-guard')))
            .canPop,
        isFalse);
    expect(find.byType(WerkaDock), findsNothing);
    completion.complete(_receipt);
    await tester.pumpAndSettle();
    expect(find.byType(WerkaDock), findsOneWidget);
    expect(find.byKey(const ValueKey('werka-wip-received')), findsOneWidget);
    expect(_accept, findsNothing);
    action();
    expect(writes, 1);
  });

  for (final status in ['in_use', 'processed']) {
    testWidgets('$status WIP remains read-only', (tester) async {
      await _show(tester, preview: _preview(status: status, eligible: false));
      expect(tester.widget<FilledButton>(_accept).onPressed, isNull);
      expect(
          find.text(status == 'in_use'
              ? 'WIP hozir ishlatilmoqda. Kirim mumkin emas.'
              : 'WIP avval ishlatilgan. Kirim mumkin emas.'),
          findsOneWidget);
    });
  }

  testWidgets('received WIP displays receipt and no second receive',
      (tester) async {
    await _show(tester,
        preview:
            _preview(receipt: _receipt, eligible: false, status: 'processed'));
    expect(find.byKey(const ValueKey('werka-wip-received')), findsOneWidget);
    expect(find.text('Ombor: WH-1'), findsOneWidget);
    expect(_accept, findsNothing);
  });

  testWidgets('missing snapshot token disables receive', (tester) async {
    await _show(tester, preview: _preview(token: ''));
    expect(tester.widget<FilledButton>(_accept).onPressed, isNull);
  });

  testWidgets(
      'warehouse must be explicitly selected when more than one assigned',
      (tester) async {
    await _show(tester, preview: _preview(warehouses: ['WH-1', 'WH-2']));
    expect(tester.widget<FilledButton>(_accept).onPressed, isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WH-2').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(_accept).onPressed, isNotNull);
  });

  testWidgets(
      'lost receipt response requires GET recovery and never repeats POST',
      (tester) async {
    var writes = 0, reads = 0;
    await _show(tester, receive: (_, __) async {
      writes++;
      throw TimeoutException('response lost');
    }, load: (code) async {
      reads++;
      expectSync(code, 'QR-wip-1');
      return WerkaQrPreview(
          code: code,
          wip: _preview(
              eligible: false, receipt: _receipt, status: 'processed'));
    });
    await _submit(tester);
    expect(writes, 1);
    expect(tester.widget<FilledButton>(_accept).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('werka-wip-reload')));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(writes, 1);
    expect(find.byKey(const ValueKey('werka-wip-received')), findsOneWidget);
    expect(_accept, findsNothing);
  });

  testWidgets(
      'conflict then failed refresh stays disabled until fresh snapshot',
      (tester) async {
    var writes = 0, reads = 0;
    await _show(tester, receive: (p, _) async {
      writes++;
      if (writes == 1) {
        throw const MobileApiException(
            code: 'wip_receipt_conflict', message: '');
      }
      expectSync(p.snapshotToken, 'snapshot-2');
      return _receipt;
    }, load: (code) async {
      if (++reads == 1) {
        throw const MobileApiException(code: 'forbidden', message: '');
      }
      return WerkaQrPreview(code: code, wip: _preview(token: 'snapshot-2'));
    });
    await _submit(tester);
    expect(tester.widget<FilledButton>(_accept).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('werka-wip-reload')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(_accept).onPressed, isNull);
    expect(find.text('Bu amalga yoki omborga ruxsat yo‘q.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('werka-wip-reload')));
    await tester.pumpAndSettle();
    expect(writes, 1);
    await _submit(tester);
    expect(writes, 2);
  });

  testWidgets('leaving while receipt is pending never applies a late update',
      (tester) async {
    final completion = Completer<Map<String, dynamic>>();
    var writes = 0;
    await _show(tester, receive: (_, __) {
      writes++;
      return completion.future;
    });
    await tester.tap(_accept);
    await tester.pumpAndSettle();
    await tester.tap(_confirm);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    completion.complete(_receipt);
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(tester.takeException(), isNull);
  });
}
