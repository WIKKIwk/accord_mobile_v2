import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../models/telegram_models.dart';

class TelegramUserbotSettingsInput {
  const TelegramUserbotSettingsInput({
    required this.apiId,
    required this.apiHash,
  });

  final int apiId;
  final String apiHash;
}

class TelegramUserbotSettingsSheet extends StatefulWidget {
  const TelegramUserbotSettingsSheet({
    super.key,
    required this.initial,
  });

  final TelegramUserbotSettings initial;

  @override
  State<TelegramUserbotSettingsSheet> createState() =>
      _TelegramUserbotSettingsSheetState();
}

class _TelegramUserbotSettingsSheetState
    extends State<TelegramUserbotSettingsSheet> {
  late final TextEditingController _apiIdController;
  late final TextEditingController _apiHashController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiIdController = TextEditingController(
      text: widget.initial.apiId?.toString() ?? '',
    );
    _apiHashController = TextEditingController();
  }

  @override
  void dispose() {
    _apiIdController.dispose();
    _apiHashController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final apiId = int.tryParse(_apiIdController.text.trim());
    final apiHash = _apiHashController.text.trim();
    if (apiId == null || apiId <= 0) {
      setState(() => _error = l10n.adminTelegramUserbotApiIdInvalid);
      return;
    }
    if (apiHash.isEmpty && !widget.initial.apiHashConfigured) {
      setState(() => _error = l10n.adminTelegramUserbotApiHashRequired);
      return;
    }
    if (apiHash.isNotEmpty &&
        (apiHash.length != 32 ||
            !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(apiHash))) {
      setState(() => _error = l10n.adminTelegramUserbotApiHashInvalid);
      return;
    }
    Navigator.of(context).pop(
      TelegramUserbotSettingsInput(apiId: apiId, apiHash: apiHash),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.adminTelegramUserbotSettingsTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adminTelegramUserbotSettingsSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _apiIdController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.adminTelegramUserbotApiIdLabel,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _apiHashController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.adminTelegramUserbotApiHashLabel,
                hintText: widget.initial.apiHashConfigured
                    ? l10n.adminTelegramUserbotApiHashKeepHint
                    : '32 ta hex belgi',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save_rounded),
              label: Text(l10n.adminTelegramSaveUserbotSettings),
            ),
          ],
        ),
      ),
    );
  }
}
