import '../../localization/app_localizations.dart';
import '../../session/accounts/account_switch_runtime.dart';
import 'm3_confirm_dialog.dart';
import 'package:flutter/material.dart';

Future<void> showLogoutPrompt(BuildContext context) async {
  final l10n = context.l10n;
  await _showSessionEndPrompt(
    context,
    title: l10n.logoutTitle,
    message: l10n.logoutPrompt,
    confirmLabel: l10n.yes,
    destructive: false,
  );
}

Future<void> showDisconnectSessionPrompt(BuildContext context) async {
  final l10n = context.l10n;
  await _showSessionEndPrompt(
    context,
    title: l10n.disconnectSessionTitle,
    message: l10n.disconnectSessionPrompt,
    confirmLabel: l10n.disconnectSessionConfirm,
    destructive: true,
  );
}

Future<void> _showSessionEndPrompt(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required bool destructive,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final l10n = context.l10n;
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showM3ConfirmDialog(
    context: context,
    title: title,
    message: message,
    cancelLabel: l10n.no,
    confirmLabel: confirmLabel,
    blurBackground: true,
    dialogRadius: 22,
    buttonRadius: 14,
    confirmBackgroundColor: destructive ? scheme.error : scheme.primary,
    confirmForegroundColor: destructive ? scheme.onError : scheme.onPrimary,
  );
  if (confirmed != true) {
    return;
  }

  await createRuntimeAccountSwitchController().logoutCurrent();
  if (!navigator.mounted) {
    return;
  }
  navigator.pushNamedAndRemoveUntil('/', (route) => false);
}
