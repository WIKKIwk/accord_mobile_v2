import '../../../core/api/mobile_api.dart';
import '../../../core/security/state/security_controller.dart';
import '../../../core/session/accounts/account_switch_runtime.dart';
import '../../../core/session/accounts/saved_account_runtime.dart';
import '../../../core/session/state/app_session.dart';
import 'account_switcher_sheet.dart';
import 'login_screen.dart';
import 'package:flutter/material.dart';

Future<void> showAccountSwitcherSheet(BuildContext context) async {
  final savedAccounts = SavedAccountRuntime.instance;
  if (!savedAccounts.isInitialized) {
    return;
  }
  final accounts = savedAccounts.store.accountsForEndpoint(MobileApi.baseUrl);
  if (accounts.isEmpty) {
    return;
  }
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final switchController = createRuntimeAccountSwitchController();

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.82,
        child: AccountSwitcherSheet(
          accounts: accounts,
          activeAccountId: savedAccounts.store.activeAccountId,
          hasPinForProfile: SecurityController.instance.hasPinForProfile,
          verifyPinForProfile: SecurityController.instance.verifyPinForProfile,
          onSwitch: (account) async {
            await switchController.switchTo(account.id);
            if (!sheetContext.mounted) {
              return;
            }
            Navigator.of(sheetContext).pop();
            rootNavigator.pushNamedAndRemoveUntil(
              AppSession.instance.homeRoute,
              (route) => false,
            );
          },
          onAddAccount: () {
            Navigator.of(sheetContext).pop();
            rootNavigator.push(
              MaterialPageRoute<void>(
                builder: (loginContext) => LoginScreen(
                  addAccountMode: true,
                  onBack: () => Navigator.of(loginContext).pop(),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
