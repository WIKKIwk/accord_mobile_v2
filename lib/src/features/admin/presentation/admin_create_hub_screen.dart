import '../../../app/app_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/session/session.dart';
import '../../shared/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/display/common_widgets.dart';
import '../../../core/widgets/display/motion_widgets.dart';
import 'widgets/admin_dock.dart';
import 'package:flutter/material.dart';

class AdminCreateHubScreen extends StatelessWidget {
  const AdminCreateHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = [
      (
        l10n.adminCreateUserTitle,
        l10n.adminCreateUserSubtitle,
        AppRoutes.adminUserCreate
      ),
      (
        l10n.adminText('create_hub.worker_settings'),
        l10n.adminText('create_hub.worker_settings_subtitle'),
        AppRoutes.adminWorkerSettings
      ),
      (
        l10n.adminErpSettingsTitle,
        l10n.adminErpSettingsSubtitle,
        AppRoutes.adminSettings
      ),
      (
        l10n.adminCreateItemTitle,
        l10n.adminCreateItemSubtitle,
        AppRoutes.adminItemCreate
      ),
      (
        l10n.adminCreateItemGroupTitle,
        l10n.adminCreateItemGroupSubtitle,
        AppRoutes.adminItemGroupCreate
      ),
      (
        l10n.adminCreateOrderTitle,
        l10n.adminText('create_hub.saved_order'),
        AppRoutes.adminCalculate
      ),
    ]
        .where((action) =>
            AppSession.instance.profile?.role != UserRole.salesManager ||
            AppRouter.canOpenRoute(action.$3))
        .toList(growable: false);
    return AppShell(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.pop();
          } else {
            nav.pushNamedAndRemoveUntil(
                AppSession.instance.homeRoute, (route) => false);
          }
        },
      ),
      title: context.l10n.adminCreateTitle,
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
      child: ListView(
        padding: const EdgeInsets.only(top: 4),
        children: [
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const Divider(height: 1, thickness: 1),
                  _CreateHubRow(
                    title: actions[i].$1,
                    subtitle: actions[i].$2,
                    onTap: () => Navigator.of(context).pushNamed(actions[i].$3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateHubRow extends StatelessWidget {
  const _CreateHubRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      borderRadius: 24,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    );
  }
}
