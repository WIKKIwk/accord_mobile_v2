package com.example.accord_mobile_v2

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal class SecureAccountStorageChannel(
    context: Context,
    messenger: BinaryMessenger,
) {
    private companion object {
        const val CHANNEL_NAME = "accord/secure_account_storage"
        const val PREFERENCES_NAME = "accord_secure_accounts_v1"
        const val KEY_ALIAS = "accord_saved_accounts_v1"
        const val ANDROID_KEY_STORE = "AndroidKeyStore"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
    }

    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(::handleMethodCall)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val key = arguments["key"]?.toString()?.trim().orEmpty()
        if (key.isEmpty()) {
            result.error("invalid_key", "Secure storage key is required", null)
            return
        }
        when (call.method) {
            "read" -> read(key, result)
            "write" -> {
                val value = arguments["value"]?.toString()
                if (value == null) {
                    result.error("invalid_value", "Secure storage value is required", null)
                    return
                }
                write(key, value, result)
            }
            "delete" -> {
                preferences.edit().remove(key).apply()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun read(key: String, result: MethodChannel.Result) {
        val encoded = preferences.getString(key, null)
        if (encoded.isNullOrEmpty()) {
            result.success(null)
            return
        }
        try {
            result.success(decrypt(encoded))
        } catch (_: Exception) {
            // A restored preference cannot be decrypted by a device-local key.
            preferences.edit().remove(key).apply()
            result.success(null)
        }
    }

    private fun write(key: String, value: String, result: MethodChannel.Result) {
        try {
            val encoded = encrypt(value)
            if (!preferences.edit().putString(key, encoded).commit()) {
                result.error("write_failed", "Secure storage write failed", null)
                return
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("write_failed", "Secure storage write failed", error.javaClass.simpleName)
        }
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val cipherText = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val payload = ByteBuffer.allocate(Int.SIZE_BYTES + cipher.iv.size + cipherText.size)
            .putInt(cipher.iv.size)
            .put(cipher.iv)
            .put(cipherText)
            .array()
        return Base64.encodeToString(payload, Base64.NO_WRAP)
    }

    private fun decrypt(encoded: String): String {
        val payload = Base64.decode(encoded, Base64.NO_WRAP)
        val buffer = ByteBuffer.wrap(payload)
        val ivSize = buffer.int
        require(ivSize in 12..32 && buffer.remaining() > ivSize) {
            "Invalid secure storage payload"
        }
        val iv = ByteArray(ivSize)
        buffer.get(iv)
        val cipherText = ByteArray(buffer.remaining())
        buffer.get(cipherText)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(128, iv))
        return cipher.doFinal(cipherText).toString(Charsets.UTF_8)
    }

    @Synchronized
    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }
        val existing = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) {
            return existing
        }
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEY_STORE,
        )
        keyGenerator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return keyGenerator.generateKey()
    }
}
