import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/shell/app_shell.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_create_hub_sheet.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'admin_calculate_materials_screen_widgets_part_01.dart';
part 'admin_calculate_materials_screen_widgets_part_02.dart';

final _decimalFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'));
