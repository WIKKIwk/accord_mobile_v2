import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/theme/app_theme.dart';
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
    setState(() => _requests = requests);
    await requests;
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
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _ReturnedPaintRequestCard(request: requests[index]),
            ),
          );
        },
      ),
    );
  }
}

class _ReturnedPaintRequestCard extends StatelessWidget {
  const _ReturnedPaintRequestCard({required this.request});

  final ReturnedPaintRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rasxot = request.items
        .where((item) => item.usage == 'rasxot')
        .toList(growable: false);
    final astatka = request.items
        .where((item) => item.usage == 'astatka')
        .toList(growable: false);
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReturnedPaintInfoRow(
              label: 'Order',
              value: _orderLabel(request),
              prominent: true,
            ),
            _ReturnedPaintInfoRow(
              label: 'Operator',
              value: _displayOrDash(request.senderDisplayName),
            ),
            _ReturnedPaintInfoRow(
              label: 'Rasxot',
              value: _usageLabel(rasxot),
            ),
            _ReturnedPaintInfoRow(
              label: 'Astatka',
              value: _usageLabel(astatka),
            ),
            _ReturnedPaintInfoRow(
              label: 'Time',
              value: formatLocalDateTime(request.createdAt),
            ),
            _ReturnedPaintInfoRow(
              label: 'Location',
              value: _displayOrDash(request.apparatus),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnedPaintInfoRow extends StatelessWidget {
  const _ReturnedPaintInfoRow({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: prominent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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

String _usageLabel(List<ReturnedPaintItemInput> items) {
  if (items.isEmpty) return '—';
  return items
      .map(
        (item) =>
            '${item.name}: ${item.values.entries.map((entry) => '${entry.key} ${_formatNumber(entry.value)}').join(', ')}',
      )
      .join('; ');
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

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
        RegExp(r'\.$'),
        '',
      );
}
