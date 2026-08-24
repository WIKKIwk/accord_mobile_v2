import '../../../core/api/mobile_api.dart';
import '../../../core/app_preview.dart';
import '../../../core/security/state/security_controller.dart';
import '../../../core/session/accounts/account_switch_runtime.dart';
import '../../../core/session/accounts/saved_account_runtime.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import 'account_switcher_sheet.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import 'package:flutter/material.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  bool _booting = true;
  bool _showLogin = false;
  bool _showWelcome = false;
  bool _showSavedAccounts = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    if (!AppSession.instance.isLoggedIn) {
      if (AppPreview.hasPreviewLoginCredentials) {
        try {
          await MobileApi.instance
              .login(
                phone: AppPreview.previewPhone,
                code: AppPreview.previewCode,
              )
              .timeout(const Duration(seconds: 6));
        } catch (_) {}
      }
    }

    if (!AppSession.instance.isLoggedIn) {
      if (!mounted) {
        return;
      }
      setState(() {
        _booting = false;
        _showSavedAccounts = _hasSavedAccounts;
        _showWelcome = !_showSavedAccounts;
        _showLogin = false;
      });
      return;
    }

    if (!AppSession.instance.isTestModeSession) {
      try {
        await MobileApi.instance.profile().timeout(const Duration(seconds: 2));
      } catch (_) {
        // Keep existing local session on transient network/backend failures.
      }
    }

    if (!mounted) {
      return;
    }

    if (!AppSession.instance.isLoggedIn) {
      setState(() {
        _booting = false;
        _showSavedAccounts = _hasSavedAccounts;
        _showWelcome = false;
        _showLogin = !_showSavedAccounts;
      });
      return;
    }

    _navigated = true;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppPreview.initialRouteOverride ?? AppSession.instance.homeRoute,
      (route) => false,
    );
  }

  bool get _hasSavedAccounts {
    final runtime = SavedAccountRuntime.instance;
    return runtime.isInitialized &&
        runtime.store.accountsForEndpoint(MobileApi.baseUrl).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_showSavedAccounts) {
      final runtime = SavedAccountRuntime.instance;
      final accounts = runtime.store.accountsForEndpoint(MobileApi.baseUrl);
      return Scaffold(
        body: AccountSwitcherSheet(
          accounts: accounts,
          activeAccountId: runtime.store.activeAccountId,
          hasPinForProfile: SecurityController.instance.hasSwitchPinForProfile,
          verifyPinForProfile:
              SecurityController.instance.verifySwitchPinForProfile,
          onSwitch: (account) async {
            await createRuntimeAccountSwitchController().switchTo(account.id);
            if (!mounted) {
              return;
            }
            Navigator.of(this.context).pushNamedAndRemoveUntil(
              AppSession.instance.homeRoute,
              (route) => false,
            );
          },
          onAddAccount: () {
            setState(() {
              _showSavedAccounts = false;
              _showWelcome = false;
              _showLogin = true;
            });
          },
        ),
      );
    }
    if (_showWelcome || _showLogin) {
      final scheme = Theme.of(context).colorScheme;
      final Color authBackgroundColor =
          Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF000000)
              : scheme.surfaceContainerLow;
      final Widget currentScreen = _showWelcome
          ? WelcomeScreen(
              key: const ValueKey<String>('welcome-screen'),
              useSharedBackground: true,
              onGetStarted: () async {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _showSavedAccounts = false;
                  _showWelcome = false;
                  _showLogin = true;
                });
              },
            )
          : LoginScreen(
              key: const ValueKey<String>('login-screen'),
              useSharedBackground: true,
              onBack: () {
                setState(() {
                  _showLogin = false;
                  _showSavedAccounts = _hasSavedAccounts;
                  _showWelcome = !_showSavedAccounts;
                });
              },
            );

      return Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: authBackgroundColor),
            child: IgnorePointer(
              child: AuthAmbientOutlineBackground(
                outlineColor: scheme.outlineVariant,
                accentColor: scheme.primary,
                backgroundColor: authBackgroundColor,
                isDarkBackground:
                    Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 340),
            reverseDuration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: currentScreen,
          ),
        ],
      );
    }

    return AppShell(
      title: 'Accord Mobile',
      subtitle: '',
      child: Center(
        child: _navigated
            ? const SizedBox.shrink()
            : _booting
                ? const AppLoadingIndicator()
                : const SizedBox.shrink(),
      ),
    );
  }
}
