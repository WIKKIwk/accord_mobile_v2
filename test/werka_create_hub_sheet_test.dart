import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_create_hub_sheet.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/widgets/werka_create_hub_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openHub(WidgetTester tester) async {
  await tester.runAsync(() async {
    await GlobalMaterialLocalizations.delegate.load(const Locale('uz'));
    await GlobalCupertinoLocalizations.delegate.load(const Locale('uz'));
  });
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('uz'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text(settings.name!))),
    home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () => showWerkaCreateHubSheet(context),
                  child: const Text('Open'),
                ))),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Werka reuses shared FAB, open state and role-specific actions',
      (tester) async {
    expect(identical(werkaCreateHubMenuOpen, adminCreateHubMenuOpen), isTrue);
    await openHub(tester);
    expect(werkaCreateHubMenuOpen.value, isTrue);
    expect(
        find.byKey(const ValueKey('admin-hub-toggle-button')), findsOneWidget);
    for (final label in ['Paddon kirimi', 'Aytilmagan mahsulot', 'Stock QR']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Mahsulot qo‘shish'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('admin-hub-toggle-button')));
    await tester.pumpAndSettle();
    expect(werkaCreateHubMenuOpen.value, isFalse);
  });

  testWidgets('Werka shared FAB opens pallet receipt', (tester) async {
    await openHub(tester);
    await tester.tap(find.text('Paddon kirimi'));
    await tester.pumpAndSettle();
    expect(find.text(AppRoutes.werkaPaddonReceive), findsOneWidget);
    expect(werkaCreateHubMenuOpen.value, isFalse);
  });

  testWidgets('Werka shared FAB retains legacy stock scanning', (tester) async {
    await openHub(tester);
    await tester.tap(find.text('Stock QR'));
    await tester.pumpAndSettle();
    expect(find.text(AppRoutes.werkaStockEntryQrScan), findsOneWidget);
  });
}
