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
            avatarUrl: '',
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
    await tester.pump(const Duration(milliseconds: 250));
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
            avatarUrl: '',
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

  testWidgets('material taminotchi detail keeps phone and code controls', (
    tester,
  ) async {
    String? savedPhone;
    var codeRegenerated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AdminCustomerDetailScreen(
          customerRef: 'MAT-001',
          title: 'Material taminotchisi',
          profileSubtitle: 'Material ta’minotchisi profili',
          emptyName: 'Material taminotchisi',
          namelessLabel: 'Nomsiz material ta’minotchisi',
          customerManagementEnabled: true,
          itemManagementEnabled: false,
          removeEnabled: false,
          detailLoader: (_) async => const AdminCustomerDetail(
            ref: 'MAT-001',
            name: 'Materialchi',
            phone: '+998901000333',
            avatarUrl: '',
            code: '70ABCDEF1234',
            codeLocked: false,
            codeRetryAfterSec: 0,
            assignedItems: [],
          ),
          phoneUpdater: ({required phone, required ref}) async {
            savedPhone = phone;
            return AdminCustomerDetail(
              ref: ref,
              name: 'Materialchi',
              phone: phone,
              avatarUrl: '',
              code: '70ABCDEF1234',
              codeLocked: false,
              codeRetryAfterSec: 0,
              assignedItems: const [],
            );
          },
          codeRegenerator: (ref) async {
            codeRegenerated = true;
            return AdminCustomerDetail(
              ref: ref,
              name: 'Materialchi',
              phone: '+998901000333',
              avatarUrl: '',
              code: '70ZZZZZZZZZZ',
              codeLocked: false,
              codeRetryAfterSec: 0,
              assignedItems: const [],
            );
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(
      find.byKey(const ValueKey('admin-customer-detail-admin-toggle')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Admin boshqaruv'), findsOneWidget);
    expect(find.text('70ABCDEF1234'), findsOneWidget);
    expect(find.text('Biriktirilgan mahsulotlar'), findsNothing);
    expect(find.text('Tizimdan chiqarish'), findsNothing);

    tester
        .widget<IconButton>(
          find.byKey(const ValueKey('admin-customer-detail-phone-action')),
        )
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(
      find.byKey(const ValueKey('admin-customer-detail-phone-input')),
      '+998909999999',
    );
    tester
        .widget<IconButton>(
          find.byKey(const ValueKey('admin-customer-detail-phone-action')),
        )
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 250));
    expect(savedPhone, '+998909999999');
    expect(find.text('+998909999999'), findsWidgets);

    tester
        .widget<IconButton>(
          find.byKey(const ValueKey('admin-customer-detail-code-regenerate')),
        )
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 250));
    expect(codeRegenerated, isTrue);
    expect(find.text('70ZZZZZZZZZZ'), findsOneWidget);
  });
}
