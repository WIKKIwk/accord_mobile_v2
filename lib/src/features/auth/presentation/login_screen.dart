import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/app_preview.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/network/network_required_dialog.dart';
import '../../../core/notifications/service/push_messaging_service.dart';
import '../../../core/security/state/security_controller.dart';
import '../../../core/session/accounts/account_switch_runtime.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/test_mode/test_mode_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/display/motion_widgets.dart';
import '../../shared/models/app_models.dart';
import 'welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'login_screen__LoginScreenState_methods_01.dart';
part 'login_screen_helpers_part_01.dart';

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final FocusNode phoneFocusNode = FocusNode();
  final FocusNode codeFocusNode = FocusNode();
  String? errorText;
  bool loading = false;
  double _backSwipeOffset = 0;
  int? _backSwipePointer;
  Offset? _backSwipeStartGlobal;
  bool _trackingBackSwipe = false;
  bool _backSwipeTriggered = false;

  bool get _canSubmit =>
      phoneController.text.trim().isNotEmpty &&
      codeController.text.trim().isNotEmpty;

  bool get _numericRolePrefixSelected {
    final code = codeController.text.trim();
    return code.length >= 2 && loginCodeUsesNumericKeyboard(code);
  }

  @override
  void initState() {
    super.initState();
    phoneController.addListener(_handleInputChanged);
    codeController.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    phoneController.removeListener(_handleInputChanged);
    codeController.removeListener(_handleInputChanged);
    phoneController.dispose();
    codeController.dispose();
    phoneFocusNode.dispose();
    codeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeController.instance,
        LocaleController.instance,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final l10n = AppLocalizations.of(context);
        final bool isDark = ThemeController.instance.isDark;
        final Color authBackgroundColor =
            isDark ? const Color(0xFF000000) : scheme.surfaceContainerLow;
        final Color inputFillColor =
            isDark ? const Color(0xFF000000) : scheme.surface;
        final darkTheme = theme.copyWith(
          colorScheme: scheme.copyWith(
            surface: const Color(0xFF000000),
            surfaceContainerLowest: const Color(0xFF000000),
            surfaceContainerLow: const Color(0xFF000000),
            surfaceContainer: const Color(0xFF000000),
            surfaceContainerHigh: const Color(0xFF000000),
            surfaceContainerHighest: const Color(0xFF000000),
          ),
          scaffoldBackgroundColor: const Color(0xFF000000),
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            filled: true,
            fillColor: inputFillColor,
            labelStyle: theme.inputDecorationTheme.labelStyle?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.82),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.44),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 17,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.94),
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: scheme.primary.withValues(alpha: 0.96),
                width: 1.35,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.94),
                width: 1.0,
              ),
            ),
          ),
        );

        return Theme(
          key: ValueKey<String>('login-${ThemeController.instance.variant}'),
          data: darkTheme,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handleBackSwipePointerDown,
            onPointerMove: _handleBackSwipePointerMove,
            onPointerUp: (event) => _handleBackSwipePointerEnd(event.pointer),
            onPointerCancel: (event) =>
                _handleBackSwipePointerEnd(event.pointer),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(_backSwipeOffset, 0, 0),
              child: AppShell(
                title: '',
                subtitle: '',
                backgroundColor: widget.useSharedBackground
                    ? Colors.transparent
                    : authBackgroundColor,
                leading: widget.onBack == null
                    ? null
                    : IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                child: Stack(
                  children: [
                    if (!widget.useSharedBackground)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AuthAmbientOutlineBackground(
                            outlineColor: scheme.outlineVariant,
                            accentColor: scheme.primary,
                            backgroundColor: authBackgroundColor,
                            isDarkBackground: ThemeController.instance.isDark,
                          ),
                        ),
                      ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double topSpacing =
                            constraints.maxHeight >= 760 ? 160 : 120;
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 396,
                                minHeight: constraints.maxHeight,
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  0,
                                  topSpacing,
                                  0,
                                  28,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SmoothAppear(
                                      delay: const Duration(milliseconds: 20),
                                      offset: const Offset(0, 12),
                                      child: Text(
                                        widget.addAccountMode
                                            ? l10n.addProfileTitle
                                            : l10n.signInTitle,
                                        style: theme.textTheme.displaySmall
                                            ?.copyWith(
                                          fontSize: 40,
                                          letterSpacing: -1.4,
                                          height: 1.02,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    SmoothAppear(
                                      delay: const Duration(milliseconds: 170),
                                      offset: const Offset(0, 12),
                                      child: AutofillGroup(
                                        child: Column(
                                          children: [
                                            TextField(
                                              controller: phoneController,
                                              focusNode: phoneFocusNode,
                                              textInputAction:
                                                  TextInputAction.next,
                                              keyboardType: TextInputType.phone,
                                              autocorrect: false,
                                              enableSuggestions: true,
                                              autofillHints: const [
                                                AutofillHints.telephoneNumber,
                                              ],
                                              decoration: InputDecoration(
                                                labelText: l10n.phoneLabel,
                                                hintText: '+998901234567',
                                                prefixIcon: const Icon(
                                                  Icons.phone_outlined,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            TextField(
                                              controller: codeController,
                                              focusNode: codeFocusNode,
                                              textInputAction:
                                                  TextInputAction.done,
                                              keyboardType:
                                                  loginCodeUsesNumericKeyboard(
                                                codeController.text,
                                              )
                                                      ? TextInputType.number
                                                      : TextInputType.text,
                                              inputFormatters:
                                                  _numericRolePrefixSelected
                                                      ? [
                                                          FilteringTextInputFormatter
                                                              .digitsOnly,
                                                        ]
                                                      : null,
                                              autocorrect: false,
                                              enableSuggestions: false,
                                              onSubmitted: (_) {
                                                if (!loading) {
                                                  submitLogin(context);
                                                }
                                              },
                                              decoration: InputDecoration(
                                                labelText: l10n.codeLabel,
                                                hintText:
                                                    _numericRolePrefixSelected
                                                        ? '40XXXXXXXXXX'
                                                        : '10XXXXXXXXXX',
                                                prefixIcon: const Icon(
                                                  Icons.password_outlined,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (errorText != null) ...[
                                      const SizedBox(height: 14),
                                      SmoothAppear(
                                        delay: const Duration(
                                          milliseconds: 210,
                                        ),
                                        offset: const Offset(0, 8),
                                        child: _LoginErrorBanner(
                                          message: errorText!,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 22),
                                    SmoothAppear(
                                      delay: const Duration(milliseconds: 220),
                                      offset: const Offset(0, 10),
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 260,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        opacity:
                                            (_canSubmit || loading) ? 1 : 0,
                                        child: AnimatedSlide(
                                          duration: const Duration(
                                            milliseconds: 260,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          offset: (_canSubmit || loading)
                                              ? Offset.zero
                                              : const Offset(0, 0.08),
                                          child: IgnorePointer(
                                            ignoring: !_canSubmit && !loading,
                                            child: FilledButton(
                                              onPressed: loading
                                                  ? null
                                                  : _canSubmit
                                                      ? () =>
                                                          submitLogin(context)
                                                      : null,
                                              child: loading
                                                  ? const SizedBox(
                                                      height: 18,
                                                      width: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2.2,
                                                      ),
                                                    )
                                                  : Text(
                                                      widget.addAccountMode
                                                          ? l10n.accountAdd
                                                          : l10n.loginAction,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
