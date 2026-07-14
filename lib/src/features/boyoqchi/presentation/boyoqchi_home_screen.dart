import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
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
    final titleParts = [
      request.orderCode.trim(),
      request.orderName.trim(),
    ].where((value) => value.isNotEmpty).toList(growable: false);
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
            Text(
              titleParts.isEmpty ? request.orderId : titleParts.join(' · '),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${request.apparatus} · ${request.senderDisplayName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (rasxot.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ReturnedPaintUsage(title: 'Rasxot', items: rasxot),
            ],
            if (astatka.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ReturnedPaintUsage(title: 'Astatka', items: astatka),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReturnedPaintUsage extends StatelessWidget {
  const _ReturnedPaintUsage({required this.title, required this.items});

  final String title;
  final List<ReturnedPaintItemInput> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${item.name}: ${item.values.entries.map((entry) => '${entry.key} ${_formatNumber(entry.value)}').join(', ')}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
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
