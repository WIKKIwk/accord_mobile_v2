import '../../localization/app_localizations.dart';
import '../../session/accounts/account_switch_runtime.dart';
import 'm3_confirm_dialog.dart';
import 'package:flutter/material.dart';

Future<void> showLogoutPrompt(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final l10n = context.l10n;
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showM3ConfirmDialog(
    context: context,
    title: l10n.logoutTitle,
    message: l10n.logoutPrompt,
    cancelLabel: l10n.no,
    confirmLabel: l10n.yes,
    blurBackground: true,
    dialogRadius: 22,
    buttonRadius: 14,
    confirmBackgroundColor: scheme.primary,
    confirmForegroundColor: scheme.onPrimary,
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
