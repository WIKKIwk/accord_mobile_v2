import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/production_map_pechat_rules.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_test_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_production_map_p0_stress_test_helpers_part_01.dart';
part 'admin_production_map_p0_stress_test_cases_resplit_part_01.dart';
part 'admin_production_map_p0_stress_test_cases_resplit_part_02.dart';

const _print7Id = 'apparatus:default:bosma_7';
const _print8Id = 'apparatus:default:bosma_8';
const _print7Name = '7 ta rangli bosma aparat';
const _print8Name = '8 ta rangli bosma aparat';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
    );
    await TestModeController.instance.setEnabled(true);
    setMobileApiTestModeForceSequenceSaveFailure(false);
    setMobileApiTestModeForceCalculateTemplateSaveFailure(false);
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    setMobileApiTestModeForceSequenceSaveFailure(false);
    setMobileApiTestModeForceCalculateTemplateSaveFailure(false);
  });

  _registeradmin_production_map_p0_stress_testCases01();

  _registeradmin_production_map_p0_stress_testCases02();
}
