import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_retry_state.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_loading_indicator.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_suppliers_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_user_create_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_worker_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_worker_profile_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_suppliers_screen_test_helpers_part_01.dart';
part 'admin_suppliers_screen_test_models_part_02.dart';
part 'admin_suppliers_screen_test_cases_resplit_part_01.dart';
part 'admin_suppliers_screen_test_cases_resplit_part_02.dart';
part 'admin_suppliers_screen_test_cases_resplit_part_03.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestModeController.instance.setEnabled(false);
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
    AdminSuppliersScreen.invalidateCache();
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    AdminSuppliersScreen.invalidateCache();
  });

  _registeradmin_suppliers_screen_testCases01();

  _registeradmin_suppliers_screen_testCases02();

  _registeradmin_suppliers_screen_testCases03();
}
