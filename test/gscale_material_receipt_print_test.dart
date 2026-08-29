import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/native_usb_printer.dart';
import 'package:accord_mobile_v2/src/core/print_service.dart';
import 'package:accord_mobile_v2/src/core/print_transport.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/features/gscale/gscale_mobile_app.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'gscale_material_receipt_print_test_cases_resplit_part_01.dart';
part 'gscale_material_receipt_print_test_cases_resplit_part_02.dart';
part 'gscale_material_receipt_print_test_cases_resplit_part_03.dart';
part 'gscale_material_receipt_print_test_cases_resplit_part_04.dart';
part 'gscale_material_receipt_print_test_cases_resplit_part_05.dart';

void main() {
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  _registergscale_material_receipt_print_testCases01();

  _registergscale_material_receipt_print_testCases02();

  _registergscale_material_receipt_print_testCases03();

  _registergscale_material_receipt_print_testCases04();

  _registergscale_material_receipt_print_testCases05();
}
