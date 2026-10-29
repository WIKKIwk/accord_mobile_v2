import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/session/session.dart';
import '../../../../core/session/session_read_scope.dart';

class AdminAppUpdateSettingsCard extends StatefulWidget {
  const AdminAppUpdateSettingsCard({super.key});

  @override
  State<AdminAppUpdateSettingsCard> createState() =>
      _AdminAppUpdateSettingsCardState();
}

class _AdminAppUpdateSettingsCardState
    extends State<AdminAppUpdateSettingsCard> {
  bool? _enabled;
  bool _busy = true;
  bool _loadFailed = false;

  bool get _isAdmin => AppSession.instance.profile?.isAdminOrBrigader == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isAdmin) return;
    final scope = currentSessionReadScope();
    setState(() {
      _busy = true;
      _loadFailed = false;
    });
    try {
      final enabled = await MobileApi.instance.mandatoryAppUpdatesEnabled();
      if (!mounted || scope != currentSessionReadScope()) return;
      setState(() => _enabled = enabled);
    } catch (_) {
      if (!mounted || scope != currentSessionReadScope()) return;
      setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(bool enabled) async {
    if (_busy || !_isAdmin) return;
    final scope = currentSessionReadScope();
    setState(() => _busy = true);
    try {
      final saved =
          await MobileApi.instance.setMandatoryAppUpdatesEnabled(enabled);
      if (!mounted || scope != currentSessionReadScope()) return;
      setState(() => _enabled = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsSaved)),
      );
    } catch (_) {
      if (!mounted || scope != currentSessionReadScope()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.appUpdateSettingsSaveFailed)),
      );
      // A timeout may occur after the server saved the setting. Read it back.
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!_isAdmin) return const SizedBox.shrink();
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            key: const ValueKey('mandatory-app-update-switch'),
            title: Text(l10n.appUpdateMandatorySettingTitle),
            subtitle: Text(l10n.appUpdateMandatorySettingBody),
            value: _enabled ?? false,
            onChanged: _busy || _loadFailed || _enabled == null ? null : _save,
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_loadFailed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  Text(l10n.appUpdateSettingsLoadFailed),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
