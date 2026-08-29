import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_training_api_test_helpers_part_01.dart';
part 'admin_training_api_test_cases_resplit_part_01.dart';
part 'admin_training_api_test_cases_resplit_part_02.dart';

const _laminationApparatusId = 'apparatus:default:asset-007';
const _laminationApparatusName = 'Laminatsiya 1';
const _secondLaminationApparatusId = 'apparatus:default:asset-008';
const _secondLaminationApparatusName = 'Laminatsiya 2';
const _rezkaApparatusId = 'apparatus:default:asset-010';
const _rezkaApparatusName = 'Rezka';
const _trainingBosmaInputStageId = 'training-input:bosma';
const _trainingLaminationInputStageId = 'training-input:laminatsiya';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
  });

  tearDown(() async {
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = null;
  });

  _registeradmin_training_api_testCases01();

  _registeradmin_training_api_testCases02();
}
