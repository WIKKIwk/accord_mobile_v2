import 'package:accord_mobile_v2/src/features/admin/presentation/admin_customer_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_dock.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin customer detail renders loaded content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminCustomerDetailScreen(
          customerRef: 'comfi',
          detailLoader: (_) async => const AdminCustomerDetail(
            ref: 'comfi',
            name: 'comfi',
            phone: '+998901000333',
            code: '30SFT8WLPTR9',
            codeLocked: false,
            codeRetryAfterSec: 0,
            assignedItems: [],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.byType(AdminDock), findsOneWidget);
    expect(find.text('comfi'), findsWidgets);
    expect(find.text('+998901000333'), findsOneWidget);
    expect(find.text('Ref'), findsNothing);
    expect(find.text('Admin boshqaruv'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('admin-customer-detail-admin-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Admin boshqaruv'), findsOneWidget);
    expect(find.text('30SFT8WLPTR9'), findsOneWidget);
    tester
        .widget<IconButton>(
          find.byKey(const ValueKey('admin-customer-detail-phone-action')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.byKey(const ValueKey('admin-customer-detail-phone-input')),
      findsOneWidget,
    );
  });

  testWidgets('admin customer detail renders with semantics enabled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminCustomerDetailScreen(
          customerRef: 'comfi',
          detailLoader: (_) async => const AdminCustomerDetail(
            ref: 'comfi',
            name: 'comfi',
            phone: '+998901000333',
            code: '30SFT8WLPTR9',
            codeLocked: false,
            codeRetryAfterSec: 0,
            assignedItems: [],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(find.text('comfi'), findsWidgets);
    expect(find.text('+998901000333'), findsOneWidget);
    semantics.dispose();
  });
}
