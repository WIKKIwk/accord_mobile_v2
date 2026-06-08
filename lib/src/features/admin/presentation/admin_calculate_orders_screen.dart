import '../../../app/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../state/calculate_order_store.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
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
  bool _openingRoute = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await CalculateOrderTemplateStore.instance.load();
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
  }

  void _openDrawerRoute(String routeName) {
    if (_openingRoute) {
      return;
    }
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    _openingRoute = true;
    Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
    );
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminCalculateOrders,
        onNavigate: _openDrawerRoute,
      ),
      title: 'Zakazlar',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.home),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : AnimatedBuilder(
              animation: CalculateOrderTemplateStore.instance,
              builder: (context, _) {
                final templates =
                    CalculateOrderTemplateStore.instance.templates;
                if (templates.isEmpty) {
                  return ListView(
                    padding: EdgeInsets.fromLTRB(12, 24, 12, bottomPadding),
                    children: const [
                      _EmptyOrders(),
                    ],
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    return _OrderTile(
                      template: template,
                      onTap: () => _openTemplate(template),
                      onDelete: () => _deleteTemplate(template),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: templates.length,
                );
              },
            ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.template,
    required this.onTap,
    required this.onDelete,
  });

  final CalculateOrderTemplate template;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = [
      if (template.product.trim().isNotEmpty) template.product.trim(),
      if (template.widthMm > 0) '${_fmt(template.widthMm)} mm',
      if (template.wastePercent >= 0) 'Atxod ${_fmt(template.wastePercent)}%',
    ].join(' • ');
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'O‘chirish',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        'Saqlangan zakaz yo‘q',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _fmt(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
