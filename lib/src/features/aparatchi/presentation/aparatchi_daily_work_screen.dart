import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/print_service.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/progress_printer_picker.dart';
import '../../admin/presentation/widgets/admin_drawer_navigation.dart';
import '../../shared/models/app_models.dart';
import 'widgets/aparatchi_dock.dart';
import 'widgets/aparatchi_navigation_drawer.dart';

part 'aparatchi_daily_work_screen_helpers_part_01.dart';
part 'aparatchi_daily_work_screen_models_part_02.dart';
part 'aparatchi_daily_work_screen_models_part_03.dart';
part 'aparatchi_daily_work_screen_models_part_04.dart';
part 'aparatchi_daily_work_screen_models_part_05.dart';
part 'aparatchi_daily_work_screen_models_part_06.dart';
