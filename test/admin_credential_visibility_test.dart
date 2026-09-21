import 'package:accord_mobile_v2/src/features/admin/presentation/admin_customer_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin can reopen and copy the saved code without regeneration',
      (tester) async {
    var stored = const AdminCustomerDetail(
      ref: 'customer',
      name: 'Customer',
      phone: '+998901234567',
      avatarUrl: '',
      code: '301234567890',
      codeLocked: true,
      codeRetryAfterSec: 0,
      assignedItems: [],
    );
    String? clipboard;
    var regenerations = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
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
            codeRegenerator: (_) async {
              regenerations++;
              stored = stored.copyWith(code: '309876543210');
              return stored;
            },
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
    expect(find.text('301234567890'), findsOneWidget);
    expect(regenerations, 0);
    Future<void> copyVisibleCode() async {
      tester
          .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.content_copy_outlined))
          .onPressed!();
      await tester.pump();
    }

    await copyVisibleCode();
    expect(clipboard, '301234567890');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(subject());
    await expand();
    expect(find.text('301234567890'), findsOneWidget);
    await copyVisibleCode();
    expect(clipboard, '301234567890');
    expect(regenerations, 0);
    // A stale backend cooldown must not disable the administrator's button.
    tester
        .widget<IconButton>(
            find.byKey(const ValueKey('admin-customer-detail-code-regenerate')))
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('309876543210'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(subject());
    await expand();
    expect(find.text('309876543210'), findsOneWidget);
    await copyVisibleCode();
    expect(clipboard, '309876543210');
    expect(regenerations, 1);
    expect(tester.takeException(), isNull);
  });
}
