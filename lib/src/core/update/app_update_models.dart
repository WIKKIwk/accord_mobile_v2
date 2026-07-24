class AppInstallationInfo {
  const AppInstallationInfo({
    required this.packageName,
    required this.versionCode,
    required this.versionName,
    required this.signerSha256,
  });

  final String packageName;
  final int versionCode;
  final String versionName;
  final String signerSha256;

  factory AppInstallationInfo.fromMap(Map<Object?, Object?> map) {
    return AppInstallationInfo(
      packageName: map['packageName']?.toString().trim() ?? '',
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      versionName: map['versionName']?.toString().trim() ?? '',
      signerSha256: map['signerSha256']?.toString().trim().toLowerCase() ?? '',
    );
  }
}

class AppUpdateManifest {
  const AppUpdateManifest({
    required this.versionCode,
    required this.versionName,
    required this.minimumSupportedVersionCode,
    required this.mandatory,
    required this.apkUri,
    required this.sha256,
    required this.sizeBytes,
    required this.releaseNotes,
    required this.publishedAt,
  });

  final int versionCode;
  final String versionName;
  final int minimumSupportedVersionCode;
  final bool mandatory;
  final Uri apkUri;
  final String sha256;
  final int sizeBytes;
  final String releaseNotes;
  final String publishedAt;

  factory AppUpdateManifest.fromJson(
    Map<String, dynamic> json, {
    required Uri baseUri,
  }) {
    final versionCode = (json['version_code'] as num?)?.toInt() ?? 0;
    final versionName = json['version_name']?.toString().trim() ?? '';
    final minimumVersion =
        (json['minimum_supported_version_code'] as num?)?.toInt() ?? 0;
    final rawApkUrl = json['apk_url']?.toString().trim() ?? '';
    final sha256 = json['sha256']?.toString().trim().toLowerCase() ?? '';
    final sizeBytes = (json['size_bytes'] as num?)?.toInt() ?? 0;
    final apkUri = baseUri.resolve(rawApkUrl);
    final validSha256 = RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256);
    if (versionCode <= 0 ||
        versionName.isEmpty ||
        minimumVersion < 0 ||
        minimumVersion > versionCode ||
        rawApkUrl.isEmpty ||
        !apkUri.hasScheme ||
        (apkUri.scheme != 'https' && apkUri.scheme != 'http') ||
        !validSha256 ||
        sizeBytes <= 0) {
      throw const AppUpdateException(
        code: 'invalid_manifest',
        message: 'Update ma’lumoti noto‘g‘ri',
      );
    }
    return AppUpdateManifest(
      versionCode: versionCode,
      versionName: versionName,
      minimumSupportedVersionCode: minimumVersion,
      mandatory: json['mandatory'] == true,
      apkUri: apkUri,
      sha256: sha256,
      sizeBytes: sizeBytes,
      releaseNotes: json['release_notes']?.toString().trim() ?? '',
      publishedAt: json['published_at']?.toString().trim() ?? '',
    );
  }

  bool isNewerThan(AppInstallationInfo current) =>
      versionCode > current.versionCode;

  bool isMandatoryFor(AppInstallationInfo current) =>
      mandatory || current.versionCode < minimumSupportedVersionCode;
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.current,
    required this.manifest,
  });

  final AppInstallationInfo current;
  final AppUpdateManifest? manifest;

  bool get updateAvailable =>
      manifest != null && manifest!.isNewerThan(current);
  bool get mandatory => updateAvailable && manifest!.isMandatoryFor(current);
}

class AppUpdateException implements Exception {
  const AppUpdateException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => message;
}
