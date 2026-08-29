import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/theme/theme_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_raw_material_rules_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_raw_material_rules_screen_test_helpers_part_01.dart';
part 'admin_raw_material_rules_screen_test_declarations_part_02.dart';
part 'admin_raw_material_rules_screen_test_cases_resplit_part_01.dart';
part 'admin_raw_material_rules_screen_test_cases_resplit_part_02.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'raw_material.rule.manage'],
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  _registeradmin_raw_material_rules_screen_testCases01();

  _registeradmin_raw_material_rules_screen_testCases02();
}

const _apparatusId = 'apparatus:default:asset-005';
const _aasxSha256 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
