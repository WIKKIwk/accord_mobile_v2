import 'package:accord_mobile_v2/src/features/admin/presentation/admin_customer_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_dock.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

part 'admin_customer_detail_screen_test_cases_resplit_part_01.dart';
part 'admin_customer_detail_screen_test_cases_resplit_part_02.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _registeradmin_customer_detail_screen_testCases01();

  _registeradmin_customer_detail_screen_testCases02();
}
