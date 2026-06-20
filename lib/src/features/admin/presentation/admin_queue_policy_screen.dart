import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../logic/production_map_pechat_rules.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

const double _queuePolicyPanelGap = 4;
const double _queuePolicyPanelTopGap = 8;

class AdminQueuePolicyScreen extends StatelessWidget {
  const AdminQueuePolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;
    return AppShell(
      title: 'Aparat navbati',
      subtitle: '',
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminApparatusSettings,
        onNavigate: (routeName) =>
            AdminDrawerNavigation.openRoute(context, routeName),
      ),
      nativeTopBar: true,
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: AdminQueuePolicyPanel(bottomPadding: bottomPadding),
      ),
    );
  }
}

class AdminQueuePolicyPanel extends StatefulWidget {
  const AdminQueuePolicyPanel({
    super.key,
    required this.bottomPadding,
  });

  final double bottomPadding;

  @override
  State<AdminQueuePolicyPanel> createState() => _AdminQueuePolicyPanelState();
}

class _AdminQueuePolicyPanelState extends State<AdminQueuePolicyPanel> {
  late Future<_QueuePolicyData> _future;
  final Set<String> _saving = {};
  Map<String, AdminApparatusQueuePolicy> _policies = const {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_QueuePolicyData> _load() async {
    final results = await Future.wait<Object>([
      MobileApi.instance.adminWarehouses(parent: 'aparat - A', limit: 300),
      MobileApi.instance.adminApparatusQueuePolicies(),
    ]);
    final apparatus = results[0] as List<AdminWarehouse>;
    final policies = results[1] as Map<String, AdminApparatusQueuePolicy>;
    _policies = policies;
    return _QueuePolicyData(apparatus: apparatus, policies: policies);
  }

  Future<void> _updatePolicy(
    AdminWarehouse apparatus,
    ApparatusQueuePolicy policy,
  ) async {
    final title = apparatus.warehouse.trim();
    if (title.isEmpty || _saving.contains(title)) {
      return;
    }
    setState(() => _saving.add(title));
    try {
      final saved = await MobileApi.instance.adminUpdateApparatusQueuePolicy(
        apparatus: title,
        policy: policy,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _policies = {..._policies, saved.apparatus: saved};
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException
            ? error.message
            : 'Navbat sozlamasi saqlanmadi',
      );
    } finally {
      if (mounted) {
        setState(() => _saving.remove(title));
      }
    }
  }

  AdminApparatusQueuePolicy _effectivePolicy(AdminWarehouse apparatus) {
    final title = apparatus.warehouse.trim();
    final pechatLocked = productionMapPechatColorCount(title) != null;
    if (pechatLocked) {
      return AdminApparatusQueuePolicy(
        apparatus: title,
        policy: ApparatusQueuePolicy.strictSequence,
        locked: true,
        reason: 'pechat_always_strict',
      );
    }
    final direct = _policies[title];
    if (direct != null) {
      return direct;
    }
    for (final entry in _policies.entries) {
      if (productionMapWarehouseTitlesMatch(entry.key, title)) {
        return entry.value;
      }
    }
    return AdminApparatusQueuePolicy(
      apparatus: title,
      policy: ApparatusQueuePolicy.strictSequence,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_QueuePolicyData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError) {
          return AppRetryState(
            onRetry: () async {
              setState(() {
                _future = _load();
              });
            },
          );
        }
        final apparatus = snapshot.data!.apparatus;
        if (apparatus.isEmpty) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              _queuePolicyPanelGap,
              _queuePolicyPanelTopGap,
              _queuePolicyPanelGap,
              widget.bottomPadding,
            ),
            children: const [
              _QueuePolicyIntro(),
              SizedBox(height: 24),
              Center(child: Text('Aparatlar topilmadi')),
            ],
          );
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(
            _queuePolicyPanelGap,
            _queuePolicyPanelTopGap,
            _queuePolicyPanelGap,
            widget.bottomPadding,
          ),
          children: [
            const _QueuePolicyIntro(),
            const SizedBox(height: 10),
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < apparatus.length; index++)
                  _QueuePolicyTile(
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      apparatus.length,
                    ),
                    title: apparatus[index].warehouse.trim(),
                    policy: _effectivePolicy(apparatus[index]),
                    saving: _saving.contains(
                      apparatus[index].warehouse.trim(),
                    ),
                    onChanged: _effectivePolicy(apparatus[index]).locked
                        ? null
                        : (value) => _updatePolicy(apparatus[index], value),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _QueuePolicyIntro extends StatelessWidget {
  const _QueuePolicyIntro();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Text(
        'Har bir aparat uchun ishchilar zakazni qanday tanlashini belgilang.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.3,
            ),
      ),
    );
  }
}

class _QueuePolicyData {
  const _QueuePolicyData({required this.apparatus, required this.policies});

  final List<AdminWarehouse> apparatus;
  final Map<String, AdminApparatusQueuePolicy> policies;
}

class _QueuePolicyTile extends StatelessWidget {
  const _QueuePolicyTile({
    required this.slot,
    required this.title,
    required this.policy,
    required this.saving,
    required this.onChanged,
  });

  final M3SegmentVerticalSlot slot;
  final String title;
  final AdminApparatusQueuePolicy policy;
  final bool saving;
  final ValueChanged<ApparatusQueuePolicy>? onChanged;

  String? get _lockedHint {
    if (!policy.locked) {
      return null;
    }
    return 'Bosma aparatlari doim ketma-ket rejimda';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locked = policy.locked || onChanged == null;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );

    return Material(
      color: locked ? scheme.surfaceContainerHighest : scheme.surface,
      elevation: locked ? 0 : 2,
      shadowColor:
          locked ? Colors.transparent : scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: locked
            ? BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: locked
                          ? scheme.outlineVariant.withValues(alpha: 0.35)
                          : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.precision_manufacturing_rounded,
                      size: 16,
                      color: locked
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
                          : scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: locked
                              ? scheme.onSurfaceVariant.withValues(alpha: 0.72)
                              : scheme.onSurface,
                        ),
                      ),
                      if (_lockedHint != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _lockedHint!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: locked ? 0.72 : 1,
                            ),
                            height: 1.05,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (locked)
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  )
                else if (saving)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _QueuePolicySelector(
              policy: policy.policy,
              locked: locked,
              enabled: !locked && !saving,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _QueuePolicySelector extends StatelessWidget {
  const _QueuePolicySelector({
    required this.policy,
    required this.locked,
    required this.enabled,
    required this.onChanged,
  });

  final ApparatusQueuePolicy policy;
  final bool locked;
  final bool enabled;
  final ValueChanged<ApparatusQueuePolicy>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selector = DecoratedBox(
      decoration: BoxDecoration(
        color: locked
            ? scheme.outlineVariant.withValues(alpha: 0.22)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _QueuePolicyOption(
                selected: policy == ApparatusQueuePolicy.strictSequence,
                enabled: enabled,
                locked: locked,
                icon: Icons.format_list_numbered_rounded,
                label: 'Ketma-ket',
                onTap: onChanged == null
                    ? null
                    : () => onChanged!(ApparatusQueuePolicy.strictSequence),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _QueuePolicyOption(
                selected: policy == ApparatusQueuePolicy.freePick,
                enabled: enabled,
                locked: locked,
                icon: Icons.ads_click_rounded,
                label: 'Erkin',
                onTap: onChanged == null
                    ? null
                    : () => onChanged!(ApparatusQueuePolicy.freePick),
              ),
            ),
          ],
        ),
      ),
    );
    if (locked) {
      return AbsorbPointer(child: selector);
    }
    return selector;
  }
}

class _QueuePolicyOption extends StatelessWidget {
  const _QueuePolicyOption({
    required this.selected,
    required this.enabled,
    required this.locked,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final bool locked;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inactive = locked || !enabled;
    final Color background = switch ((inactive, selected)) {
      (true, true) => scheme.outlineVariant.withValues(alpha: 0.42),
      (true, false) => Colors.transparent,
      (false, true) => scheme.secondaryContainer,
      (false, false) => Colors.transparent,
    };
    final Color foreground = switch ((inactive, selected)) {
      (true, true) => scheme.onSurfaceVariant.withValues(alpha: 0.72),
      (true, false) => scheme.onSurfaceVariant.withValues(alpha: 0.38),
      (false, true) => scheme.onSecondaryContainer,
      (false, false) => scheme.onSurfaceVariant,
    };

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
          if (selected && !inactive) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_rounded, size: 16, color: foreground),
          ],
        ],
      ),
    );

    if (inactive) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: content,
      );
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: content,
      ),
    );
  }
}
