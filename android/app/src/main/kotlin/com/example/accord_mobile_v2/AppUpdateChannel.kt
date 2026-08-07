package com.example.accord_mobile_v2

import android.app.Activity
import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
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
    private companion object {
        const val UPDATE_PREFERENCES = "accord_app_update_download"
        const val KEY_DOWNLOAD_ID = "download_id"
        const val KEY_URL = "url"
        const val KEY_VERSION_CODE = "version_code"
        const val KEY_SHA256 = "sha256"
        const val KEY_SIZE_BYTES = "size_bytes"
        const val MAXIMUM_APK_BYTES = 512L * 1024L * 1024L
        const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    }

    private val channel = MethodChannel(messenger, "accord/app_update")
    private val downloadManager =
        activity.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    private val downloadPreferences =
        activity.getSharedPreferences(UPDATE_PREFERENCES, Context.MODE_PRIVATE)

    init {
        channel.setMethodCallHandler(::handleMethodCall)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCurrentAppInfo" -> currentAppInfo(result)
            "startOrAttachUpdateDownload" -> startOrAttachUpdateDownload(call, result)
            "queryUpdateDownload" -> queryUpdateDownload(call, result)
            "cancelUpdateDownload" -> cancelUpdateDownload(call, result)
            "installApk" -> installApk(call, result)
            else -> result.notImplemented()
        }
    }

    private fun currentAppInfo(result: MethodChannel.Result) {
        try {
            val packageInfo = installedPackageInfo()
            val installedVersionCode = versionCode(packageInfo)
            cleanupInstalledDownload(installedVersionCode)
            result.success(
                mapOf(
                    "packageName" to activity.packageName,
                    "versionCode" to installedVersionCode,
                    "versionName" to (packageInfo.versionName ?: ""),
                    "signerSha256" to signerDigests(packageInfo).firstOrNull().orEmpty(),
                ),
            )
        } catch (error: Exception) {
            result.error("app_info_failed", error.message, null)
        }
    }

    private fun startOrAttachUpdateDownload(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            val spec = downloadSpec(call)
            val existing = storedDownload()
            if (existing != null && existing.spec.matches(spec)) {
                val snapshot = downloadSnapshot(existing)
                if (snapshot["status"] != "failed" && snapshot["status"] != "missing") {
                    result.success(snapshot)
                    return
                }
                removeStoredDownload(existing)
            } else if (existing != null) {
                removeStoredDownload(existing)
            }

            val destination = updateDestination(spec)
            val updateDirectory = destination.parentFile
                ?: throw IllegalStateException("Update directory is unavailable")
            if (!updateDirectory.exists() && !updateDirectory.mkdirs()) {
                throw IllegalStateException("Update directory could not be created")
            }
            cleanupUpdateFiles(updateDirectory, except = destination)
            if (destination.exists() && !destination.delete()) {
                throw IllegalStateException("Stale update file could not be removed")
            }

            val relativePath = "app_updates/${destination.name}"
            val request = DownloadManager.Request(spec.uri).apply {
                setAllowedOverMetered(true)
                setAllowedOverRoaming(true)
                setDestinationInExternalFilesDir(
                    activity,
                    Environment.DIRECTORY_DOWNLOADS,
                    relativePath,
                )
                setMimeType(APK_MIME_TYPE)
                setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE,
                )
                setTitle("Accord Mobile ${spec.versionName}")
                setDescription("Ilova yangilanishi yuklanmoqda")
                addRequestHeader("Accept", APK_MIME_TYPE)
            }
            val download = StoredDownload(
                id = downloadManager.enqueue(request),
                spec = spec,
            )
            if (!saveStoredDownload(download)) {
                downloadManager.remove(download.id)
                destination.delete()
                throw IllegalStateException("Update state could not be saved")
            }
            val snapshot = downloadSnapshot(download)
            result.success(
                if (snapshot["status"] == "missing") {
                    pendingSnapshot(spec)
                } else {
                    snapshot
                },
            )
        } catch (error: IllegalArgumentException) {
            result.error("invalid_download_request", error.message, null)
        } catch (error: Exception) {
            result.error("download_start_failed", error.message, null)
        }
    }

    private fun queryUpdateDownload(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            val spec = downloadSpec(call)
            val download = storedDownload()
            if (download == null || !download.spec.matches(spec)) {
                result.success(missingSnapshot(spec))
                return
            }
            result.success(downloadSnapshot(download))
        } catch (error: IllegalArgumentException) {
            result.error("invalid_download_request", error.message, null)
        } catch (error: Exception) {
            result.error("download_query_failed", error.message, null)
        }
    }

    private fun cancelUpdateDownload(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            val spec = downloadSpec(call)
            val download = storedDownload()
            if (download != null && download.spec.matches(spec)) {
                removeStoredDownload(download)
            }
            result.success(null)
        } catch (error: IllegalArgumentException) {
            result.error("invalid_download_request", error.message, null)
        } catch (error: Exception) {
            result.error("download_cancel_failed", error.message, null)
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
            if (!apk.isFile || !isAllowedUpdateFile(apk)) {
                result.error("invalid_apk_path", "APK is outside app update storage", null)
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

    private fun downloadSpec(call: MethodCall): DownloadSpec {
        val rawUrl = call.argument<String>("url")?.trim().orEmpty()
        val versionCode = call.argument<Number>("versionCode")?.toLong() ?: 0L
        val versionName = call.argument<String>("versionName")?.trim().orEmpty()
        val sha256 = call.argument<String>("sha256")?.trim()?.lowercase().orEmpty()
        val sizeBytes = call.argument<Number>("sizeBytes")?.toLong() ?: 0L
        val uri = Uri.parse(rawUrl)
        if (rawUrl.isEmpty() ||
            (uri.scheme != "https" && uri.scheme != "http") ||
            uri.host.isNullOrBlank() ||
            versionCode <= 0L ||
            versionName.isEmpty() ||
            !sha256.matches(Regex("^[a-f0-9]{64}$")) ||
            sizeBytes <= 0L ||
            sizeBytes > MAXIMUM_APK_BYTES
        ) {
            throw IllegalArgumentException("Invalid update download arguments")
        }
        return DownloadSpec(
            uri = uri,
            versionCode = versionCode,
            versionName = versionName,
            sha256 = sha256,
            sizeBytes = sizeBytes,
        )
    }

    private fun updateDirectory(): File {
        val downloadsRoot = activity.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: throw IllegalStateException("External app storage is unavailable")
        val canonicalRoot = downloadsRoot.canonicalFile
        val directory = File(canonicalRoot, "app_updates").canonicalFile
        if (!isChildOf(directory, canonicalRoot)) {
            throw SecurityException("Update directory escaped app storage")
        }
        return directory
    }

    private fun updateDestination(spec: DownloadSpec): File {
        val fileName = "accord-${spec.versionCode}-${spec.sha256.take(16)}.apk"
        val directory = updateDirectory()
        val destination = File(directory, fileName).canonicalFile
        if (!isChildOf(destination, directory)) {
            throw SecurityException("Update file escaped app storage")
        }
        return destination
    }

    private fun isAllowedUpdateFile(apk: File): Boolean {
        val roots = buildList {
            add(File(activity.cacheDir, "app_updates").canonicalFile)
            activity.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)?.let { downloads ->
                add(File(downloads, "app_updates").canonicalFile)
            }
        }
        return roots.any { root ->
            isChildOf(apk, root)
        }
    }

    private fun isChildOf(file: File, directory: File): Boolean {
        return file.path.startsWith(directory.path + File.separator)
    }

    private fun storedDownload(): StoredDownload? {
        if (!downloadPreferences.contains(KEY_DOWNLOAD_ID)) {
            return null
        }
        val id = downloadPreferences.getLong(KEY_DOWNLOAD_ID, -1L)
        val rawUrl = downloadPreferences.getString(KEY_URL, null).orEmpty()
        val versionCode = downloadPreferences.getLong(KEY_VERSION_CODE, 0L)
        val sha256 = downloadPreferences.getString(KEY_SHA256, null).orEmpty()
        val sizeBytes = downloadPreferences.getLong(KEY_SIZE_BYTES, 0L)
        val uri = Uri.parse(rawUrl)
        if (id <= 0L ||
            (uri.scheme != "https" && uri.scheme != "http") ||
            uri.host.isNullOrBlank() ||
            versionCode <= 0L ||
            !sha256.matches(Regex("^[a-f0-9]{64}$")) ||
            sizeBytes <= 0L ||
            sizeBytes > MAXIMUM_APK_BYTES
        ) {
            downloadPreferences.edit().clear().commit()
            return null
        }
        return StoredDownload(
            id = id,
            spec = DownloadSpec(
                uri = uri,
                versionCode = versionCode,
                versionName = versionCode.toString(),
                sha256 = sha256,
                sizeBytes = sizeBytes,
            ),
        )
    }

    private fun saveStoredDownload(download: StoredDownload): Boolean {
        return downloadPreferences.edit()
            .putLong(KEY_DOWNLOAD_ID, download.id)
            .putString(KEY_URL, download.spec.uri.toString())
            .putLong(KEY_VERSION_CODE, download.spec.versionCode)
            .putString(KEY_SHA256, download.spec.sha256)
            .putLong(KEY_SIZE_BYTES, download.spec.sizeBytes)
            .commit()
    }

    private fun downloadSnapshot(download: StoredDownload): Map<String, Any> {
        val destination = updateDestination(download.spec)
        val cursor = downloadManager.query(
            DownloadManager.Query().setFilterById(download.id),
        )
        cursor.use {
            if (!it.moveToFirst()) {
                return if (destination.isFile && destination.length() == download.spec.sizeBytes) {
                    successfulSnapshot(download.spec, destination)
                } else {
                    missingSnapshot(download.spec)
                }
            }
            val status = it.getInt(
                it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS),
            )
            val receivedBytes = it.getLong(
                it.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR),
            ).coerceAtLeast(0L)
            val reason = it.getInt(
                it.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON),
            )
            return when (status) {
                DownloadManager.STATUS_PENDING -> stateSnapshot(
                    status = "pending",
                    spec = download.spec,
                    receivedBytes = receivedBytes,
                )
                DownloadManager.STATUS_RUNNING -> stateSnapshot(
                    status = "running",
                    spec = download.spec,
                    receivedBytes = receivedBytes,
                )
                DownloadManager.STATUS_PAUSED -> stateSnapshot(
                    status = "paused",
                    spec = download.spec,
                    receivedBytes = receivedBytes,
                    reason = reason,
                )
                DownloadManager.STATUS_SUCCESSFUL -> {
                    if (destination.isFile && destination.length() == download.spec.sizeBytes) {
                        successfulSnapshot(download.spec, destination)
                    } else {
                        failedSnapshot(
                            spec = download.spec,
                            receivedBytes = receivedBytes,
                            reason = DownloadManager.ERROR_FILE_ERROR,
                        )
                    }
                }
                DownloadManager.STATUS_FAILED -> failedSnapshot(
                    spec = download.spec,
                    receivedBytes = receivedBytes,
                    reason = reason,
                )
                else -> missingSnapshot(download.spec)
            }
        }
    }

    private fun pendingSnapshot(spec: DownloadSpec): Map<String, Any> =
        stateSnapshot(status = "pending", spec = spec, receivedBytes = 0L)

    private fun missingSnapshot(spec: DownloadSpec): Map<String, Any> =
        stateSnapshot(status = "missing", spec = spec, receivedBytes = 0L)

    private fun successfulSnapshot(
        spec: DownloadSpec,
        destination: File,
    ): Map<String, Any> = stateSnapshot(
        status = "successful",
        spec = spec,
        receivedBytes = spec.sizeBytes,
        path = destination.path,
    )

    private fun failedSnapshot(
        spec: DownloadSpec,
        receivedBytes: Long,
        reason: Int,
    ): Map<String, Any> = stateSnapshot(
        status = "failed",
        spec = spec,
        receivedBytes = receivedBytes,
        reason = reason,
        retryable = isRetryableFailure(reason),
    )

    private fun stateSnapshot(
        status: String,
        spec: DownloadSpec,
        receivedBytes: Long,
        path: String = "",
        reason: Int = 0,
        retryable: Boolean = false,
    ): Map<String, Any> = mapOf(
        "status" to status,
        "receivedBytes" to receivedBytes.coerceIn(0L, spec.sizeBytes),
        "totalBytes" to spec.sizeBytes,
        "path" to path,
        "reason" to reason,
        "retryable" to retryable,
    )

    private fun isRetryableFailure(reason: Int): Boolean {
        return reason == DownloadManager.ERROR_UNKNOWN ||
            reason == DownloadManager.ERROR_HTTP_DATA_ERROR ||
            reason == DownloadManager.ERROR_CANNOT_RESUME ||
            reason == 408 ||
            reason == 429 ||
            reason in 500..599
    }

    private fun removeStoredDownload(download: StoredDownload) {
        downloadManager.remove(download.id)
        updateDestination(download.spec).delete()
        downloadPreferences.edit().clear().commit()
    }

    private fun cleanupUpdateFiles(directory: File, except: File) {
        directory.listFiles()?.forEach { file ->
            if (file.isFile && file.canonicalFile != except) {
                file.delete()
            }
        }
    }

    private fun cleanupInstalledDownload(installedVersionCode: Long) {
        val download = storedDownload() ?: return
        if (download.spec.versionCode <= installedVersionCode) {
            try {
                removeStoredDownload(download)
            } catch (_: Exception) {
                // Cleanup must not prevent reading the installed app version.
            }
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

    private data class DownloadSpec(
        val uri: Uri,
        val versionCode: Long,
        val versionName: String,
        val sha256: String,
        val sizeBytes: Long,
    ) {
        fun matches(other: DownloadSpec): Boolean {
            return uri == other.uri &&
                versionCode == other.versionCode &&
                sha256 == other.sha256 &&
                sizeBytes == other.sizeBytes
        }
    }

    private data class StoredDownload(
        val id: Long,
        val spec: DownloadSpec,
    )
}
