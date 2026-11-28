import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme_controller.dart';

part 'app_theme_AppTheme_resplit_class.dart';
part 'app_theme_AppTheme_resplit_class_AppTheme_resplit2_static_appBarHeight.dart';
part 'app_theme_AppTheme_resplit_class_AppTheme_resplit2_static_headerActionSize.dart';
part 'app_theme_AppTheme_resplit_class_AppTheme_resplit2_static_headerActionIconSize.dart';
part 'app_theme_AppTheme_resplit_class_AppTheme_resplit2_static_methods_01.dart';
part 'app_theme_AppTheme_resplit_class_AppTheme_resplit2_static_methods_02.dart';

extension MaterialRowColors on ColorScheme {
  Color get paddonMaterialTint => brightness == Brightness.dark
      ? const Color(0xFFF48FB1)
      : const Color(0xFFC2185B);

  Color tintedMaterialRow(Color tint) => Color.alphaBlend(
        tint.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12),
        surfaceContainerLowest,
      );
}
