import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';

class QolipSetNameDialog extends StatefulWidget {
  const QolipSetNameDialog({super.key, required this.entry});

  final QolipManagedSet entry;

  @override
  State<QolipSetNameDialog> createState() => _QolipSetNameDialogState();
}

class _QolipSetNameDialogState extends State<QolipSetNameDialog> {
  late final _controller = TextEditingController(text: widget.entry.name);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await MobileApi.instance.qolipRenameSet(
        setId: widget.entry.set.id,
        name: _controller.text,
      );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        setState(() => _error = qolipErrorMessage(error,
            l10n: l10n, fallback: l10n.qolipManagementText('rename_failed')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.qolipManagementText('rename')),
        content: SingleChildScrollView(
          child: TextField(
            key: const ValueKey('qolip-set-name-field'),
            controller: _controller,
            autofocus: true,
            enabled: !_saving,
            maxLength: 160,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: l10n.qolipManagementText('name'),
              errorText: _error,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.qolipText('action.cancel')),
          ),
          FilledButton(
            key: const ValueKey('qolip-set-name-save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.qolipText('action.save')),
          ),
        ],
      ),
    );
  }
}
