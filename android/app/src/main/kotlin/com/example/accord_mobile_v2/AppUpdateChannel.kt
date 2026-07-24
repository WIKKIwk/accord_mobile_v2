package com.example.accord_mobile_v2

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class AppUpdateChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "accord/app_update")

    init {
        channel.setMethodCallHandler(::handleMethodCall)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCurrentAppInfo" -> currentAppInfo(result)
            "installApk" -> installApk(call, result)
            else -> result.notImplemented()
        }
    }

    private fun currentAppInfo(result: MethodChannel.Result) {
        try {
            val packageInfo = installedPackageInfo()
            result.success(
                mapOf(
                    "packageName" to activity.packageName,
                    "versionCode" to versionCode(packageInfo),
                    "versionName" to (packageInfo.versionName ?: ""),
                    "signerSha256" to signerDigests(packageInfo).firstOrNull().orEmpty(),
                ),
            )
        } catch (error: Exception) {
            result.error("app_info_failed", error.message, null)
        }
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")?.trim().orEmpty()
        val expectedPackageName =
            call.argument<String>("expectedPackageName")?.trim().orEmpty()
        val expectedVersionCode =
            (call.argument<Number>("expectedVersionCode")?.toLong() ?: 0L)
        if (path.isEmpty() || expectedPackageName.isEmpty() || expectedVersionCode <= 0L) {
            result.error("invalid_install_request", "Missing APK install arguments", null)
            return
        }

        try {
            val apk = File(path).canonicalFile
            val updateRoot = File(activity.cacheDir, "app_updates").canonicalFile
            val allowedPrefix = updateRoot.path + File.separator
            if (!apk.isFile || !apk.path.startsWith(allowedPrefix)) {
                result.error("invalid_apk_path", "APK is outside the app update cache", null)
                return
            }

            val archive = archivePackageInfo(apk)
            if (archive.packageName != expectedPackageName ||
                archive.packageName != activity.packageName
            ) {
                result.error("package_mismatch", "APK package does not match this app", null)
                return
            }
            val archiveVersionCode = versionCode(archive)
            if (archiveVersionCode != expectedVersionCode) {
                result.error("version_mismatch", "APK version does not match metadata", null)
                return
            }
            val installed = installedPackageInfo()
            if (archiveVersionCode <= versionCode(installed)) {
                result.error("version_not_newer", "APK version is not newer", null)
                return
            }
            val currentSigners = signerDigests(installed).toSet()
            val archiveSigners = signerDigests(archive).toSet()
            if (currentSigners.isEmpty() ||
                archiveSigners.isEmpty() ||
                currentSigners.intersect(archiveSigners).isEmpty()
            ) {
                result.error("signer_mismatch", "APK signing certificate does not match", null)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !activity.packageManager.canRequestPackageInstalls()
            ) {
                val settingsIntent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${activity.packageName}"),
                )
                activity.startActivity(settingsIntent)
                result.success(mapOf("status" to "permission_required"))
                return
            }

            val uri = FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.app-update-files",
                apk,
            )
            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (installIntent.resolveActivity(activity.packageManager) == null) {
                result.error("installer_unavailable", "Android package installer not found", null)
                return
            }
            activity.startActivity(installIntent)
            result.success(mapOf("status" to "installer_launched"))
        } catch (error: Exception) {
            result.error("install_failed", error.message, null)
        }
    }

    private fun installedPackageInfo(): PackageInfo {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.packageManager.getPackageInfo(
                activity.packageName,
                PackageManager.PackageInfoFlags.of(
                    PackageManager.GET_SIGNING_CERTIFICATES.toLong(),
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            activity.packageManager.getPackageInfo(
                activity.packageName,
                legacySigningFlags(),
            )
        }
    }

    private fun archivePackageInfo(apk: File): PackageInfo {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.packageManager.getPackageArchiveInfo(
                apk.path,
                PackageManager.PackageInfoFlags.of(
                    PackageManager.GET_SIGNING_CERTIFICATES.toLong(),
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            activity.packageManager.getPackageArchiveInfo(
                apk.path,
                legacySigningFlags(),
            )
        }
        return info ?: throw IllegalArgumentException("APK package metadata is unreadable")
    }

    @Suppress("DEPRECATION")
    private fun legacySigningFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
    }

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
    }

    @Suppress("DEPRECATION")
    private fun signerDigests(info: PackageInfo): List<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo ?: return emptyList()
            if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners.toList()
            } else {
                signingInfo.signingCertificateHistory.toList()
            }
        } else {
            info.signatures?.toList().orEmpty()
        }
        return signatures.map { signature ->
            MessageDigest.getInstance("SHA-256")
                .digest(signature.toByteArray())
                .joinToString(separator = "") { byte ->
                    "%02x".format(byte.toInt() and 0xff)
                }
        }
    }
}
