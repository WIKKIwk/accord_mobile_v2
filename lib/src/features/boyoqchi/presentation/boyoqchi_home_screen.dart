import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/returned_paint_models.dart';
import 'widgets/boyoqchi_dock.dart';
import 'widgets/boyoqchi_navigation_drawer.dart';
import 'package:flutter/material.dart';

class BoyoqchiHomeScreen extends StatefulWidget {
  const BoyoqchiHomeScreen({super.key});

  @override
  State<BoyoqchiHomeScreen> createState() => _BoyoqchiHomeScreenState();
}

class _BoyoqchiHomeScreenState extends State<BoyoqchiHomeScreen> {
  late Future<ReturnedPaintRequestPage> _requests;
  String? _expandedRequestKey;

  @override
  void initState() {
    super.initState();
    _requests = _load();
  }

  Future<ReturnedPaintRequestPage> _load() {
    return MobileApi.instance.boyoqchiReturnedPaintRequests(limit: 100);
  }

  Future<void> _refresh() async {
    final requests = _load();
    setState(() {
      _requests = requests;
      _expandedRequestKey = null;
    });
    await requests;
  }

  String _requestKey(ReturnedPaintRequest request) {
    final id = request.id.trim();
    if (id.isNotEmpty) return id;
    return '${request.orderId.trim()}|${request.orderCode.trim()}|${request.createdAt.toIso8601String()}';
  }

  void _onRequestExpanded(ReturnedPaintRequest request, bool expanded) {
    setState(() {
      _expandedRequestKey = expanded ? _requestKey(request) : null;
    });
  }

  void _openDrawerRoute(String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128.0;
    return AppShell(
      title: 'Bo‘yoqchi',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      preferNativeTitle: true,
      contentPadding: EdgeInsets.zero,
      drawer: BoyoqchiNavigationDrawer(
        selectedRouteName: AppRoutes.boyoqchiHome,
        onNavigate: _openDrawerRoute,
      ),
      bottom: const BoyoqchiDock(activeTab: BoyoqchiDockTab.home),
      child: FutureBuilder<ReturnedPaintRequestPage>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError) {
            return _BoyoqchiMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Ma’lumotlar yuklanmadi',
              actionLabel: 'Qayta yuklash',
              onAction: _refresh,
            );
          }
          final requests = snapshot.data?.items ?? const [];
          if (requests.isEmpty) {
            return _BoyoqchiMessage(
              icon: Icons.inbox_outlined,
              title: 'Qaytarilgan bo‘yoq ma’lumotlari hali yo‘q',
              actionLabel: 'Yangilash',
              onAction: _refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const TopRefreshScrollPhysics(),
              padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPadding),
              itemCount: requests.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: M3SegmentedListGeometry.gap),
              itemBuilder: (context, index) {
                final request = requests[index];
                return _ReturnedPaintRequestCard(
                  request: request,
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    requests.length,
                  ),
                  expanded: _expandedRequestKey == _requestKey(request),
                  onExpandedChanged: (expanded) =>
                      _onRequestExpanded(request, expanded),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ReturnedPaintRequestCard extends StatelessWidget {
  const _ReturnedPaintRequestCard({
    required this.request,
    required this.slot,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final ReturnedPaintRequest request;
  final M3SegmentVerticalSlot slot;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rasxot = request.items
        .where((item) => item.usage.trim().toLowerCase() == 'rasxot')
        .toList(growable: false);
    final astatka = request.items
        .where((item) => item.usage.trim().toLowerCase() == 'astatka')
        .toList(growable: false);
    return M3ExpandableFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      headerPadding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
      header: Row(
        children: [
          Expanded(
            child: Text(
              _orderLabel(request),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      expandedChild: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReturnedPaintMetadata(
              rows: [
                _ReturnedPaintMetadataRow(
                  label: 'Order',
                  value: _orderLabel(request),
                  prominent: true,
                ),
                _ReturnedPaintMetadataRow(
                  label: 'Operator',
                  value: _displayOrDash(request.senderDisplayName),
                ),
                _ReturnedPaintMetadataRow(
                  label: 'Time',
                  value: formatLocalDateTime(request.createdAt),
                ),
                _ReturnedPaintMetadataRow(
                  label: 'Location',
                  value: _displayOrDash(request.apparatus),
                ),
              ],
            ),
            if (_groupItemsByCategory(rasxot).isNotEmpty) ...[
              const SizedBox(height: 10),
              _ReturnedPaintUsageSection(title: 'Rasxot', items: rasxot),
            ],
            if (_groupItemsByCategory(astatka).isNotEmpty) ...[
              const SizedBox(height: 10),
              _ReturnedPaintUsageSection(title: 'Astatka', items: astatka),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReturnedPaintMetadata extends StatelessWidget {
  const _ReturnedPaintMetadata({required this.rows});

  final List<_ReturnedPaintMetadataRow> rows;

  @override
  Widget build(BuildContext context) {
    return _ReportContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index < rows.length - 1) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _ReturnedPaintMetadataRow extends StatelessWidget {
  const _ReturnedPaintMetadataRow({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: prominent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReturnedPaintUsageSection extends StatelessWidget {
  const _ReturnedPaintUsageSection({required this.title, required this.items});

  final String title;
  final List<ReturnedPaintItemInput> items;

  @override
  Widget build(BuildContext context) {
    final groups = _groupItemsByCategory(items);
    if (groups.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return _ReportContentContainer(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < groups.length; index++) ...[
            _ReturnedPaintCategoryGroup(group: groups[index]),
            if (index < groups.length - 1)
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _ReturnedPaintCategoryGroup extends StatelessWidget {
  const _ReturnedPaintCategoryGroup({required this.group});

  final _ReturnedPaintCategory group;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _categoryLabel(group.category),
            style: textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Divider(height: 16),
          for (var index = 0; index < group.items.length; index++) ...[
            _ReturnedPaintCompactItem(item: group.items[index]),
            if (index < group.items.length - 1) const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

class _ReturnedPaintCompactItem extends StatelessWidget {
  const _ReturnedPaintCompactItem({required this.item});

  final ReturnedPaintItemInput item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        style: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
        children: [
          TextSpan(
            text: _displayOrDash(item.name.trim()),
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(text: ': '),
          TextSpan(
            text: item.values.entries
                .where(
                  (entry) =>
                      entry.key.trim().isNotEmpty &&
                      entry.value.trim().isNotEmpty,
                )
                .map(
                  (entry) =>
                      '${entry.key.trim()} — ${_formatNumber(entry.value)}',
                )
                .join(', '),
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportContentContainer extends StatelessWidget {
  const _ReportContentContainer({
    required this.child,
    this.padding = const EdgeInsets.all(10),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: child,
    );
  }
}

String _orderLabel(ReturnedPaintRequest request) {
  final name = request.orderName.trim();
  final code = request.orderCode.trim();
  if (name.isNotEmpty && code.isNotEmpty) return '$name — #$code';
  if (name.isNotEmpty) return name;
  if (code.isNotEmpty) return '#$code';
  return _displayOrDash(request.orderId);
}

List<_ReturnedPaintCategory> _groupItemsByCategory(
  List<ReturnedPaintItemInput> items,
) {
  final grouped = <String, List<ReturnedPaintItemInput>>{};
  for (final item in items) {
    final category = item.category.trim();
    if (category.isEmpty ||
        !item.values.entries.any(
          (entry) =>
              entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty,
        )) {
      continue;
    }
    grouped.putIfAbsent(category, () => []).add(item);
  }
  return grouped.entries
      .map(
        (entry) => _ReturnedPaintCategory(
          category: entry.key,
          items: List.unmodifiable(entry.value),
        ),
      )
      .toList(growable: false);
}

String _categoryLabel(String category) {
  switch (category.trim().toLowerCase()) {
    case 'colors':
    case 'ranglar':
      return 'Ranglar';
    case 'lacquers':
    case 'laklar':
      return 'Laklar';
    case 'solvents':
    case 'spirtlar':
      return 'Spirtlar';
    default:
      return category.trim();
  }
}

class _ReturnedPaintCategory {
  const _ReturnedPaintCategory({required this.category, required this.items});

  final String category;
  final List<ReturnedPaintItemInput> items;
}

String _displayOrDash(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '—' : trimmed;
}

class _BoyoqchiMessage extends StatelessWidget {
  const _BoyoqchiMessage({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatNumber(String rawValue) {
  final value = double.tryParse(rawValue);
  if (value == null || !value.isFinite) return rawValue;
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
        RegExp(r'\.$'),
        '',
      );
}
