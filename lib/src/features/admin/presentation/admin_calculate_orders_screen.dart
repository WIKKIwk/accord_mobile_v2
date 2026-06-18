import '../../../app/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../state/calculate_order_store.dart';
import 'widgets/admin_catalog_search_field.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_summary_card.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

class AdminCalculateOrdersScreen extends StatefulWidget {
  const AdminCalculateOrdersScreen({super.key});

  @override
  State<AdminCalculateOrdersScreen> createState() =>
      _AdminCalculateOrdersScreenState();
}

class _AdminCalculateOrdersScreenState
    extends State<AdminCalculateOrdersScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _openingRoute = false;
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await CalculateOrderTemplateStore.instance.load();
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
  }

  void _openDrawerRoute(String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  void _openTemplate(CalculateOrderTemplate template) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.adminCalculate,
      (route) => false,
      arguments: template,
    );
  }

  Future<void> _deleteTemplate(CalculateOrderTemplate template) async {
    await CalculateOrderTemplateStore.instance.delete(template.id);
    if (!mounted) {
      return;
    }
    showAdminTopNotice(context, 'Zakaz o‘chirildi');
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  List<CalculateOrderTemplate> _visibleTemplates(
    List<CalculateOrderTemplate> templates,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return templates;
    }
    return templates.where((template) {
      final haystack = [
        template.code,
        template.name,
        template.customer,
        template.customerRef,
        template.product,
        template.itemCode,
        template.status,
        template.color,
        template.firstLayerMaterial,
        template.firstLayerMicron,
        template.secondLayerMaterial,
        template.secondLayerMicron,
        template.thirdLayerMaterial,
        template.thirdLayerMicron,
        template.note,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 240.0;
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminCalculateOrders,
        onNavigate: _openDrawerRoute,
      ),
      title: '',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: 'Zakaz qidirish',
        onChanged: _onSearchChanged,
        onClear: () {
          _searchController.clear();
          _onSearchChanged('');
        },
      ),
      bottom: const AdminDock(activeTab: AdminDockTab.home),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : AnimatedBuilder(
                animation: CalculateOrderTemplateStore.instance,
                builder: (context, _) {
                  final templates =
                      CalculateOrderTemplateStore.instance.templates;
                  final visibleTemplates = _visibleTemplates(templates);
                  return ListView(
                    padding: EdgeInsets.fromLTRB(4, 12, 4, bottomPadding),
                    children: [
                      if (templates.isEmpty)
                        const _EmptyOrders(message: 'Saqlangan zakaz yo‘q')
                      else if (visibleTemplates.isEmpty)
                        const _EmptyOrders(message: 'Zakaz topilmadi')
                      else
                        _OrderListModule(
                          templates: visibleTemplates,
                          onTapTemplate: _openTemplate,
                          onDeleteTemplate: _deleteTemplate,
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _OrderListModule extends StatelessWidget {
  const _OrderListModule({
    required this.templates,
    required this.onTapTemplate,
    required this.onDeleteTemplate,
  });

  final List<CalculateOrderTemplate> templates;
  final ValueChanged<CalculateOrderTemplate> onTapTemplate;
  final ValueChanged<CalculateOrderTemplate> onDeleteTemplate;

  @override
  Widget build(BuildContext context) {
    return M3SegmentSpacedColumn(
      padding: EdgeInsets.zero,
      children: [
        for (int index = 0; index < templates.length; index++)
          _OrderRow(
            slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
              index,
              templates.length,
            ),
            template: templates[index],
            onTap: () => onTapTemplate(templates[index]),
            onDelete: () => onDeleteTemplate(templates[index]),
          ),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.slot,
    required this.template,
    required this.onTap,
    required this.onDelete,
  });

  final M3SegmentVerticalSlot slot;
  final CalculateOrderTemplate template;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = [
      if (template.customer.trim().isNotEmpty) template.customer.trim(),
      if (template.product.trim().isNotEmpty) template.product.trim(),
      if (template.widthMm > 0) '${_fmt(template.widthMm)} mm',
      if (template.wastePercent >= 0) 'Atxod ${_fmt(template.wastePercent)}%',
    ].join(' • ');

    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      backgroundColor: scheme.surface,
      fixedHeight: 61,
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      value: '',
      showChevron: true,
      onTap: onTap,
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.calculate_outlined,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      title: _orderTitle(template),
      subtitle: subtitle,
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.05,
          ),
      trailing: IconButton(
        tooltip: 'O‘chirish',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

String _orderTitle(CalculateOrderTemplate template) {
  final name = template.name.trim().isEmpty
      ? template.product.trim()
      : template.name.trim();
  return name.isEmpty ? 'Zakaz' : name;
}

String _fmt(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
