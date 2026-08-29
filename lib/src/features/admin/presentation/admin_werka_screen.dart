import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/timers/retry_after_countdown.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/display/app_detail_field.dart';
import '../../../core/widgets/display/app_status_chip.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/models/app_models.dart';
import '../../shared/presentation/widgets/profile_info_chip.dart';
import '../../chat/models/chat_models.dart';
import '../../chat/presentation/widgets/chat_profile_action_button.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_profile_avatar.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'admin_werka_screen_widgets_part_01.dart';
part 'admin_werka_screen_widgets_part_02.dart';

const double _werkaDetailPanelGap = 4;
const double _werkaDetailFieldRadius = 14;
