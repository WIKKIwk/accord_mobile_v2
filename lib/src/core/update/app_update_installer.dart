import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_update_models.dart';

enum AppInstallLaunchResult { installerLaunched, permissionRequired }

abstract class AppUpdatePlatform {
  bool get isSupported;

  Future<AppInstallationInfo> currentAppInfo();

  Future<AppInstallLaunchResult> installApk({
    required String path,
    required String expectedPackageName,
    required int expectedVersionCode,
  });
}

class NativeAppUpdatePlatform implements AppUpdatePlatform {
  const NativeAppUpdatePlatform();

  static const MethodChannel _channel = MethodChannel('accord/app_update');

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<AppInstallationInfo> currentAppInfo() async {
    if (!isSupported) {
      throw const AppUpdateException(
        code: 'unsupported_platform',
        message: 'Bu platformada APK update ishlamaydi',
      );
    }
    final Map<Object?, Object?>? result;
    try {
      result = await _channel.invokeMapMethod<Object?, Object?>(
        'getCurrentAppInfo',
      );
    } on PlatformException catch (error) {
      throw AppUpdateException(
        code: error.code,
        message: error.message ?? 'Ilova versiyasi aniqlanmadi',
      );
    }
    if (result == null) {
      throw const AppUpdateException(
        code: 'app_info_failed',
        message: 'Ilova versiyasi aniqlanmadi',
      );
    }
    final info = AppInstallationInfo.fromMap(result);
    if (info.packageName.isEmpty || info.versionCode <= 0) {
      throw const AppUpdateException(
        code: 'app_info_failed',
        message: 'Ilova versiyasi aniqlanmadi',
      );
    }
    return info;
  }

  @override
  Future<AppInstallLaunchResult> installApk({
    required String path,
    required String expectedPackageName,
    required int expectedVersionCode,
  }) async {
    final Map<Object?, Object?>? result;
    try {
      result = await _channel.invokeMapMethod<Object?, Object?>(
        'installApk',
        {
          'path': path,
          'expectedPackageName': expectedPackageName,
          'expectedVersionCode': expectedVersionCode,
        },
      );
    } on PlatformException catch (error) {
      throw AppUpdateException(
        code: error.code,
        message: error.message ?? 'APK o‘rnatilmadi',
      );
    }
    return switch (result?['status']?.toString()) {
      'installer_launched' => AppInstallLaunchResult.installerLaunched,
      'permission_required' => AppInstallLaunchResult.permissionRequired,
      _ => throw const AppUpdateException(
          code: 'installer_failed',
          message: 'Android o‘rnatuvchisi ochilmadi',
        ),
    };
  }
}
