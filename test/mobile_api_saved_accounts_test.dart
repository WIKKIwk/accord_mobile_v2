import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/account_switch_controller.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/account_switch_runtime.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_runtime.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_store.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'mobile_api_saved_accounts_test_helpers_part_01.dart';
part 'mobile_api_saved_accounts_test_helpers_part_02.dart';
void main() => _largeLibrarySplitter_mobile_api_saved_accounts_test_main();
