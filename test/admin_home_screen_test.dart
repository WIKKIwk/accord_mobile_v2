import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/theme/theme_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/display/motion_widgets.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_home_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_navigation_drawer.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_store.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/profile_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_home_screen_test_declarations_part_01.dart';
part 'admin_home_screen_test_cases_resplit_part_01.dart';
part 'admin_home_screen_test_cases_resplit_part_02.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  _registeradmin_home_screen_testCases01();

  _registeradmin_home_screen_testCases02();
}
