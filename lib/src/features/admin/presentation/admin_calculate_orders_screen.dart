import '../../../app/app_router.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../state/calculate_order_store.dart';
import 'widgets/admin_catalog_search_field.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_order_image_thumb.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
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
    setState(() {
      _loading = false;
    });
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
    showAdminTopNotice(
      context,
      context.l10n.adminText('calculate.saved_deleted'),
    );
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  List<CalculateOrderTemplate> _visibleTemplates(
    List<CalculateOrderTemplate> templates,
  ) {
    // Saved templates exist independently of orders and linked flow maps.
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
        for (final layer in template.effectiveLayers) ...[
          layer.material,
          layer.micron,
        ],
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
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: context.l10n.adminText('calculate.order_search'),
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
        color: scheme.surfaceContainerLow,
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : AnimatedBuilder(
                animation: CalculateOrderTemplateStore.instance,
                builder: (context, _) {
                  final templates =
                      CalculateOrderTemplateStore.instance.templates;
                  final visibleTemplates = _visibleTemplates(templates);
                  return ListView(
                    padding: EdgeInsets.fromLTRB(4, 4, 4, bottomPadding),
                    children: [
                      if (visibleTemplates.isEmpty &&
                          _searchQuery.trim().isEmpty)
                        _EmptyOrders(
                          message: context.l10n.adminText(
                            'calculate.saved_templates_empty',
                          ),
                        )
                      else if (visibleTemplates.isEmpty)
                        _EmptyOrders(
                          message: context.l10n.adminText(
                            'calculate.order_empty',
                          ),
                        )
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = [
      if (template.customer.trim().isNotEmpty) template.customer.trim(),
      if (template.product.trim().isNotEmpty) template.product.trim(),
      if (template.widthMm > 0) '${_fmt(template.widthMm)} mm',
      if (template.wastePercent >= 0)
        '${context.l10n.adminText('calculate.waste')} '
            '${_fmt(template.wastePercent)}%',
    ].join(' • ');

    final cornerRadius = M3SegmentedListGeometry.cornerRadiusForSlot(slot);

    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: cornerRadius,
      backgroundColor: scheme.surfaceContainerLowest,
      onTap: onTap,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: kAdminOrderCoverWidth,
            child: AdminOrderCoverThumb(
              imageUrl: template.imageUrl,
              displayName: _orderTitle(context.l10n, template),
              heroTag: 'quick-order-image-${template.id}',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kAdminOrderCoverWidth + 12,
              8,
              8,
              8,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 45),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _orderTitle(context.l10n, template),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.adminText('action.delete'),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

String _orderTitle(
  AppLocalizations l10n,
  CalculateOrderTemplate template,
) {
  final name = template.name.trim().isEmpty
      ? template.product.trim()
      : template.name.trim();
  return name.isEmpty ? l10n.adminText('calculate.order') : name;
}

String _fmt(double value) => formatQuantity(value);
