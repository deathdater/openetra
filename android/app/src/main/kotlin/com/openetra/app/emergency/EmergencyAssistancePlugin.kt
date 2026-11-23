package com.openetra.app.emergency

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Android Keystore AES-256-GCM trusted-contact store & ACTION_DIAL handoff.
 * Phone numbers and contact names are NEVER logged or emitted to analytics.
 */
class EmergencyAssistancePlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val KEY_ALIAS = "openetra_emergency_aes_gcm_v1"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_IV_LEN = 12
        private const val GCM_TAG_BITS = 128

        private fun getOrCreateKey(): SecretKey {
            val ks = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
            val existing = ks.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
            if (existing != null) return existing.secretKey

            val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
            val spec = KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
                .build()
            gen.init(spec)
            return gen.generateKey()
        }

        fun secureFile(context: Context): File {
            val dir = File(context.filesDir, "secure")
            if (!dir.exists()) dir.mkdirs()
            return File(dir, "emergency_contacts.enc")
        }

        fun encryptAndSave(context: Context, plaintextJson: String) {
            val key = getOrCreateKey()
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, key)
            val iv = cipher.iv
            val ciphertext = cipher.doFinal(plaintextJson.toByteArray(StandardCharsets.UTF_8))

            val payload = ByteArray(1 + iv.size + ciphertext.size)
            payload[0] = iv.size.toByte()
            System.arraycopy(iv, 0, payload, 1, iv.size)
            System.arraycopy(ciphertext, 0, payload, 1 + iv.size, ciphertext.size)

            val out = secureFile(context)
            val tmp = File(out.parentFile, "${out.name}.tmp")
            tmp.writeBytes(payload)
            if (out.exists()) out.delete()
            check(tmp.renameTo(out)) { "Failed committing encrypted emergency contact store" }
        }

        fun loadAndDecrypt(context: Context): String {
            val file = secureFile(context)
            if (!file.exists() || file.length() == 0L) return ""
            val bytes = file.readBytes()
            require(bytes.size > 1 + GCM_IV_LEN) { "Corrupt encrypted contact store" }
            val ivLen = bytes[0].toInt() and 0xFF
            require(bytes.size > 1 + ivLen) { "Invalid IV length in encrypted store" }
            val iv = bytes.copyOfRange(1, 1 + ivLen)
            val ciphertext = bytes.copyOfRange(1 + ivLen, bytes.size)

            val key = getOrCreateKey()
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_BITS, iv))
            val plain = cipher.doFinal(ciphertext)
            return String(plain, StandardCharsets.UTF_8)
        }

        fun sanitizeDialNumber(raw: String): String {
            val trimmed = raw.trim()
            val sb = StringBuilder()
            for (ch in trimmed) {
                if (ch.isDigit() || (ch == '+' && sb.isEmpty()) || ch == '*' || ch == '#') {
                    sb.append(ch)
                }
            }
            return sb.toString()
        }
    }

    private val channel = MethodChannel(messenger, "com.openetra.app/emergency")

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveContactsPayload" -> {
                val payload = call.argument<String>("payload")
                if (payload == null) {
                    result.error("INVALID_ARGS", "payload required", null)
                    return
                }
                try {
                    encryptAndSave(context, payload)
                    result.success(mapOf("saved" to true))
                } catch (e: Throwable) {
                    result.error("ENCRYPT_ERROR", e.message ?: "Encryption failed", null)
                }
            }

            "loadContactsPayload" -> {
                try {
                    result.success(mapOf("payload" to loadAndDecrypt(context)))
                } catch (e: Throwable) {
                    result.error("DECRYPT_ERROR", "Unable to read protected contact store", null)
                }
            }

            "deleteContactsStorage" -> {
                val file = secureFile(context)
                if (file.exists()) file.delete()
                result.success(mapOf("deleted" to true))
            }

            "checkCallCapabilities" -> {
                val airplaneOn = try {
                    Settings.Global.getInt(
                        context.contentResolver,
                        Settings.Global.AIRPLANE_MODE_ON,
                        0
                    ) != 0
                } catch (_: Throwable) {
                    false
                }
                val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:0000"))
                val dialerAvailable = dialIntent.resolveActivity(context.packageManager) != null
                val telephonyAvailable =
                    context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
                result.success(
                    mapOf(
                        "airplaneMode" to airplaneOn,
                        "dialerAvailable" to dialerAvailable,
                        "telephonyAvailable" to telephonyAvailable
                    )
                )
            }

            "openDialer" -> {
                val rawPhone = call.argument<String>("phoneNumber") ?: ""
                val sanitized = sanitizeDialNumber(rawPhone)
                if (sanitized.length < 3) {
                    result.error("INVALID_NUMBER", "Trusted contact phone number is invalid", null)
                    return
                }
                try {
                    val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$sanitized")).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (intent.resolveActivity(context.packageManager) == null) {
                        result.error("DIALER_UNAVAILABLE", "No dialer app available on device", null)
                        return
                    }
                    context.startActivity(intent)
                    result.success(mapOf("dialerOpened" to true))
                } catch (e: Throwable) {
                    result.error("DIALER_ERROR", "Could not open phone dialer", null)
                }
            }

            else -> result.notImplemented()
        }
    }

    fun release() {
        channel.setMethodCallHandler(null)
    }
}
