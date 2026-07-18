import 'package:accord_mobile_v2/src/core/widgets/scroll/top_refresh_scroll_physics.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/features/admin/models/admin_item_group_tree_entry.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_item_group_items_tab.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_item_group_tree_tab.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('item group tree reuses the admin home pull refresh', (
    tester,
  ) async {
    var refreshCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminItemGroupTreeTab(
            itemGroupTreeFuture: Future.value(const [
              AdminItemGroupTreeEntry(
                name: 'all-item-groups',
                itemGroupName: 'All Item Groups',
                parentItemGroup: '',
                isGroup: true,
              ),
            ]),
            onRefresh: () async => refreshCalls++,
            onShowItems: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppRefreshIndicator), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(
      tester.widget<ListView>(find.byType(ListView).first).physics,
      isA<TopRefreshScrollPhysics>(),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(refreshCalls, 1);
  });

  testWidgets('item group items reuses the admin home pull refresh', (
    tester,
  ) async {
    var loadCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminItemGroupItemsTab(
            itemGroupsFuture: Future.value(const ['Group A']),
            selectedGroup: 'Group A',
            onSelectGroup: (_) {},
            loadItemsPage: (group, limit, offset) async {
              loadCalls++;
              return const [
                SupplierItem(
                  code: 'ITEM-001',
                  name: 'Item 001',
                  uom: 'Dona',
                  warehouse: '',
                  itemGroup: 'Group A',
                ),
              ];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loadCalls, 1);
    expect(find.byType(AppRefreshIndicator), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(
      tester.widget<ListView>(find.byType(ListView).first).physics,
      isA<TopRefreshScrollPhysics>(),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(loadCalls, 2);
  });
}
