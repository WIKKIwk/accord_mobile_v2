import 'dart:async';
import 'dart:convert';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/mobile_api.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/native_bluetooth_printer.dart';
import '../../core/native_usb_printer.dart';
import '../../core/print_service.dart';
import '../../core/print_transport.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../core/widgets/lists/m3_segmented_list.dart';
import '../../core/widgets/navigation/app_navigation_bar.dart';
import '../../core/widgets/printing/bluetooth_printer_list.dart';
import '../shared/models/app_models.dart';
import '../admin/presentation/widgets/admin_summary_card.dart';
import '../werka/presentation/widgets/m3_picker_sheet.dart';
import 'gscale_catalog.dart';
import 'network_candidates_stub.dart'
    if (dart.library.io) 'network_candidates_io.dart' as network_candidates;

// Keep in sync with gscale-zebra mobileapi approved ports.

part 'gscale_mobile_app__OperatorDashboardPageState_methods_01.dart';
part 'gscale_mobile_app__OperatorDashboardPageState_methods_02.dart';
part 'gscale_mobile_app__OperatorDashboardPageState_methods_03.dart';
part 'gscale_mobile_app__OperatorDashboardPageState_methods_04.dart';
part 'gscale_mobile_app__OperatorDashboardPageState_methods_05.dart';
part 'gscale_mobile_app__OperatorDashboardPageState_methods_06.dart';
part 'gscale_mobile_app_declarations_part_01.dart';
part 'gscale_mobile_app_widgets_part_02.dart';
part 'gscale_mobile_app_declarations_part_03.dart';
part 'gscale_mobile_app_declarations_part_04.dart';
part 'gscale_mobile_app_models_part_05.dart';
part 'gscale_mobile_app_declarations_part_06.dart';
part 'gscale_mobile_app_helpers_part_07.dart';
part 'gscale_mobile_app_models_part_08.dart';
part 'gscale_mobile_app_declarations_part_09.dart';
part 'gscale_mobile_app_helpers_part_10.dart';
part 'gscale_mobile_app_helpers_part_11.dart';
part 'gscale_mobile_app__OperatorDashboardPageState_resplit_class.dart';

const _defaultApiPort = 39117;
const _discoveryPort = 18081;
const _fastProbeTimeout = Duration(milliseconds: 350);
const _manualProbeTimeout = Duration(seconds: 2);
const _udpDiscoveryTimeout = Duration(milliseconds: 900);
const _fallbackProbeTimeout = Duration(milliseconds: 240);
const _fallbackProbeConcurrency = 24;
const _directProbePorts = <int>[39117, 41257, 43391, 45533, 47681];
const _enableAutomaticSubnetSweep = false;
const _lastServerKey = 'last_server_base_url';
const _cachedServersKey = 'cached_servers_v1';
const _controlDraftKey = 'operator_control_draft_v1';
const _lastPrintDeviceKey = 'gscale_last_print_device_v1';
const _defaultWifiServerAddress = 'http://gscale.local:39117';
const _platformDiscoveryTimeout = Duration(milliseconds: 900);
const _bonjourDiscoveryChannel = MethodChannel('gscale/bonjour');
const _nsdDiscoveryChannel = MethodChannel('gscale/nsd');
const _udpDiscoveryChannel = MethodChannel('gscale/udp_discovery');
const _platformDiscoveryServiceTypes = <String>[
  '_gscale-mobileapi._tcp.',
  '_rp-scale._tcp.',
];
const _minManualPrintKg = 0.100;
const _catalogPickerPageSize = 50;
const _configuredApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: _defaultWifiServerAddress,
);
