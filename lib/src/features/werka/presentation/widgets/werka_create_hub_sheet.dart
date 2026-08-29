import 'dart:async';
import 'dart:math' as math;

import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/navigation/app_navigation_bar.dart';
import '../../../../core/widgets/navigation/dock_gesture_overlay.dart';
import '../../../../core/widgets/navigation/dock_system_bottom_inset.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/material.dart';

part 'werka_create_hub_sheet_widgets_part_01.dart';
part 'werka_create_hub_sheet_declarations_part_02.dart';

final ValueNotifier<bool> werkaCreateHubMenuOpen = ValueNotifier<bool>(false);
const double _werkaHubMenuItemHeight = 56.0;
const double _werkaHubActionPaddingStart = 14.0;
const double _werkaHubActionPaddingEnd = 14.0;
const double _werkaHubActionIconGap = 10.0;

OverlayEntry? _werkaCreateHubOverlayEntry;
final GlobalKey<_WerkaCreateHubOverlayState> _werkaCreateHubOverlayKey =
    GlobalKey<_WerkaCreateHubOverlayState>();
