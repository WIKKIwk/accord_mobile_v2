import 'package:accord_mobile_v2/src/features/admin/presentation/admin_customer_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('issued code disappears when the profile is reopened',
      (tester) async {
    const stored = AdminCustomerDetail(
      ref: 'customer',
      name: 'Customer',
      phone: '+998901234567',
      avatarUrl: '',
      code: '',
      codeLocked: false,
      codeRetryAfterSec: 0,
      assignedItems: [],
    );
    Widget subject() => MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AdminCustomerDetailScreen(
            key: UniqueKey(),
            customerRef: 'customer',
            customerManagementEnabled: true,
            detailLoader: (_) async => stored,
            codeRegenerator: (_) async => stored.copyWith(code: '301234567890'),
          ),
        );
    Future<void> expand() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
          find.byKey(const ValueKey('admin-customer-detail-admin-toggle')));
      await tester.pump(const Duration(milliseconds: 500));
    }

    await tester.pumpWidget(subject());
    await expand();
    expect(find.text('Saqlangan kod ko‘rsatilmaydi'), findsOneWidget);
    tester
        .widget<IconButton>(
            find.byKey(const ValueKey('admin-customer-detail-code-regenerate')))
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('301234567890'), findsOneWidget);
    expect(
        find.text(
            'Yangi kodni hozir nusxalab oling. Sahifa qayta ochilganda ko‘rsatilmaydi.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(subject());
    await expand();
    expect(find.text('301234567890'), findsNothing);
    expect(find.text('Saqlangan kod ko‘rsatilmaydi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
