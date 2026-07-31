import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../api/mobile_api.dart';
import 'app_update_installer.dart';
import 'app_update_models.dart';

typedef AppUpdateProgress = void Function(int receivedBytes, int totalBytes);
typedef TemporaryDirectoryProvider = Future<Directory> Function();

class AppUpdateCancellation {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    AppUpdatePlatform? platform,
    TemporaryDirectoryProvider? temporaryDirectoryProvider,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _platform = platform ?? const NativeAppUpdatePlatform(),
        _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory,
        _baseUriOverride = baseUri;

  static final AppUpdateService instance = AppUpdateService();
  static const int _maximumManifestBytes = 128 * 1024;
  static const int _maximumApkBytes = 512 * 1024 * 1024;

  final http.Client _client;
  final AppUpdatePlatform _platform;
  final TemporaryDirectoryProvider _temporaryDirectoryProvider;
  final Uri? _baseUriOverride;

  Uri get _baseUri => _baseUriOverride ?? Uri.parse(MobileApi.baseUrl);

  bool get isSupported => _platform.isSupported;

  Future<AppUpdateCheckResult> check() async {
    if (!isSupported) {
      throw const AppUpdateException(
        code: 'unsupported_platform',
        message: 'Bu platformada APK update ishlamaydi',
      );
    }
    final current = await _platform.currentAppInfo();
    final endpoint = _baseUri.resolve('/v1/mobile/app-update/android');
    final response = await _client
        .send(http.Request('GET', endpoint))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == HttpStatus.noContent) {
      return AppUpdateCheckResult(current: current, manifest: null);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw AppUpdateException(
        code: 'update_check_failed',
        message: 'Yangilanish tekshirilmadi (${response.statusCode})',
      );
    }
    final body = await _readLimited(
      response.stream,
      maximumBytes: _maximumManifestBytes,
      tooLargeCode: 'manifest_too_large',
    );
    final decoded = jsonDecode(utf8.decode(body));
    if (decoded is! Map) {
      throw const AppUpdateException(
        code: 'invalid_manifest',
        message: 'Update ma’lumoti noto‘g‘ri',
      );
    }
    final manifest = AppUpdateManifest.fromJson(
      decoded.cast<String, dynamic>(),
      baseUri: _baseUri,
    );
    return AppUpdateCheckResult(current: current, manifest: manifest);
  }

  Future<AppInstallLaunchResult> downloadAndInstall(
    AppUpdateCheckResult update, {
    AppUpdateProgress? onProgress,
    AppUpdateCancellation? cancellation,
  }) async {
    final manifest = update.manifest;
    if (manifest == null || !update.updateAvailable) {
      throw const AppUpdateException(
        code: 'no_update',
        message: 'Yangi versiya mavjud emas',
      );
    }
    if (manifest.sizeBytes > _maximumApkBytes) {
      throw const AppUpdateException(
        code: 'apk_too_large',
        message: 'APK hajmi ruxsat etilgan chegaradan katta',
      );
    }

    final root = await _temporaryDirectoryProvider();
    final updateDirectory = Directory('${root.path}/app_updates');
    await updateDirectory.create(recursive: true);
    final finalFile =
        File('${updateDirectory.path}/accord-${manifest.versionCode}.apk');
    if (!await _matchesManifest(finalFile, manifest)) {
      await _download(
        manifest,
        finalFile,
        onProgress: onProgress,
        cancellation: cancellation,
      );
    } else {
      onProgress?.call(manifest.sizeBytes, manifest.sizeBytes);
    }
    await _removeOtherApks(updateDirectory, except: finalFile.path);
    return _platform.installApk(
      path: finalFile.path,
      expectedPackageName: update.current.packageName,
      expectedVersionCode: manifest.versionCode,
    );
  }

  Future<void> _download(
    AppUpdateManifest manifest,
    File finalFile, {
    AppUpdateProgress? onProgress,
    AppUpdateCancellation? cancellation,
  }) async {
    final partFile = File('${finalFile.path}.part');
    await _deleteIfExists(partFile);
    final request = http.Request('GET', manifest.apkUri);
    final response =
        await _client.send(request).timeout(const Duration(seconds: 30));
    if (response.statusCode != HttpStatus.ok) {
      throw AppUpdateException(
        code: 'apk_download_failed',
        message: 'APK yuklanmadi (${response.statusCode})',
      );
    }
    final responseLength = response.contentLength;
    if (responseLength != null && responseLength != manifest.sizeBytes) {
      throw const AppUpdateException(
        code: 'apk_size_mismatch',
        message: 'APK hajmi server ma’lumotiga mos emas',
      );
    }

    var received = 0;
    final sink = partFile.openWrite();
    try {
      await for (final chunk in response.stream) {
        if (cancellation?.isCancelled == true) {
          throw const AppUpdateException(
            code: 'cancelled',
            message: 'Yangilanish bekor qilindi',
          );
        }
        received += chunk.length;
        if (received > manifest.sizeBytes || received > _maximumApkBytes) {
          throw const AppUpdateException(
            code: 'apk_size_mismatch',
            message: 'APK hajmi server ma’lumotiga mos emas',
          );
        }
        sink.add(chunk);
        onProgress?.call(received, manifest.sizeBytes);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (received != manifest.sizeBytes) {
      await _deleteIfExists(partFile);
      throw const AppUpdateException(
        code: 'apk_size_mismatch',
        message: 'APK to‘liq yuklanmadi',
      );
    }
    if (!await _matchesManifest(partFile, manifest)) {
      await _deleteIfExists(partFile);
      throw const AppUpdateException(
        code: 'apk_checksum_mismatch',
        message: 'APK xavfsizlik tekshiruvidan o‘tmadi',
      );
    }
    await _deleteIfExists(finalFile);
    await partFile.rename(finalFile.path);
  }

  Future<bool> _matchesManifest(
    File file,
    AppUpdateManifest manifest,
  ) async {
    if (!await file.exists()) {
      return false;
    }
    if (await file.length() != manifest.sizeBytes) {
      return false;
    }
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase() == manifest.sha256;
  }

  Future<void> _removeOtherApks(
    Directory directory, {
    required String except,
  }) async {
    await for (final entity in directory.list()) {
      if (entity is File &&
          entity.path != except &&
          (entity.path.endsWith('.apk') || entity.path.endsWith('.part'))) {
        await _deleteIfExists(entity);
      }
    }
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Stale update files are best-effort cleanup only.
    }
  }

  Future<List<int>> _readLimited(
    Stream<List<int>> stream, {
    required int maximumBytes,
    required String tooLargeCode,
  }) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (builder.length + chunk.length > maximumBytes) {
        throw AppUpdateException(
          code: tooLargeCode,
          message: 'Server javobi juda katta',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}
