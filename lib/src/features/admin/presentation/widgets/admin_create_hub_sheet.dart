import 'dart:async';
import 'dart:math' as math;

import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/navigation/app_navigation_bar.dart';
import '../../../../core/widgets/navigation/dock_gesture_overlay.dart';
import '../../../../core/widgets/navigation/dock_system_bottom_inset.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/material.dart';

part 'admin_create_hub_sheet_widgets_part_01.dart';
part 'admin_create_hub_sheet_models_part_02.dart';
part 'admin_create_hub_sheet_declarations_part_03.dart';
part 'admin_create_hub_sheet_models_part_04.dart';
part 'admin_create_hub_sheet_models_part_05.dart';
part 'admin_create_hub_sheet_declarations_part_06.dart';

final ValueNotifier<bool> adminCreateHubMenuOpen = ValueNotifier<bool>(false);
const double _adminHubMenuItemHeight = 56.0;
const double _adminHubActionPaddingStart = 14.0;
const double _adminHubActionPaddingEnd = 14.0;
const double _adminHubActionIconGap = 10.0;

OverlayEntry? _adminCreateHubOverlayEntry;
final GlobalKey<_AdminCreateHubOverlayState> _adminCreateHubOverlayKey =
    GlobalKey<_AdminCreateHubOverlayState>();
