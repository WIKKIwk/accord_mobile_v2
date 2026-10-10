import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_shell.dart';

class AdminAdditionalSettingsScreen extends StatefulWidget {
  const AdminAdditionalSettingsScreen({super.key});

  @override
  State<AdminAdditionalSettingsScreen> createState() =>
      _AdminAdditionalSettingsScreenState();
}

class _AdminAdditionalSettingsScreenState
    extends State<AdminAdditionalSettingsScreen> {
  Future<PaddonManagementSettings>? _future;
  bool _saving = false;
  bool get _isAdmin => AppSession.instance.profile?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    if (_isAdmin) _future = MobileApi.instance.paddonManagementSettings();
  }

  Future<void> _refresh() async {
    if (!_isAdmin || _saving) return;
    final future = MobileApi.instance.paddonManagementSettings();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {/* The retry state displays failures. */}
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_saving || !_isAdmin) return;
    final scope = currentSessionReadScope();
    if (enabled) {
      final confirmed = await showM3ConfirmDialog(
        context: context,
        title: context.l10n
            .productionText('paddon.management.free_movement.confirm'),
        message: context.l10n
            .productionText('paddon.management.free_movement.description'),
        cancelLabel: context.l10n.no,
        confirmLabel: context.l10n.yes,
        confirmButtonKey: const ValueKey('paddon-free-movement-confirm'),
        cancelButtonKey: const ValueKey('paddon-free-movement-cancel'),
      );
      if (confirmed != true ||
          !mounted ||
          !_isAdmin ||
          scope != currentSessionReadScope()) {
        return;
      }
    }
    await _saveSettings(freeMovementEnabled: enabled);
  }

  Future<void> _saveSettings({
    bool? freeMovementEnabled,
    bool? workerVisibilityEnabled,
  }) async {
    if (_saving || !_isAdmin) return;
    final scope = currentSessionReadScope();
    setState(() => _saving = true);
    try {
      final saved = await MobileApi.instance.updatePaddonManagementSettings(
        freeMovementEnabled: freeMovementEnabled,
        workerVisibilityEnabled: workerVisibilityEnabled,
      );
      if (!mounted || scope != currentSessionReadScope()) return;
      setState(() {
        _future = Future.value(saved);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.settingsSaved)));
    } catch (_) {
      if (!mounted || scope != currentSessionReadScope()) return;
      final future = MobileApi.instance.paddonManagementSettings();
      setState(() {
        _future = future;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n
              .productionText('paddon.management.settings.failed'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminShell(
        title: context.l10n.productionText('paddon.management.settings.title'),
        activeTab: AdminDockTab.settings,
        selectedRouteName: AppRoutes.adminAdditionalSettings,
        showPrimaryFab: false,
        actions: [
          IconButton(
              onPressed: _saving ? null : _refresh,
              icon: const Icon(Icons.refresh))
        ],
        child: !_isAdmin
            ? Center(
                child: Text(context.l10n.productionErrorMessage('forbidden')))
            : FutureBuilder<PaddonManagementSettings>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: AppLoadingIndicator());
                  }
                  if (snapshot.hasError) {
                    return AppRetryState(onRetry: _refresh);
                  }
                  return ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 144),
                      children: [
                        Card(
                            child: SwitchListTile(
                          key: const ValueKey('paddon-free-movement-switch'),
                          title: Text(context.l10n.productionText(
                              'paddon.management.free_movement.title')),
                          subtitle: Text(context.l10n.productionText(
                              'paddon.management.free_movement.description')),
                          value: snapshot.data?.freeMovementEnabled ?? false,
                          onChanged: _saving ? null : _setEnabled,
                        )),
                        Card(
                            child: SwitchListTile(
                          key: const ValueKey('paddon-worker-visibility-switch'),
                          title: Text(context.l10n.productionText(
                              'paddon.management.worker_visibility.title')),
                          subtitle: Text(context.l10n.productionText(
                              'paddon.management.worker_visibility.description')),
                          value: snapshot.data?.workerVisibilityEnabled ?? false,
                          onChanged: _saving
                              ? null
                              : (enabled) => _saveSettings(
                                  workerVisibilityEnabled: enabled),
                        )),
                        if (_saving) const LinearProgressIndicator(),
                      ]);
                },
              ),
      );
}
