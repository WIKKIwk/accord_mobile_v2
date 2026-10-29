import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/session/session.dart';
import '../../../../core/session/session_read_scope.dart';

class AdminLaminationSettingsCard extends StatefulWidget {
  const AdminLaminationSettingsCard({super.key});

  @override
  State<AdminLaminationSettingsCard> createState() =>
      _AdminLaminationSettingsCardState();
}

class _AdminLaminationSettingsCardState
    extends State<AdminLaminationSettingsCard> {
  bool? _required;
  bool _busy = true;
  bool _loadFailed = false;

  bool get _isAdmin => AppSession.instance.profile?.isAdminOrBrigader == true;
  String _text(String key) =>
      context.l10n.productionText('lamination.settings.$key');

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
      final required =
          await MobileApi.instance.laminationLayerRemaindersRequired();
      if (!mounted || scope != currentSessionReadScope()) return;
      setState(() => _required = required);
    } catch (_) {
      if (!mounted || scope != currentSessionReadScope()) return;
      setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(bool required) async {
    if (_busy || !_isAdmin) return;
    final scope = currentSessionReadScope();
    setState(() => _busy = true);
    try {
      final saved = await MobileApi.instance
          .setLaminationLayerRemaindersRequired(required);
      if (!mounted || scope != currentSessionReadScope()) return;
      setState(() => _required = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsSaved)),
      );
    } catch (_) {
      if (!mounted || scope != currentSessionReadScope()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text('save_failed'))),
      );
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
          key: const ValueKey('lamination-layer-remainders-switch'),
          title: Text(_text('title')),
          subtitle: Text(_text('description')),
          value: _required ?? true,
          onChanged: _busy || _loadFailed || _required == null ? null : _save,
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
