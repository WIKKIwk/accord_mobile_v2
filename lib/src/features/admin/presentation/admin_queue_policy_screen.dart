import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_top_notice.dart';
import 'dart:async';
import 'package:flutter/material.dart';

part 'admin_queue_policy_screen_widgets_part_01.dart';
part 'admin_queue_policy_screen_declarations_part_02.dart';

const double _queuePolicyPanelGap = 4;
const double _queuePolicyPanelTopGap = 8;
