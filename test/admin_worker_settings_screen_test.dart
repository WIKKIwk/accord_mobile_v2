import 'dart:io';
import 'dart:ui' as ui;

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_worker_settings_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_top_notice.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_worker_settings_screen_test_cases_resplit_part_01.dart';
part 'admin_worker_settings_screen_test_cases_resplit_part_02.dart';

const _googleSansTestAssets = [
  'assets/fonts/google_sans/GoogleSans-Regular.ttf',
  'assets/fonts/google_sans/GoogleSans-Medium.ttf',
  'assets/fonts/google_sans/GoogleSans-Bold.ttf',
  'assets/fonts/google_sans/GoogleSans-Italic.ttf',
  'assets/fonts/google_sans/GoogleSans-MediumItalic.ttf',
  'assets/fonts/google_sans/GoogleSans-BoldItalic.ttf',
];

Future<void> _loadGoogleSansTestFont() async {
  final fontLoader = FontLoader(AppTheme.fontFamily);
  for (final fontAsset in _googleSansTestAssets) {
    fontLoader.addFont(rootBundle.load(fontAsset));
  }
  await fontLoader.load();
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    dismissAdminTopNotice();
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeWorkerSettingsData();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access'],
    );
  });

  tearDown(() async {
    dismissAdminTopNotice();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await TestModeController.instance.setEnabled(false);
  });

  _registeradmin_worker_settings_screen_testCases01();

  _registeradmin_worker_settings_screen_testCases02();
}
