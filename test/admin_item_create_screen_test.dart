import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_loading_indicator.dart';
import 'package:accord_mobile_v2/src/features/admin/models/admin_item_group_tree_entry.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_item_create_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_search_field.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_summary_card.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_item_create_screen_test_widgets_part_01.dart';
part 'admin_item_create_screen_test_declarations_part_02.dart';
part 'admin_item_create_screen_test_cases_resplit_part_01.dart';
part 'admin_item_create_screen_test_cases_resplit_part_02.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
  });

  setUp(() {
    AdminItemsListTab.clearMemoryCache();
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  _registeradmin_item_create_screen_testCases01();

  _registeradmin_item_create_screen_testCases02();
}
