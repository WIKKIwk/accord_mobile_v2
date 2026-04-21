import '../../../app/app_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/refresh_hub.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_retry_state.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/top_refresh_scroll_physics.dart';
import '../../shared/models/app_models.dart';
import '../state/werka_store.dart';
import 'widgets/werka_dock.dart';
import 'widgets/werka_create_hub_sheet.dart';
import 'package:flutter/material.dart';

class WerkaHomeScreen extends StatefulWidget {
  const WerkaHomeScreen({super.key});

  @override
  State<WerkaHomeScreen> createState() => _WerkaHomeScreenState();
}

class _WerkaHomeScreenState extends State<WerkaHomeScreen>
    with WidgetsBindingObserver {
  int _refreshVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WerkaStore.instance.bootstrapHome();
    RefreshHub.instance.addListener(_handlePushRefresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RefreshHub.instance.removeListener(_handlePushRefresh);
    super.dispose();
  }

  void _handlePushRefresh() {
    if (!mounted || RefreshHub.instance.topic != 'werka') {
      return;
    }
    if (_refreshVersion == RefreshHub.instance.version) {
      return;
    }
    _refreshVersion = RefreshHub.instance.version;
    _reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _reload();
    }
  }

  Future<void> _reload() async {
    await WerkaStore.instance.refreshHome();
  }

  void _openDrawerRoute(String route) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        route,
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
        );
    return AppShell(
      title: context.l10n.werkaRoleName,
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: titleStyle,
      drawer: _WerkaHomeDrawer(onNavigate: _openDrawerRoute),
      bottom: const WerkaDock(activeTab: WerkaDockTab.home),
      contentPadding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: WerkaStore.instance,
              builder: (context, _) {
                final store = WerkaStore.instance;
                if (store.loadingHome && !store.loadedHome) {
                  return const Center(child: AppLoadingIndicator());
                }
                if (store.homeError != null && !store.loadedHome) {
                  return AppRefreshIndicator(
                    onRefresh: _reload,
                    allowRefreshOnShortContent: true,
                    child: ListView(
                      physics: const TopRefreshScrollPhysics(),
                      children: [
                        AppRetryState(onRetry: _reload),
                      ],
                    ),
                  );
                }
                final currentSummary = store.summary;
                final effectivePending = store.pendingItems;
                final previewItems = effectivePending.length > 3
                    ? effectivePending.take(3).toList()
                    : effectivePending;

                return AppRefreshIndicator(
                  onRefresh: _reload,
                  allowRefreshOnShortContent: true,
                  child: ListView(
                    physics: const TopRefreshScrollPhysics(),
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    children: [
                      const SizedBox(height: 4),
                      _WerkaSummaryList(summary: currentSummary),
                      if (previewItems.isNotEmpty) const SizedBox(height: 16),
                      if (previewItems.isNotEmpty)
                        _WerkaPendingSection(items: previewItems),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WerkaHomeDrawer extends StatelessWidget {
  const _WerkaHomeDrawer({
    required this.onNavigate,
  });

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    const selectedIndex = 0;
    return SizedBox(
      width: 272,
      child: NavigationDrawer(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        surfaceTintColor: Colors.transparent,
        selectedIndex: selectedIndex,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        onDestinationSelected: (index) {
          if (index == 0) {
            Navigator.of(context).pop();
            return;
          }
          if (index == 1) {
            Navigator.of(context).pop();
            onNavigate(AppRoutes.werkaNotifications);
            return;
          }
          if (index == 2) {
            Navigator.of(context).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) {
                return;
              }
              showWerkaCreateHubSheet(context);
            });
            return;
          }
          if (index == 3) {
            Navigator.of(context).pop();
            onNavigate(AppRoutes.werkaArchive);
            return;
          }
          if (index == 4) {
            Navigator.of(context).pop();
            onNavigate(AppRoutes.profile);
          }
        },
        header: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bo‘limlar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
              ),
          ),
        ),
        children: [
          const NavigationDrawerDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: Text('Uy'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: Text('Bildirish'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.add_rounded),
            selectedIcon: Icon(Icons.add_rounded),
            label: Text('Yangi'),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.archive_outlined),
            selectedIcon: const Icon(Icons.archive_rounded),
            label: Text(context.l10n.archiveTitle),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: Text(context.l10n.profileTitle),
          ),
        ],
      ),
    );
  }
}

/// Segment shakli: tepada faqat **yuqori** yumaloqlar (1‑rasm), o‘rtada **to‘rt tomon**
/// yumaloq (2‑rasm), pastda faqat **pastki** yumaloqlar (1‑rasmni pastga qaratsa).
enum _WerkaSummarySegmentSlot {
  top,
  middle,
  bottom,
}

/// MD3 Lists guidelines — **Gaps & dividers**:
/// «Use gaps for contained lists» / «Use segmented gaps and filled list items to define
/// a list group»; dividerlar ko‘pincha **uncontained** ro‘yxatlar uchun.
/// Manba: [m3.material.io/components/lists/guidelines](https://m3.material.io/components/lists/guidelines)
class _WerkaSummaryList extends StatelessWidget {
  const _WerkaSummaryList({
    required this.summary,
  });

  final WerkaHomeSummary summary;

  /// Segmentlar orasidagi vertikal bo‘shliq (contained / segmented gap).
  static const double _segmentGap = 2;
  static const double _segmentRadius = 18;
  static const double _segmentMiddleRadius = 6;

  @override
  Widget build(BuildContext context) {
    return SmoothAppear(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WerkaSummarySegmentCard(
              slot: _WerkaSummarySegmentSlot.top,
              cornerRadius: _segmentRadius,
              label: context.l10n.pendingStatus,
              value: summary.pendingCount.toString(),
              highlighted: true,
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.werkaStatusBreakdown,
                arguments: WerkaStatusKind.pending,
              ),
            ),
            const SizedBox(height: _segmentGap),
            _WerkaSummarySegmentCard(
              slot: _WerkaSummarySegmentSlot.middle,
              cornerRadius: _segmentMiddleRadius,
              label: context.l10n.confirmedStatus,
              value: summary.confirmedCount.toString(),
              highlighted: false,
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.werkaStatusBreakdown,
                arguments: WerkaStatusKind.confirmed,
              ),
            ),
            const SizedBox(height: _segmentGap),
            _WerkaSummarySegmentCard(
              slot: _WerkaSummarySegmentSlot.bottom,
              cornerRadius: _segmentRadius,
              label: context.l10n.returnedStatus,
              value: summary.returnedCount.toString(),
              highlighted: false,
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.werkaStatusBreakdown,
                arguments: WerkaStatusKind.returned,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmentlar oralig‘ida bir-biriga mos mikro‑yumaloqlik (tepa kartaning pastki va
/// past kartaning **yuqori** burchaklari — bir xil radius, teskaricha).
const Radius _werkaSummarySegmentJoinMicro = Radius.circular(6);

BorderRadius _borderRadiusForSegmentSlot(
  _WerkaSummarySegmentSlot slot,
  double r,
) {
  final Radius radius = Radius.circular(r);
  switch (slot) {
    case _WerkaSummarySegmentSlot.top:
      return BorderRadius.only(
        topLeft: radius,
        topRight: radius,
        bottomLeft: _werkaSummarySegmentJoinMicro,
        bottomRight: _werkaSummarySegmentJoinMicro,
      );
    case _WerkaSummarySegmentSlot.middle:
      return BorderRadius.all(radius);
    case _WerkaSummarySegmentSlot.bottom:
      return BorderRadius.only(
        topLeft: _werkaSummarySegmentJoinMicro,
        topRight: _werkaSummarySegmentJoinMicro,
        bottomLeft: radius,
        bottomRight: radius,
      );
  }
}

/// Bitta **to‘ldirilgan** list elementi — segmentlar bir-biriga ulanmaydi (faqat gap).
class _WerkaSummarySegmentCard extends StatelessWidget {
  const _WerkaSummarySegmentCard({
    required this.slot,
    required this.cornerRadius,
    required this.label,
    required this.value,
    required this.onTap,
    this.highlighted = false,
  });

  final _WerkaSummarySegmentSlot slot;
  final double cornerRadius;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final BorderRadius radius =
        _borderRadiusForSegmentSlot(slot, cornerRadius);
    final Color bg = highlighted
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHighest;
    final Color fg = highlighted
        ? scheme.onSecondaryContainer
        : scheme.onSurface;
    final Color accent =
        highlighted ? scheme.primary : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.38),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                if (highlighted) ...[
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WerkaPendingSection extends StatelessWidget {
  const _WerkaPendingSection({
    required this.items,
  });

  final List<DispatchRecord> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return SmoothAppear(
      delay: const Duration(milliseconds: 90),
      offset: const Offset(0, 18),
      child: Card.filled(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.inProgressItemsTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 14),
              Card.filled(
                margin: EdgeInsets.zero,
                color:
                    isDark ? const Color(0xFF2A2931) : scheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    for (int index = 0; index < items.length; index++) ...[
                      _WerkaPendingRow(
                        record: items[index],
                        isFirst: index == 0,
                        isLast: index == items.length - 1,
                      ),
                      if (index != items.length - 1)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: scheme.outlineVariant.withValues(alpha: 0.55),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WerkaPendingRow extends StatelessWidget {
  const _WerkaPendingRow({
    required this.record,
    required this.isFirst,
    required this.isLast,
  });

  final DispatchRecord record;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableScale(
      onTap: () => Navigator.of(context).pushNamed(
        record.isDeliveryNote
            ? AppRoutes.werkaCustomerDeliveryDetail
            : AppRoutes.werkaDetail,
        arguments: record,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isFirst ? 24 : 0),
              topRight: Radius.circular(isFirst ? 24 : 0),
              bottomLeft: Radius.circular(isLast ? 24 : 0),
              bottomRight: Radius.circular(isLast ? 24 : 0),
            ),
            onTap: () => Navigator.of(context).pushNamed(
              record.isDeliveryNote
                  ? AppRoutes.werkaCustomerDeliveryDetail
                  : AppRoutes.werkaDetail,
              arguments: record,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          record.supplierName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${record.sentQty.toStringAsFixed(0)} ${record.uom}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.createdLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
