import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/formatters/date_time_formatters.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_item_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('shows full item details and edits name and code',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const createdAtUnix = 1720000000;
    String? receivedOriginalCode;
    String? receivedCode;
    String? receivedName;
    const initial = AdminItemDetail(
      code: 'ITEM-001',
      name: 'Finished product',
      uom: 'Dona',
      itemGroup: 'Tayyor mahsulot / Paket',
      isFinishedGoods: true,
      createdAtUnix: createdAtUnix,
      updatedAtUnix: createdAtUnix + 60,
      customers: [
        CustomerDirectoryEntry(
          ref: 'CUST-001',
          name: 'Customer One',
          phone: '+998901234567',
        ),
      ],
    );

    Future<AdminItemDetail> updateItem({
      required String originalCode,
      required String code,
      required String name,
    }) async {
      receivedOriginalCode = originalCode;
      receivedCode = code;
      receivedName = name;
      return AdminItemDetail(
        code: code,
        name: name,
        uom: initial.uom,
        itemGroup: initial.itemGroup,
        isFinishedGoods: true,
        createdAtUnix: initial.createdAtUnix,
        updatedAtUnix: initial.updatedAtUnix + 60,
        customers: initial.customers,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminItemDetailScreen(
          itemCode: initial.code,
          loadDetail: (_) async => initial,
          updateItem: updateItem,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finished product'), findsWidgets);
    expect(find.text('ITEM-001'), findsWidgets);
    expect(find.text('Tayyor mahsulot / Paket'), findsOneWidget);
    expect(find.text('Ombor'), findsNothing);
    expect(
      find.text(formatUnixSecondsLocalDateTime(createdAtUnix)),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Customer One'), 260);
    expect(find.text('Customer One'), findsOneWidget);
    expect(find.text('CUST-001 • +998901234567'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('admin-item-detail-edit')),
      -260,
    );
    await tester.tap(
      find.byKey(const ValueKey('admin-item-detail-edit')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-item-detail-code-field')),
      'ITEM-NEW',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-item-detail-name-field')),
      'Updated product',
    );
    await tester.tap(find.byKey(const ValueKey('admin-item-detail-save')));
    await tester.pumpAndSettle();

    expect(receivedOriginalCode, 'ITEM-001');
    expect(receivedCode, 'ITEM-NEW');
    expect(receivedName, 'Updated product');
    expect(find.text('ITEM-NEW'), findsWidgets);
    expect(find.text('Updated product'), findsWidgets);
    expect(find.text('Item ma’lumotlari saqlandi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changes item group and refreshes finished goods state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const initial = AdminItemDetail(
      code: 'ITEM-RAW',
      name: 'Raw item',
      uom: 'Kg',
      itemGroup: 'Hom ashyo',
      isFinishedGoods: false,
      createdAtUnix: 1720000000,
      updatedAtUnix: 1720000000,
    );
    String? receivedCode;
    String? receivedGroup;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminItemDetailScreen(
          itemCode: initial.code,
          loadDetail: (_) async => initial,
          loadItemGroups: () async => const [
            'Hom ashyo',
            'Tayyor mahsulot / Paket',
          ],
          updateItemGroup: ({
            required String itemCode,
            required String itemGroup,
          }) async {
            receivedCode = itemCode;
            receivedGroup = itemGroup;
            return initial.copyWith(
              itemGroup: itemGroup,
              isFinishedGoods: true,
              updatedAtUnix: initial.updatedAtUnix + 60,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final changeGroup =
        find.byKey(const ValueKey('admin-item-detail-change-group'));
    await tester.ensureVisible(changeGroup);
    await tester.tap(changeGroup);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey(
          'admin-item-group-option-Tayyor mahsulot / Paket',
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('admin-item-group-apply')));
    await tester.pumpAndSettle();

    expect(receivedCode, 'ITEM-RAW');
    expect(receivedGroup, 'Tayyor mahsulot / Paket');
    expect(find.text('Tayyor mahsulot / Paket'), findsOneWidget);
    expect(find.text('Item group o‘zgartirildi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('admin-item-detail-manage-customers')),
      260,
    );
    expect(
      find.byKey(const ValueKey('admin-item-detail-manage-customers')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('links and unlinks a customer from finished item',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const customer = CustomerDirectoryEntry(
      ref: 'CUST-002',
      name: 'Customer Two',
      phone: '+998909876543',
    );
    var current = const AdminItemDetail(
      code: 'ITEM-FG',
      name: 'Finished item',
      uom: 'Dona',
      itemGroup: 'Tayyor mahsulot',
      isFinishedGoods: true,
      createdAtUnix: 1720000000,
      updatedAtUnix: 1720000000,
    );
    final assignments = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminItemDetailScreen(
          itemCode: current.code,
          loadDetail: (_) async => current,
          loadCustomers: ({
            String query = '',
            int limit = 20,
            int offset = 0,
          }) async =>
              const [customer],
          updateItemCustomer: ({
            required String itemCode,
            required CustomerDirectoryEntry customer,
            required bool assigned,
          }) async {
            expect(itemCode, 'ITEM-FG');
            assignments.add(assigned);
            current = current.copyWith(
              customers:
                  assigned ? <CustomerDirectoryEntry>[customer] : const [],
              updatedAtUnix: current.updatedAtUnix + 1,
            );
            return current;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final manage = find.byKey(
      const ValueKey('admin-item-detail-manage-customers'),
      skipOffstage: false,
    );
    await tester.ensureVisible(manage);
    await tester.pumpAndSettle();
    await tester.tap(manage);
    await tester.pumpAndSettle();
    final customerOption =
        find.byKey(const ValueKey('admin-item-customer-option-CUST-002'));
    await tester.tap(customerOption);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-item-customer-done')));
    await tester.pumpAndSettle();

    expect(assignments, const [true]);
    expect(find.text('Customer Two', skipOffstage: false), findsOneWidget);

    await tester.ensureVisible(manage);
    await tester.pumpAndSettle();
    await tester.tap(manage);
    await tester.pumpAndSettle();
    await tester.tap(customerOption);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-item-customer-done')));
    await tester.pumpAndSettle();

    expect(assignments, const [true, false]);
    expect(
      find.text('Biriktirilmagan', skipOffstage: false),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('asks for confirmation and deletes an unused item',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const item = AdminItemDetail(
      code: 'ITEM-DELETE',
      name: 'Unused item',
      uom: 'Kg',
      itemGroup: 'Hom ashyo',
      isFinishedGoods: false,
      createdAtUnix: 1720000000,
      updatedAtUnix: 1720000000,
    );
    var deleteCalls = 0;
    String? deletedCode;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: '/detail',
        routes: {
          '/': (_) => const Scaffold(body: Text('Itemlar ro‘yxati')),
          '/detail': (_) => AdminItemDetailScreen(
                itemCode: item.code,
                loadDetail: (_) async => item,
                deleteItem: (code) async {
                  deleteCalls += 1;
                  deletedCode = code;
                },
              ),
        },
      ),
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(const ValueKey('admin-item-detail-delete'));
    await Scrollable.ensureVisible(
      tester.element(deleteButton),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Itemni o‘chirish'), findsWidgets);
    expect(find.textContaining('ITEM-DELETE) itemini'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('admin-item-delete-cancel')));
    await tester.pumpAndSettle();
    expect(deleteCalls, 0);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-item-delete-confirm')));
    await tester.pumpAndSettle();

    expect(deleteCalls, 1);
    expect(deletedCode, 'ITEM-DELETE');
    expect(find.text('Itemlar ro‘yxati'), findsOneWidget);
    expect(find.text('Item o‘chirildi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps item detail open when backend blocks deletion',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const item = AdminItemDetail(
      code: 'ITEM-ACTIVE',
      name: 'Active item',
      uom: 'Kg',
      itemGroup: 'Hom ashyo',
      isFinishedGoods: false,
      createdAtUnix: 1720000000,
      updatedAtUnix: 1720000000,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminItemDetailScreen(
          itemCode: item.code,
          loadDetail: (_) async => item,
          deleteItem: (_) async {
            throw const MobileApiException(
              code: 'item is used by active order',
              message: 'Item faol buyurtmada ishlatilgan',
              statusCode: 409,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(const ValueKey('admin-item-detail-delete'));
    await Scrollable.ensureVisible(
      tester.element(deleteButton),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-item-delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Item faol buyurtmada ishlatilgan'), findsOneWidget);
    expect(find.text('Active item'), findsWidgets);
    expect(deleteButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
