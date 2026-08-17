import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_worker_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('worker detail shows direct chat action', (tester) async {
    const entry = AdminUserListEntry(
      id: 'WORKER-001',
      name: 'Aparatchi',
      phone: '+998901234567',
      kind: AdminUserKind.worker,
      principalRole: UserRole.aparatchi,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminWorkerDetailScreen(
          entry: entry,
          chatTarget: const ChatDirectoryEntry(
            role: UserRole.aparatchi,
            ref: 'WORKER-001',
            displayName: 'Aparatchi',
            avatarUrl: '',
          ),
          detailLoader: (_) async => const AdminWorkerDetail(
            id: 'WORKER-001',
            name: 'Aparatchi',
            phone: '+998901234567',
            avatarUrl: '',
            level: 'Aparatchi',
            code: '',
            codeLocked: false,
            codeRetryAfterSec: 0,
          ),
          profileDetailLoader: (_) async => const AdminWorkerProfileDetail(
            worker: AdminWorkerDetail(
              id: 'WORKER-001',
              name: 'Aparatchi',
              phone: '+998901234567',
              avatarUrl: '',
              level: 'Aparatchi',
              code: '',
              codeLocked: false,
              codeRetryAfterSec: 0,
            ),
            assignedApparatus: ['7 ta rangli pechat'],
            assignedGroups: [],
            activeSessions: [],
            recentBatches: [],
            recentLogs: [],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('admin-worker-detail-chat-action')),
      findsOneWidget,
    );
    expect(find.text('Xabar yozish'), findsOneWidget);
    expect(find.text('Ish faoliyati tafsilotlari').last, findsOneWidget);
    expect(find.text('7 ta rangli pechat'), findsOneWidget);
    expect(find.text('Joriy ish'), findsNothing);
    expect(find.text('Hozir aktiv zakaz yo‘q'), findsNothing);
  });

  testWidgets('admin manages warehouses from a qolipchi profile', (
    tester,
  ) async {
    const entry = AdminUserListEntry(
      id: 'QOLIP-001',
      name: 'Jumaniyoz qolipchi',
      phone: '+998110000011',
      kind: AdminUserKind.qolipchi,
      principalRole: UserRole.qolipchi,
    );
    final assigned = <String>['Kalidor'];
    String? assignedWarehouse;
    String? removedWarehouse;
    UserRole? removedPrincipalRole;
    String? removedPrincipalRef;

    Future<List<AdminWarehouseAssignment>> loadAssignments() async => [
          for (final warehouse in assigned)
            AdminWarehouseAssignment(
              warehouse: warehouse,
              principalRole: UserRole.qolipchi,
              principalRef: entry.id,
              displayName: entry.name,
            ),
          const AdminWarehouseAssignment(
            warehouse: 'Boshqa qolipchi ombori',
            principalRole: UserRole.qolipchi,
            principalRef: 'QOLIP-OTHER',
            displayName: 'Boshqa qolipchi',
          ),
          const AdminWarehouseAssignment(
            warehouse: 'Bo‘yoq ombori',
            principalRole: UserRole.boyoqchi,
            principalRef: 'QOLIP-001',
            displayName: 'Bo‘yoqchi',
          ),
        ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminWorkerDetailScreen(
          entry: entry,
          detailLoader: (_) async => const AdminWorkerDetail(
            id: 'QOLIP-001',
            name: 'Jumaniyoz qolipchi',
            phone: '+998110000011',
            avatarUrl: '',
            level: 'Qolipchi',
            code: '503898201824',
            codeLocked: false,
            codeRetryAfterSec: 0,
          ),
          warehouseAssignmentsLoader: loadAssignments,
          warehousesLoader: () async => const [
            AdminWarehouse(warehouse: 'Kalidor'),
            AdminWarehouse(warehouse: 'Qolip ombori'),
            AdminWarehouse(warehouse: 'Guruh', isGroup: true),
          ],
          warehouseAssigner: ({
            required warehouse,
            required principalRole,
            required principalRef,
            required displayName,
          }) async {
            expect(principalRole, UserRole.qolipchi);
            expect(principalRef, entry.id);
            expect(displayName, entry.name);
            assignedWarehouse = warehouse;
            assigned.add(warehouse);
            return AdminWarehouseAssignment(
              warehouse: warehouse,
              principalRole: principalRole,
              principalRef: principalRef,
              displayName: displayName,
            );
          },
          warehouseUnassigner: ({
            required warehouse,
            required principalRole,
            required principalRef,
          }) async {
            removedWarehouse = warehouse;
            removedPrincipalRole = principalRole;
            removedPrincipalRef = principalRef;
            assigned.remove(warehouse);
            return AdminWarehouseAssignment(
              warehouse: warehouse,
              principalRole: principalRole,
              principalRef: principalRef,
              displayName: entry.name,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 ta ombor'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('admin-worker-detail-admin-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Biriktirilgan omborlar'), findsOneWidget);
    expect(find.text('Kalidor'), findsOneWidget);
    expect(find.text('Boshqa qolipchi ombori'), findsNothing);
    expect(find.text('Bo‘yoq ombori'), findsNothing);

    final addWarehouse =
        find.byKey(const ValueKey('admin-qolipchi-detail-add-warehouse'));
    await tester.drag(
      find.byKey(const ValueKey('admin-worker-detail-scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(addWarehouse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Guruh'), findsNothing);
    await tester.tap(find.text('Qolip ombori'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('admin-material-warehouse-confirm')),
    );
    await tester.pumpAndSettle();

    expect(assignedWarehouse, 'Qolip ombori');
    expect(find.text('2 ta ombor'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('admin-qolipchi-detail-warehouse-Qolip ombori'),
      ),
      findsOneWidget,
    );

    final kalidorChip = tester.widget<InputChip>(
      find.byKey(
        const ValueKey('admin-qolipchi-detail-warehouse-Kalidor'),
      ),
    );
    kalidorChip.onDeleted!();
    await tester.pumpAndSettle();
    expect(find.text('Omborni uzish'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Ha'),
      ),
    );
    await tester.pumpAndSettle();

    expect(removedWarehouse, 'Kalidor');
    expect(removedPrincipalRole, UserRole.qolipchi);
    expect(removedPrincipalRef, entry.id);
    expect(
      find.byKey(
        const ValueKey('admin-qolipchi-detail-warehouse-Kalidor'),
      ),
      findsNothing,
    );
    expect(find.text('1 ta ombor'), findsOneWidget);
  });
}
