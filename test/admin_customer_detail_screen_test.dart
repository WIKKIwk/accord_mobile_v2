import 'package:accord_mobile_v2/src/features/admin/presentation/admin_customer_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_dock.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('customer detail shows direct chat action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminCustomerDetailScreen(
          customerRef: 'CUSTOMER-001',
          chatTarget: const ChatDirectoryEntry(
            role: UserRole.customer,
            ref: 'CUSTOMER-001',
            displayName: 'Customer',
            avatarUrl: '',
          ),
          detailLoader: (_) async => const AdminCustomerDetail(
            ref: 'CUSTOMER-001',
            name: 'Customer',
            phone: '+998901234567',
            avatarUrl: '',
            code: '',
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

    expect(
      find.byKey(const ValueKey('admin-customer-detail-chat-action')),
      findsOneWidget,
    );
  });

  testWidgets('material detail shows direct chat action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminCustomerDetailScreen(
          customerRef: 'MAT-001',
          isMaterialTaminotchi: true,
          chatTarget: const ChatDirectoryEntry(
            role: UserRole.materialTaminotchi,
            ref: 'MAT-001',
            displayName: 'Materialchi',
            avatarUrl: '',
          ),
          detailLoader: (_) async => const AdminCustomerDetail(
            ref: 'MAT-001',
            name: 'Materialchi',
            phone: '+998901234567',
            avatarUrl: '',
            code: '',
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

    expect(
      find.byKey(const ValueKey('admin-customer-detail-chat-action')),
      findsOneWidget,
    );
    expect(find.text('Xabar yozish'), findsOneWidget);
  });

  testWidgets('admin customer detail renders loaded content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminCustomerDetailScreen(
          customerRef: 'comfi',
          customerManagementEnabled: true,
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
          isMaterialTaminotchi: true,
          detailLoader: (_) async => const AdminCustomerDetail(
            ref: 'MAT-001',
            name: 'Materialchi',
            phone: '+998901000333',
            avatarUrl: '',
            code: '70ABCDEF1234',
            codeLocked: false,
            codeRetryAfterSec: 0,
            assignedItems: [],
            assignedItemGroups: ['Rulon'],
            assignedWarehouses: ['Kalidor'],
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
    expect(find.text('Mahsulot guruhlari'), findsOneWidget);
    expect(find.text('Biriktirilgan omborlar'), findsOneWidget);
    expect(find.text('Rulon'), findsOneWidget);
    expect(find.text('Kalidor'), findsOneWidget);
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

  testWidgets('admin edits material item groups and warehouse scope', (
    tester,
  ) async {
    var savedGroups = <String>[];
    String? assignedWarehouse;
    String? removedWarehouse;

    AdminCustomerDetail detail({
      List<String> groups = const ['Rulon'],
      List<String> warehouses = const ['Kalidor'],
    }) {
      return AdminCustomerDetail(
        ref: 'MAT-EDIT',
        name: 'Materialchi',
        phone: '+998901000333',
        avatarUrl: '',
        code: '70ABCDEF1234',
        codeLocked: false,
        codeRetryAfterSec: 0,
        assignedItems: const [],
        assignedItemGroups: groups,
        assignedWarehouses: warehouses,
      );
    }

    var serverDetail = detail();

    Widget subject() {
      return MaterialApp(
        home: AdminCustomerDetailScreen(
          key: UniqueKey(),
          customerRef: 'MAT-EDIT',
          title: 'Material taminotchisi',
          profileSubtitle: 'Material ta’minotchisi profili',
          customerManagementEnabled: true,
          itemManagementEnabled: false,
          removeEnabled: false,
          isMaterialTaminotchi: true,
          detailLoader: (_) async => serverDetail,
          materialItemGroupsLoader: () async => const ['Rulon', 'Kley'],
          materialItemGroupsUpdater: ({
            required ref,
            required assignedItemGroups,
          }) async {
            savedGroups = assignedItemGroups;
            serverDetail = serverDetail.copyWith(
              assignedItemGroups: assignedItemGroups,
            );
            return serverDetail;
          },
          materialWarehousesLoader: () async => const [
            AdminWarehouse(warehouse: 'Kalidor'),
            AdminWarehouse(warehouse: 'Xomashyo ombori'),
          ],
          materialWarehouseAssigner: ({
            required warehouse,
            required principalRole,
            required principalRef,
            required displayName,
          }) async {
            assignedWarehouse = warehouse;
            serverDetail = serverDetail.copyWith(
              assignedWarehouses: [
                ...serverDetail.assignedWarehouses,
                warehouse,
              ],
            );
            return AdminWarehouseAssignment(
              warehouse: warehouse,
              principalRole: principalRole,
              principalRef: principalRef,
              displayName: displayName,
            );
          },
          materialWarehouseUnassigner: ({
            required warehouse,
            required principalRole,
            required principalRef,
          }) async {
            removedWarehouse = warehouse;
            serverDetail = serverDetail.copyWith(
              assignedWarehouses: serverDetail.assignedWarehouses
                  .where((item) => item != warehouse)
                  .toList(growable: false),
            );
            return AdminWarehouseAssignment(
              warehouse: warehouse,
              principalRole: principalRole,
              principalRef: principalRef,
              displayName: 'Materialchi',
            );
          },
        ),
      );
    }

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('admin-customer-detail-admin-toggle')),
    );
    await tester.pumpAndSettle();

    final editGroups =
        find.byKey(const ValueKey('admin-material-detail-edit-item-groups'));
    await tester.drag(
      find.byKey(const ValueKey('admin-customer-detail-scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(editGroups);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.byKey(const ValueKey('admin-material-item-group-kley')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('admin-material-item-groups-save')),
    );
    await tester.pumpAndSettle();

    expect(savedGroups, ['Kley', 'Rulon']);
    expect(find.text('Kley'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    final addWarehouse =
        find.byKey(const ValueKey('admin-material-detail-add-warehouse'));
    await tester.drag(
      find.byKey(const ValueKey('admin-customer-detail-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(addWarehouse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Xomashyo ombori').last);
    await tester.pump();

    expect(assignedWarehouse, isNull);
    final confirmWarehouse =
        find.byKey(const ValueKey('admin-material-warehouse-confirm'));
    expect(confirmWarehouse, findsOneWidget);
    await tester.tap(confirmWarehouse);
    await tester.pumpAndSettle();

    expect(assignedWarehouse, 'Xomashyo ombori');
    expect(find.text('Xomashyo ombori'), findsOneWidget);

    final kalidorChip = tester.widget<InputChip>(
      find.byKey(const ValueKey('admin-material-detail-warehouse-Kalidor')),
    );
    kalidorChip.onDeleted!();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ha'));
    await tester.pumpAndSettle();

    expect(removedWarehouse, 'Kalidor');
    expect(
      find.byKey(const ValueKey('admin-material-detail-warehouse-Kalidor')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('2 ta guruh'), findsOneWidget);
    expect(find.text('1 ta ombor'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('admin-customer-detail-admin-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kley'), findsOneWidget);
    expect(find.text('Xomashyo ombori'), findsOneWidget);
    expect(find.text('Kalidor'), findsNothing);
  });

  testWidgets('read-only user sees material card without admin expansion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminCustomerDetailScreen(
          customerRef: 'MAT-READ',
          isMaterialTaminotchi: true,
          customerManagementEnabled: false,
          itemManagementEnabled: false,
          removeEnabled: false,
          detailLoader: (_) async => const AdminCustomerDetail(
            ref: 'MAT-READ',
            name: 'Materialchi',
            phone: '+998901000333',
            avatarUrl: '',
            code: '',
            codeLocked: false,
            codeRetryAfterSec: 0,
            assignedItems: [],
            assignedItemGroups: ['Rulon'],
            assignedWarehouses: ['Kalidor'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Materialchi'), findsWidgets);
    expect(
      find.byKey(const ValueKey('admin-customer-detail-admin-toggle')),
      findsNothing,
    );
    expect(find.text('Admin boshqaruv'), findsNothing);
    expect(find.text('Mahsulot guruhlari'), findsNothing);
  });

  test('material detail parses assigned scopes', () {
    final detail = AdminCustomerDetail.fromJson({
      'ref': 'MAT-JSON',
      'name': 'Materialchi',
      'assigned_items': const [],
      'assigned_item_groups': const ['Rulon', 'Kley'],
      'assigned_warehouses': const ['Kalidor'],
    });

    expect(detail.assignedItemGroups, ['Rulon', 'Kley']);
    expect(detail.assignedWarehouses, ['Kalidor']);
  });
}
