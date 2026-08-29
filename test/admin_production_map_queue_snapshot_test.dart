import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_production_map_queue_snapshot_test_cases_resplit_part_01.dart';
part 'admin_production_map_queue_snapshot_test_cases_resplit_part_02.dart';
part 'admin_production_map_queue_snapshot_test_cases_resplit_part_03.dart';

const _printId = 'apparatus:default:asset-005';
const _laminationId = 'apparatus:default:asset-007';
const _godexId = 'apparatus:test:godex-demo';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _registeradmin_production_map_queue_snapshot_testCases01();

  _registeradmin_production_map_queue_snapshot_testCases02();

  _registeradmin_production_map_queue_snapshot_testCases03();
}
