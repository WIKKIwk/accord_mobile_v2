import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(true);
  });
  tearDown(() async => TestModeController.instance.setEnabled(false));

  final log = <String, dynamic>{
    'event_id': 'issue-cycle',
    'apparatus': 'apparatus:default:asset-010',
    'order_id': 'zakaz-issue-only',
    'action': 'complete',
    'from_state': 'in_progress',
    'to_state': 'completed',
    'actor_display_name': 'Waste worker',
    'created_at_unix': 123,
    'zero_output_waste': {'total_waste': 2.5, 'rezka_edge_waste': 0.5},
  };

  test('zero-output history parses finite accounting without inventing output',
      () {
    final parsed = AdminProductionOrderLogEntry.fromJson(log);
    expect(
        parsed.zeroOutputWaste, {'total_waste': 2.5, 'rezka_edge_waste': 0.5});
    expect(
        AdminProductionOrderLogEntry.fromJson({
          ...log,
          'zero_output_waste': {
            'total_waste': double.nan,
            'rezka_edge_waste': -1,
            'untrusted': 100,
          }
        }).zeroOutputWaste,
        isEmpty);
    expect(
        AdminProductionOrderLogEntry.fromJson(
            {...log, 'zero_output_waste': null}).zeroOutputWaste,
        isEmpty);
  });

  testWidgets('closed issue-only history displays waste without a fake WIP',
      (tester) async {
    final order = AdminClosedProductionOrder.fromJson({
      'order_id': 'zakaz-issue-only',
      'order_number': '0199',
      'title': 'Issue-only order',
      'product_code': 'ISSUE',
      'logs': [log],
      'progress_batches': [],
      'completed_at_unix': 123,
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
          closedOrdersLoader: () async => [order]),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yopilgan'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Issue-only order'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Waste worker').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('2.5'), findsOneWidget);
    expect(find.textContaining('0.5'), findsOneWidget);
    expect(order.progressBatches, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
