import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shell/app_shell.dart';
import 'admin_dock.dart';

class AdminPartyCreateScaffold extends StatefulWidget {
  const AdminPartyCreateScaffold({
    super.key,
    required this.title,
    required this.nameLabel,
    required this.phoneLabel,
    required this.submitLabel,
    required this.savingLabel,
    required this.activeTab,
    required this.onCreate,
    this.onCreated,
  });

  final String title;
  final String nameLabel;
  final String phoneLabel;
  final String submitLabel;
  final String savingLabel;
  final AdminDockTab activeTab;
  final Future<void> Function(String name, String phone) onCreate;
  final VoidCallback? onCreated;

  @override
  State<AdminPartyCreateScaffold> createState() =>
      _AdminPartyCreateScaffoldState();
}

class _AdminPartyCreateScaffoldState extends State<AdminPartyCreateScaffold> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      await widget.onCreate(_name.text.trim(), _phone.text.trim());
      if (!mounted) {
        return;
      }
      widget.onCreated?.call();
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: widget.title,
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: AdminDock(activeTab: widget.activeTab),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: widget.nameLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            decoration: InputDecoration(labelText: widget.phoneLabel),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _create,
              child: Text(_saving ? widget.savingLabel : widget.submitLabel),
            ),
          ),
        ],
      ),
    );
  }
}
