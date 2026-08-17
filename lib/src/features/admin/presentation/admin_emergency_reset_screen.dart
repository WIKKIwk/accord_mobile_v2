import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/display/app_status_chip.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_shell.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

class AdminEmergencyResetScreen extends StatefulWidget {
  const AdminEmergencyResetScreen({super.key});

  static const _scopes = <_EmergencyResetScope>[
    _EmergencyResetScope(
      icon: Icons.school_outlined,
      titleKey: 'emergency_reset.training.title',
      descriptionKey: 'emergency_reset.training.description',
      scopeKey: 'emergency_reset.training.scope',
    ),
    _EmergencyResetScope(
      icon: Icons.receipt_long_outlined,
      titleKey: 'emergency_reset.orders.title',
      descriptionKey: 'emergency_reset.orders.description',
      scopeKey: 'emergency_reset.orders.scope',
      dangerous: true,
      implemented: true,
    ),
    _EmergencyResetScope(
      icon: Icons.view_in_ar_outlined,
      titleKey: 'emergency_reset.qolip.title',
      descriptionKey: 'emergency_reset.qolip.description',
      scopeKey: 'emergency_reset.qolip.scope',
    ),
    _EmergencyResetScope(
      icon: Icons.warehouse_outlined,
      titleKey: 'emergency_reset.warehouse.title',
      descriptionKey: 'emergency_reset.warehouse.description',
      scopeKey: 'emergency_reset.warehouse.scope',
      dangerous: true,
    ),
    _EmergencyResetScope(
      icon: Icons.groups_outlined,
      titleKey: 'emergency_reset.users.title',
      descriptionKey: 'emergency_reset.users.description',
      scopeKey: 'emergency_reset.users.scope',
      dangerous: true,
    ),
    _EmergencyResetScope(
      icon: Icons.notifications_off_outlined,
      titleKey: 'emergency_reset.notifications.title',
      descriptionKey: 'emergency_reset.notifications.description',
      scopeKey: 'emergency_reset.notifications.scope',
    ),
    _EmergencyResetScope(
      icon: Icons.delete_forever_outlined,
      titleKey: 'emergency_reset.all.title',
      descriptionKey: 'emergency_reset.all.description',
      scopeKey: 'emergency_reset.all.scope',
      dangerous: true,
    ),
  ];

  @override
  State<AdminEmergencyResetScreen> createState() =>
      _AdminEmergencyResetScreenState();
}

class _AdminEmergencyResetScreenState extends State<AdminEmergencyResetScreen> {
  bool _resettingOrders = false;

  Future<void> _resetOrders() async {
    if (_resettingOrders) {
      return;
    }
    final l10n = context.l10n;
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: l10n.adminText('emergency_reset.orders.confirm_title'),
      message: l10n.adminText('emergency_reset.orders.confirm_body'),
      cancelLabel: l10n.adminText('action.cancel'),
      confirmLabel: l10n.adminText('emergency_reset.orders.confirm_action'),
    );
    if (!mounted || confirmed != true) {
      return;
    }

    setState(() => _resettingOrders = true);
    try {
      await MobileApi.instance.adminResetOrders();
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        l10n.adminText('emergency_reset.orders.completed'),
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException
            ? error.message
            : l10n.adminText('emergency_reset.orders.failed'),
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _resettingOrders = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136;

    return AdminShell(
      title: l10n.adminText('emergency_reset.title'),
      selectedRouteName: AppRoutes.adminEmergencyReset,
      activeTab: AdminDockTab.settings,
      contentPadding: EdgeInsets.zero,
      child: ListView(
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
        children: [
          const _EmergencyResetWarning(),
          const SizedBox(height: 20),
          Text(
            l10n.adminText('emergency_reset.scopes_title'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.adminText('emergency_reset.scopes_subtitle'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 14),
          for (var index = 0;
              index < AdminEmergencyResetScreen._scopes.length;
              index++) ...[
            _EmergencyResetScopeCard(
              scope: AdminEmergencyResetScreen._scopes[index],
              onReset: AdminEmergencyResetScreen._scopes[index].implemented
                  ? _resetOrders
                  : null,
              resetting: AdminEmergencyResetScreen._scopes[index].implemented &&
                  _resettingOrders,
            ),
            if (index != AdminEmergencyResetScreen._scopes.length - 1)
              const SizedBox(height: 10),
          ],
          const SizedBox(height: 18),
          const _EmergencyResetNextStepCard(),
        ],
      ),
    );
  }
}

class _EmergencyResetScope {
  const _EmergencyResetScope({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.scopeKey,
    this.dangerous = false,
    this.implemented = false,
  });

  final IconData icon;
  final String titleKey;
  final String descriptionKey;
  final String scopeKey;
  final bool dangerous;
  final bool implemented;
}

class _EmergencyResetWarning extends StatelessWidget {
  const _EmergencyResetWarning();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.error.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminText('emergency_reset.warning_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.adminText('emergency_reset.warning_body'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyResetScopeCard extends StatelessWidget {
  const _EmergencyResetScopeCard({
    required this.scope,
    this.onReset,
    this.resetting = false,
  });

  final _EmergencyResetScope scope;
  final VoidCallback? onReset;
  final bool resetting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final accent = scope.dangerous ? scheme.error : scheme.primary;
    final enabled = scope.implemented && onReset != null;
    final statusKey = scope.implemented
        ? 'emergency_reset.backend_ready'
        : 'emergency_reset.backend_pending';
    final actionKey = resetting
        ? 'emergency_reset.action_resetting'
        : enabled
            ? 'emergency_reset.action_orders'
            : 'emergency_reset.action_pending';

    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: 3,
      shadowColor: scheme.shadow.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(scope.icon, color: accent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.adminText(scope.titleKey),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        l10n.adminText(scope.descriptionKey),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(
                height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppStatusChip(
                  label: l10n.adminText(statusKey),
                ),
                Text(
                  l10n.adminText(scope.scopeKey),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: enabled && !resetting ? onReset : null,
                style: enabled
                    ? OutlinedButton.styleFrom(foregroundColor: accent)
                    : null,
                icon: resetting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        enabled
                            ? Icons.delete_sweep_outlined
                            : Icons.lock_outline_rounded,
                      ),
                label: Text(l10n.adminText(actionKey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyResetNextStepCard extends StatelessWidget {
  const _EmergencyResetNextStepCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.alt_route_rounded, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminText('emergency_reset.next_step_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.adminText('emergency_reset.next_step_body'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
