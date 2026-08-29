import 'dart:math' as math;
import 'dart:async';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/test_mode/test_mode_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/display/motion_widgets.dart';
import 'package:androidx_graphics_shapes/material_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

part 'welcome_screen__WelcomeScreenState_methods_01.dart';
part 'welcome_screen_widgets_part_01.dart';
part 'welcome_screen_models_part_02.dart';
part 'welcome_screen_declarations_part_03.dart';
part 'welcome_screen_widgets_part_04.dart';

final _ShapeProfile _ambientOvalProfile = _ShapeProfile.fromPath(
  MaterialShapes.oval.toPath(),
);
final _ShapeProfile _ambientCookieProfile = _ShapeProfile.fromPath(
  MaterialShapes.cookie12Sided.toPath(),
);

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const List<Locale> _headlineLocales = <Locale>[
    Locale('uz'),
    Locale('en'),
    Locale('ru'),
  ];

  late final AnimationController _headlineController = AnimationController(
    vsync: this,
  )..addStatusListener(_handleHeadlineStatus);

  Timer? _headlineTimer;
  int _headlineIndex = 0;
  String _headlinePhase = 'idle';
  bool _lockToSelectedLocale = false;

  @override
  void initState() {
    super.initState();
    if (LocaleController.instance.hasExplicitSelection) {
      _lockToSelectedLocale = true;
      _headlineIndex = _headlineLocales.indexWhere(
        (item) =>
            item.languageCode == LocaleController.instance.locale.languageCode,
      );
      if (_headlineIndex < 0) {
        _headlineIndex = 0;
      }
    }
    _scheduleHeadlineCycle();
  }

  @override
  void dispose() {
    _headlineTimer?.cancel();
    _headlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final Locale displayLocale = _lockToSelectedLocale
        ? LocaleController.instance.locale
        : _headlineLocales[_headlineIndex];
    final AppLocalizations displayL10n = AppLocalizations(displayLocale);
    final double headlineFontSize = 46;
    final double headlineLineHeight = 1.02 * headlineFontSize;
    final double headlineHeight = headlineLineHeight * 3.15;
    final TextStyle? primaryButtonLabelStyle =
        theme.textTheme.labelMedium?.copyWith(
      color: scheme.onPrimary,
      fontWeight: FontWeight.w700,
      fontSize: 18,
      letterSpacing: -0.2,
    );
    final double primaryButtonWidth = _measurePrimaryButtonWidth(
      context,
      displayL10n.getStarted,
      primaryButtonLabelStyle,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([
        LocaleController.instance,
        ThemeController.instance,
        _headlineController,
      ]),
      builder: (context, _) {
        final currentLocale = LocaleController.instance.locale;
        final currentVariant = ThemeController.instance.variant;
        final Color authBackgroundColor = ThemeController.instance.isDark
            ? const Color(0xFF000000)
            : scheme.surfaceContainerLow;

        return Scaffold(
          backgroundColor: widget.useSharedBackground
              ? Colors.transparent
              : authBackgroundColor,
          body: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.useSharedBackground
                  ? Colors.transparent
                  : authBackgroundColor,
            ),
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
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      mediaQuery.size.height >= 760 ? 18 : 8,
                      24,
                      mediaQuery.padding.bottom + 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 180),
                        const Spacer(),
                        SmoothAppear(
                          delay: const Duration(milliseconds: 40),
                          offset: const Offset(0, 16),
                          child: SizedBox(
                            height: headlineHeight,
                            child: _buildAnimatedText(
                              displayL10n.welcomeToAccord,
                              style: GoogleFonts.manrope(
                                fontSize: headlineFontSize,
                                height: 1.02,
                                letterSpacing: -1.7,
                                fontWeight: FontWeight.w400,
                                color: scheme.onSurface,
                              ),
                              maxLines: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SmoothAppear(
                          delay: const Duration(milliseconds: 110),
                          offset: const Offset(0, 14),
                          child: _WelcomeSelectionRow(
                            icon: Icons.language_rounded,
                            label: _buildSoftAnimatedText(
                              displayL10n.languageTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 21,
                                color: scheme.onSurface,
                              ),
                            ),
                            value: _buildSoftAnimatedText(
                              LocaleController.instance.hasExplicitSelection
                                  ? _localeLabel(displayL10n, currentLocale)
                                  : displayL10n.languageUnselected,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                color: scheme.onSurface.withValues(alpha: 0.72),
                              ),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _pickLocale(context, currentLocale),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SmoothAppear(
                          delay: const Duration(milliseconds: 150),
                          offset: const Offset(0, 14),
                          child: _WelcomeSelectionRow(
                            icon: Icons.palette_outlined,
                            label: _buildSoftAnimatedText(
                              displayL10n.themeTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 21,
                                color: scheme.onSurface,
                              ),
                            ),
                            value: _buildSoftAnimatedText(
                              _themeLabel(displayL10n, currentVariant),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                color: scheme.onSurface.withValues(alpha: 0.72),
                              ),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _pickTheme(context, currentVariant),
                            onHoldComplete: _confirmTestMode,
                            holdDuration: const Duration(seconds: 3),
                          ),
                        ),
                        const SizedBox(height: 58),
                        SmoothAppear(
                          delay: const Duration(milliseconds: 190),
                          offset: const Offset(0, 10),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeInOutCubicEmphasized,
                              width: primaryButtonWidth,
                              child: SizedBox(
                                height: 54,
                                child: FilledButton(
                                  onPressed: widget.onGetStarted,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 15,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: _buildSoftAnimatedText(
                                    displayL10n.getStarted,
                                    style: primaryButtonLabelStyle,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
