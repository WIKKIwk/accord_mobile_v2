import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/display/motion_widgets.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart' show AppRefreshIndicator;
import '../logic/admin_aparatchi_assignment.dart';
import '../logic/canonical_apparatus_display.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_apparatus_scope_picker.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_shell.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

part 'admin_roles_screen_widgets_part_01.dart';
part 'admin_roles_screen_widgets_part_02.dart';
part 'admin_roles_screen_models_part_03.dart';
part 'admin_roles_screen_helpers_part_04.dart';

const double _adminRolesPanelGap = 4;
