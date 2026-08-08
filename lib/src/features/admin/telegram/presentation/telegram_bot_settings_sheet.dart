import '../../../../core/localization/app_localizations.dart';
import '../models/telegram_models.dart';
import 'package:flutter/material.dart';

class TelegramBotSettingsInput {
  const TelegramBotSettingsInput({
    required this.botUsername,
    required this.botToken,
  });

  final String botUsername;
  final String botToken;
}

class TelegramBotSettingsSheet extends StatefulWidget {
  const TelegramBotSettingsSheet({
    super.key,
    required this.initial,
  });

  final TelegramBotSettings initial;

  @override
  State<TelegramBotSettingsSheet> createState() =>
      _TelegramBotSettingsSheetState();
}

class _TelegramBotSettingsSheetState extends State<TelegramBotSettingsSheet> {
  late final TextEditingController _usernameController;
  late final TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.initial.botUsername,
    );
    _tokenController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      TelegramBotSettingsInput(
        botUsername: username,
        botToken: _tokenController.text.trim(),
      ),
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
              l10n.adminTelegramBotSettingsTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adminTelegramBotSettingsSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.adminTelegramBotUsernameLabel,
                hintText: 'accord_order_bot',
                prefixText: '@',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tokenController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.adminTelegramBotTokenLabel,
                hintText: widget.initial.tokenConfigured
                    ? widget.initial.tokenHint
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adminTelegramBotTokenHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save_rounded),
              label: Text(l10n.adminTelegramSaveBotSettings),
            ),
          ],
        ),
      ),
    );
  }
}
