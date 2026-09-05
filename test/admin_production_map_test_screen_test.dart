import 'dart:async';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/production_map_pechat_rules.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/production_map_edit_policy.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/canonical_apparatus_groups.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_test_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/raw_material_scan_dialog.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_production_map_test_screen_test_helpers_part_01.dart';
part 'admin_production_map_test_screen_test_helpers_part_02.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_01.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_02.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_03.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_04.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_05.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_06.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_07.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_08.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_09.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_10.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_11.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_12.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_13.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_14.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_15.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_16.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_17.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_18.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_19.dart';
part 'admin_production_map_rezka_recorded_rolls_test_part.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_20.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_21.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_22.dart';
part 'admin_production_map_test_screen_test_cases_resplit_part_23.dart';

const _godexId = 'apparatus:test:godex-demo';
const _print7Id = 'apparatus:default:bosma_7';
const _print8Id = 'apparatus:default:bosma_8';
const _print9Id = 'apparatus:default:bosma_9';
const _flexoId = 'apparatus:default:asset-005';
const _lamination1Id = 'apparatus:default:asset-007';
const _lamination2Id = 'apparatus:default:asset-008';
const _rezkaId = 'apparatus:default:asset-010';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalMobileScannerPlatform = MobileScannerPlatform.instance;

  setUpAll(() {
    MobileScannerPlatform.instance = _TestMobileScannerPlatform();
  });

  tearDownAll(() {
    MobileScannerPlatform.instance = originalMobileScannerPlatform;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access'],
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    setMobileApiTestModeForceProductionMapMenuLoadFailure(false);
    setMobileApiTestModeForceProductionMapQueueSnapshotLoadFailure(false);
    setMobileApiTestModeForceCompletedProductionMapOrdersLoadFailure(false);
  });

  _registeradmin_production_map_test_screen_testCases01();

  _registeradmin_production_map_test_screen_testCases02();

  _registeradmin_production_map_test_screen_testCases03();

  _registeradmin_production_map_test_screen_testCases04();

  _registeradmin_production_map_test_screen_testCases05();

  _registeradmin_production_map_test_screen_testCases06();

  _registeradmin_production_map_test_screen_testCases07();

  _registeradmin_production_map_test_screen_testCases08();

  _registeradmin_production_map_test_screen_testCases09();

  _registeradmin_production_map_test_screen_testCases10();

  _registeradmin_production_map_test_screen_testCases11();

  _registeradmin_production_map_test_screen_testCases12();

  _registeradmin_production_map_test_screen_testCases13();

  _registeradmin_production_map_test_screen_testCases14();

  _registeradmin_production_map_test_screen_testCases15();

  _registeradmin_production_map_test_screen_testCases16();

  _registeradmin_production_map_test_screen_testCases17();

  _registeradmin_production_map_test_screen_testCases18();

  _registeradmin_production_map_test_screen_testCases19();
  _registerRezkaRecordedRollTests();

  _registeradmin_production_map_test_screen_testCases20();

  _registeradmin_production_map_test_screen_testCases21();

  _registeradmin_production_map_test_screen_testCases22();

  _registeradmin_production_map_test_screen_testCases23();
}
