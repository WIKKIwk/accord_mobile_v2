import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_passport.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_scan_pdf.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_scan_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _report(String flow,
    {String orderStatus = 'in_progress'}) {
  final scanned = {
    'batch_id': 'lam-roll',
    'order_id': 'order-0063',
    'apparatus': 'apparatus:default:asset-007',
    'qr_payload': '40010063',
    'produced_qty': 4125,
    'uom': 'm',
    'status': 'completed',
    'wip_status': 'processed',
    'status_detail': {
      'work_status': 'completed',
      'flow_status': 'consumed_by_next_stage'
    },
  };
  final current = {
    'batch_id': 'cut-output',
    'parent_batch_id': 'lam-roll',
    'order_id': 'order-0063',
    'apparatus': 'apparatus:default:asset-014',
    'qr_payload': '4001NEW',
    'status': 'roll_detached',
    'wip_status': flow == 'accepted_to_stock' ? 'processed' : 'waiting',
    'status_detail': {'work_status': 'roll_detached', 'flow_status': flow},
  };
  return {
    'history_scope': 'batch_lineage',
    'lineage_complete': true,
    'lineage_edges': [
      {'parent_batch_id': 'lam-roll', 'child_batch_id': 'cut-output'}
    ],
    'current_batches': [current],
    'scanned_batch': scanned,
    'current_batch': current,
    'is_stale': true,
    'stale_reason': 'processed_by_next_stage',
    'order': {
      'id': 'order-0063',
      'title': 'Kreko',
      'order_number': '0063',
      'nodes': [],
      'edges': []
    },
    if (orderStatus.isNotEmpty)
      'order_status': {
        'order_status': orderStatus,
        'work_status': orderStatus,
        'flow_status': flow,
        'stock_status': flow == 'accepted_to_stock' ? 'accepted' : '',
      },
    'progress_batches': [scanned, current],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final flow in [
    'free_wip',
    'finished_pending_acceptance',
    'accepted_to_stock',
    ''
  ]) {
    for (final orderStatus in ['in_progress', '']) {
      test('QR order status is independent of $flow with order=$orderStatus',
          () {
        final report = AdminProgressQrReport.fromJson(
            _report(flow, orderStatus: orderStatus));
        final passport = buildProgressQrPassport(report);
        expect(
            passport.orderStatus,
            orderStatus.isEmpty
                ? 'Buyurtma holati tasdiqlanmagan'
                : 'Ish jarayonida');
        expect(passport.orderStatus.toLowerCase(), isNot(contains('tugagan')));
        expect(passport.scannedBatchStatus, 'Keyingi bosqichda ishlatilgan');
        expect(passport.isOldQr, isTrue);
        expect(passport.stages.length, 2);
        expect(
            passport.stages.first.lines.any((line) => line.value == '4 125 m'),
            isTrue);
        if (flow == 'free_wip' || flow == 'finished_pending_acceptance') {
          expect(passport.currentBatchStatus,
              'Ushbu rulon omborga qabulni kutmoqda');
        }
        if (flow == 'accepted_to_stock') {
          expect(passport.currentBatchStatus, 'Omborga qabul qilingan');
        }
        expect(passport.toPlainText(),
            isNot(contains('Ishlab chiqarish tugagan')));
        final pdf = utf8.decode(AdminProgressQrScanPdf.buildProgress(report));
        expect(pdf, contains('Buyurtma holati:'));
        expect(pdf, isNot(contains('Ishlab chiqarish tugagan')));
      });
    }
  }
  test('only order completion can label the order completed', () {
    final report = AdminProgressQrReport.fromJson(
        _report('free_wip', orderStatus: 'completed'));
    expect(buildProgressQrPassport(report).orderStatus,
        'Ishlab chiqarish tugagan');
    expect(
        progressQrOrderStatus(const AdminProductionOrderStatusDetail(
            lifecycleStatus: 'cancelled')),
        'Bekor qilingan');
  });
  test('completed roll without order status cannot complete the order', () {
    final data = _report('', orderStatus: '');
    data['current_batch'] = data['scanned_batch'];
    data['current_batches'] = [data['scanned_batch']];
    final passport =
        buildProgressQrPassport(AdminProgressQrReport.fromJson(data));
    expect(passport.orderStatus, 'Buyurtma holati tasdiqlanmagan');
    expect(passport.currentBatchStatus, isNull);
  });

  for (final flow in ['free_wip', 'accepted_to_stock']) {
    testWidgets('QR screen separates order and old roll status for $flow',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AppSession.instance.setSession(
          token: 'test-token',
          profile: const SessionProfile(
            role: UserRole.admin,
            ref: 'admin',
            displayName: 'Admin',
            legalName: '',
            phone: '',
            avatarUrl: '',
          ));
      addTearDown(AppSession.instance.clear);
      await tester.runAsync(() async {
        await GlobalMaterialLocalizations.delegate.load(const Locale('uz'));
        await GlobalCupertinoLocalizations.delegate.load(const Locale('uz'));
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          locale: Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          home: AdminProgressQrScanScreen(),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('QR ni qo‘lda kiritish'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '40010063');
        await tester.tap(find.text('Tekshirish'));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<Text>(
                    find.byKey(const ValueKey('qr-passport-order-status')))
                .data,
            'Zakaz 0063 • Ish jarayonida');
        expect(
            tester
                .widget<Text>(find
                    .byKey(const ValueKey('qr-passport-scanned-batch-status')))
                .data,
            'Skanerlangan rulon: Keyingi bosqichda ishlatilgan');
        expect(find.byKey(const ValueKey('qr-passport-current-batch-status')),
            findsOneWidget);
        expect(find.textContaining('Ishlab chiqarish tugagan'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/progress-qr/report')) {
                  return http.Response(jsonEncode(_report(flow)), 200);
                }
                if (request.url.path.endsWith('/apparatus')) {
                  return http.Response('{"items":[]}', 200);
                }
                return http.Response('{}', 404);
              }));
    }, variant: const TargetPlatformVariant({TargetPlatform.linux}));
  }
}
