import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/native_bluetooth_printer.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_service.dart';
import '../../../core/print_transport.dart';
import '../../../core/widgets/feedback/app_dialog_action_row.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../../gscale/gscale_mobile_app.dart'
    show DiscoveredServer, driverUrlForRs, showPrintDevicePicker;
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../qolip_batch.dart';
import '../qolip_search_matcher.dart';
import '../state/qolip_data_revision.dart';
import 'qolip_cell_qr_scan_screen.dart';
import 'qolip_color_picker.dart';
import 'widgets/qolip_cell_picker_sheet.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

part 'qolip_home_screen__QolipHomeScreenState_methods_01.dart';
part 'qolip_home_screen__QolipHomeScreenState_methods_02.dart';
part 'qolip_home_screen__QolipHomeScreenState_methods_03.dart';
part 'qolip_home_screen__QolipHomeScreenState_methods_04.dart';
part 'qolip_home_screen__QolipBlockGrid_methods_05.dart';
part 'qolip_home_screen__QolipAttachSheetState_methods_06.dart';
part 'qolip_home_screen__QolipAttachSheetState_methods_07.dart';
part 'qolip_home_screen_widgets_part_01.dart';
part 'qolip_home_screen_models_part_02.dart';
part 'qolip_home_screen_declarations_part_03.dart';
part 'qolip_home_screen_widgets_part_04.dart';
part 'qolip_home_screen_helpers_part_05.dart';
part 'qolip_home_screen__QolipBlockGrid_resplit_class.dart';
part 'qolip_home_screen_models_resplit_part_01.dart';
part 'qolip_home_screen_models_resplit_part_02.dart';
