import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/session/session.dart';
import '../../../../core/session/session_read_scope.dart';
import '../../../shared/models/app_models.dart';

class AdminQolipStartSettingsCard extends StatefulWidget {
  const AdminQolipStartSettingsCard({super.key});

  @override
  State<AdminQolipStartSettingsCard> createState() =>
      _AdminQolipStartSettingsCardState();
}

class _AdminQolipStartSettingsCardState
    extends State<AdminQolipStartSettingsCard> {
  AdminQolipStartSettings? _settings;
  bool _busy = true;
  bool _loadFailed = false;

  bool get _isAdmin => AppSession.instance.profile?.role == UserRole.admin;
  String _text(String key) =>
      context.l10n.productionText('qolip.start.settings.$key');

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
      final settings = await MobileApi.instance.qolipStartSettings();
      if (!mounted || !_isAdmin || scope != currentSessionReadScope()) return;
      setState(() => _settings = settings);
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
      final saved = await MobileApi.instance
          .setQolipAutomaticConfirmationEnabled(enabled);
      if (!mounted || !_isAdmin || scope != currentSessionReadScope()) return;
      setState(() => _settings = saved);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.settingsSaved)));
    } catch (_) {
      if (!mounted || scope != currentSessionReadScope()) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_text('save_failed'))));
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) return const SizedBox.shrink();
    return Card(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(
          key: const ValueKey('qolip-automatic-confirmation-switch'),
          title: Text(_text('title')),
          subtitle: Text(_text('description')),
          value: _settings?.automaticConfirmationEnabled ?? false,
          onChanged: _busy || _loadFailed || _settings == null ? null : _save,
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_loadFailed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(children: [
              Text(_text('load_failed')),
              TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.retry)),
            ]),
          ),
      ]),
    );
  }
}
