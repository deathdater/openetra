package com.openetra.app.local_intelligence

import android.app.ActivityManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Native Android bridge (`com.openetra.app/local_intelligence`) for Openetra
 * Local Intelligence (Beta):
 * - Real device hardware probing (Android API, total RAM, free internal storage, ABIs)
 * - Resumable HTTPS model downloader with Wi-Fi-only guard, storage check,
 *   Hugging Face redirect handling, real-time progress EventChannel, and cancellation
 * - SHA-256 package integrity verification for `.litertlm` files
 * - App-private model file management & deletion
 * - On-device LiteRT-LM inference (`com.google.ai.edge.litertlm.Engine`) with safe fallback
 */
class LocalIntelligencePlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val CHANNEL_NAME = "com.openetra.app/local_intelligence"
        const val PROGRESS_CHANNEL_NAME = "com.openetra.app/local_intelligence_download_progress"
        private const val MODELS_DIR = "local_intelligence_models"
        private const val MAX_REDIRECTS = 8
        private const val CONNECT_TIMEOUT_MS = 20_000
        private const val READ_TIMEOUT_MS = 30_000
        private const val PROGRESS_EMIT_INTERVAL_MS = 150L
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val progressChannel = EventChannel(messenger, PROGRESS_CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @Volatile
    private var progressSink: EventChannel.EventSink? = null

    @Volatile
    private var activeDownloadJob: Job? = null

    @Volatile
    private var activeDownloadModelId: String? = null

    private val downloadCancelled = AtomicBoolean(false)

    private val engineLock = Any()
    private var engine: Engine? = null
    private var loadedModelId: String? = null
    private var loadedModelPath: String? = null

    init {
        channel.setMethodCallHandler(this)
        progressChannel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        progressSink = events
    }

    override fun onCancel(arguments: Any?) {
        progressSink = null
    }

    private fun postSuccess(result: MethodChannel.Result, payload: Any?) {
        mainHandler.post { result.success(payload) }
    }

    private fun emitProgress(
        modelId: String,
        downloadedBytes: Long,
        totalBytes: Long,
        status: String
    ) {
        val progress = if (totalBytes > 0L) {
            (downloadedBytes.toDouble() / totalBytes.toDouble()).coerceIn(0.0, 1.0)
        } else {
            0.0
        }
        val event = mapOf(
            "modelId" to modelId,
            "downloadedBytes" to downloadedBytes,
            "totalBytes" to totalBytes,
            "progress" to progress,
            "status" to status
        )
        mainHandler.post {
            progressSink?.success(event)
        }
    }

    private fun modelsDir(): File {
        val dir = File(context.filesDir, MODELS_DIR)
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    private fun isLiteRtLmAvailable(): Boolean {
        return try {
            Class.forName("com.google.ai.edge.litertlm.Engine")
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun probeDevice(): Map<String, Any> {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        am?.getMemoryInfo(memInfo)
        val totalRamMb = (memInfo.totalMem / (1024L * 1024L)).toInt()

        val stat = StatFs(context.filesDir.absolutePath)
        val availStorageMb = (stat.availableBytes / (1024L * 1024L)).toInt()

        return mapOf(
            "androidApiLevel" to Build.VERSION.SDK_INT,
            "totalRamMb" to totalRamMb,
            "availableStorageMb" to availStorageMb,
            "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
            "liteRtLmRuntimeAvailable" to isLiteRtLmAvailable()
        )
    }

    private fun checkNetwork(wifiOnly: Boolean): String? {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return "Unable to inspect network state."
        val network = cm.activeNetwork
            ?: return "No active internet connection. Connect to Wi-Fi and try again."
        val caps = cm.getNetworkCapabilities(network)
            ?: return "No active internet connection. Connect to Wi-Fi and try again."
        if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            return "No internet access available. Connect to Wi-Fi and try again."
        }
        if (wifiOnly && !caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
            return "Wi-Fi only download is enabled. Connect to Wi-Fi or turn off Wi-Fi-only download in Local Intelligence settings."
        }
        return null
    }

    private fun openFollowingRedirects(
        initialUrl: String,
        rangeStart: Long,
        authToken: String?
    ): HttpURLConnection {
        var currentUrl = initialUrl
        var redirects = 0
        while (redirects <= MAX_REDIRECTS) {
            val url = URL(currentUrl)
            val conn = (url.openConnection() as HttpURLConnection).apply {
                instanceFollowRedirects = false
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                requestMethod = "GET"
                setRequestProperty("User-Agent", "Openetra-Android/2.4")
                if (rangeStart > 0L) {
                    setRequestProperty("Range", "bytes=$rangeStart-")
                }
                // Only send Bearer token to huggingface.co hosts; never leak to signed CDN redirects.
                if (!authToken.isNullOrBlank() &&
                    (url.host.equals("huggingface.co", ignoreCase = true) ||
                        url.host.endsWith(".huggingface.co", ignoreCase = true))
                ) {
                    setRequestProperty("Authorization", "Bearer ${authToken.trim()}")
                }
            }

            val code = conn.responseCode
            if (code == HttpURLConnection.HTTP_MOVED_PERM ||
                code == HttpURLConnection.HTTP_MOVED_TEMP ||
                code == HttpURLConnection.HTTP_SEE_OTHER ||
                code == 307 ||
                code == 308
            ) {
                val location = conn.getHeaderField("Location")
                conn.disconnect()
                if (location.isNullOrBlank()) {
                    throw IllegalStateException("Server returned redirect ($code) without Location header.")
                }
                currentUrl = URL(url, location).toString()
                redirects++
                continue
            }
            return conn
        }
        throw IllegalStateException("Too many redirects while downloading model.")
    }

    private fun sha256File(file: File): String {
        val md = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { fis ->
            val buf = ByteArray(65536)
            while (true) {
                val read = fis.read(buf)
                if (read <= 0) break
                md.update(buf, 0, read)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    private fun unloadInternal() {
        synchronized(engineLock) {
            try {
                engine?.close()
            } catch (_: Throwable) {
            }
            engine = null
            loadedModelId = null
            loadedModelPath = null
        }
    }

    private fun sanitizeFileName(name: String): String {
        return name.replace(Regex("[^a-zA-Z0-9._-]"), "_")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "probeDevice" -> {
                result.success(probeDevice())
            }

            "downloadModel" -> {
                val modelId = call.argument<String>("modelId")?.trim().orEmpty()
                val downloadUrl = call.argument<String>("downloadUrl")?.trim().orEmpty()
                val fileName = call.argument<String>("fileName")?.trim().orEmpty()
                val expectedSizeMb = (call.argument<Number>("expectedSizeMb"))?.toLong() ?: 0L
                val wifiOnly = call.argument<Boolean>("wifiOnly") ?: true
                val authToken = call.argument<String>("authToken")

                if (modelId.isEmpty() || downloadUrl.isEmpty() || fileName.isEmpty()) {
                    result.success(
                        mapOf(
                            "success" to false,
                            "error" to "Missing model download parameters."
                        )
                    )
                    return
                }

                if (activeDownloadJob?.isActive == true) {
                    result.success(
                        mapOf(
                            "success" to false,
                            "error" to "Another model download is already in progress."
                        )
                    )
                    return
                }

                val netErr = checkNetwork(wifiOnly)
                if (netErr != null) {
                    result.success(mapOf("success" to false, "error" to netErr))
                    return
                }

                val dir = modelsDir()
                val safeName = "${sanitizeFileName(modelId)}__${sanitizeFileName(fileName)}"
                val finalFile = File(dir, safeName)
                val partFile = File(dir, "$safeName.part")

                val stat = StatFs(dir.absolutePath)
                val availBytes = stat.availableBytes
                val existingPartBytes = if (partFile.exists()) partFile.length() else 0L
                val minNeededBytes = if (expectedSizeMb > 0L) {
                    ((expectedSizeMb * 1024L * 1024L * 115L) / 100L) - existingPartBytes
                } else {
                    200L * 1024L * 1024L
                }
                if (minNeededBytes > 0L && availBytes < minNeededBytes) {
                    val availMb = availBytes / (1024L * 1024L)
                    val needMb = minNeededBytes / (1024L * 1024L)
                    result.success(
                        mapOf(
                            "success" to false,
                            "error" to "Not enough free storage. Needs about $needMb MB free ($availMb MB available)."
                        )
                    )
                    return
                }

                downloadCancelled.set(false)
                activeDownloadModelId = modelId

                activeDownloadJob = scope.launch {
                    var conn: HttpURLConnection? = null
                    try {
                        var resumeFrom = if (partFile.exists()) partFile.length() else 0L
                        emitProgress(
                            modelId = modelId,
                            downloadedBytes = resumeFrom,
                            totalBytes = expectedSizeMb * 1024L * 1024L,
                            status = "connecting"
                        )

                        conn = openFollowingRedirects(downloadUrl, resumeFrom, authToken)
                        var code = conn.responseCode

                        // If Range request is unsatisfiable (e.g. file changed on server), restart cleanly.
                        if (code == 416 && resumeFrom > 0L) {
                            conn.disconnect()
                            partFile.delete()
                            resumeFrom = 0L
                            conn = openFollowingRedirects(downloadUrl, 0L, authToken)
                            code = conn.responseCode
                        }

                        if (code == HttpURLConnection.HTTP_UNAUTHORIZED ||
                            code == HttpURLConnection.HTTP_FORBIDDEN
                        ) {
                            postSuccess(
                                result,
                                mapOf(
                                    "success" to false,
                                    "error" to "Access denied ($code). This model requires accepting its licence on Hugging Face and providing a valid Hugging Face access token."
                                )
                            )
                            return@launch
                        }

                        if (code != HttpURLConnection.HTTP_OK &&
                            code != HttpURLConnection.HTTP_PARTIAL
                        ) {
                            postSuccess(
                                result,
                                mapOf(
                                    "success" to false,
                                    "error" to "Download server returned HTTP $code."
                                )
                            )
                            return@launch
                        }

                        val appendMode = (code == HttpURLConnection.HTTP_PARTIAL && resumeFrom > 0L)
                        if (!appendMode) {
                            resumeFrom = 0L
                        }

                        val contentLen = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            conn.contentLengthLong
                        } else {
                            conn.contentLength.toLong()
                        }
                        val totalBytes = when {
                            contentLen > 0L -> resumeFrom + contentLen
                            expectedSizeMb > 0L -> expectedSizeMb * 1024L * 1024L
                            else -> 0L
                        }

                        var downloaded = resumeFrom
                        var lastEmit = 0L
                        emitProgress(modelId, downloaded, totalBytes, "downloading")

                        conn.inputStream.use { input ->
                            FileOutputStream(partFile, appendMode).use { output ->
                                val buffer = ByteArray(65536)
                                while (true) {
                                    if (downloadCancelled.get()) {
                                        throw CancellationException("Download cancelled by user")
                                    }
                                    val read = input.read(buffer)
                                    if (read <= 0) break
                                    output.write(buffer, 0, read)
                                    downloaded += read
                                    val now = System.currentTimeMillis()
                                    if (now - lastEmit >= PROGRESS_EMIT_INTERVAL_MS) {
                                        lastEmit = now
                                        emitProgress(modelId, downloaded, totalBytes, "downloading")
                                    }
                                }
                                output.flush()
                            }
                        }

                        if (downloadCancelled.get()) {
                            partFile.delete()
                            emitProgress(modelId, 0L, totalBytes, "cancelled")
                            postSuccess(
                                result,
                                mapOf(
                                    "success" to false,
                                    "cancelled" to true,
                                    "error" to "Download cancelled."
                                )
                            )
                            return@launch
                        }

                        if (finalFile.exists()) {
                            finalFile.delete()
                        }
                        val renamed = partFile.renameTo(finalFile)
                        if (!renamed) {
                            partFile.copyTo(finalFile, overwrite = true)
                            partFile.delete()
                        }

                        emitProgress(modelId, finalFile.length(), finalFile.length(), "completed")
                        postSuccess(
                            result,
                            mapOf(
                                "success" to true,
                                "filePath" to finalFile.absolutePath,
                                "sizeBytes" to finalFile.length()
                            )
                        )
                    } catch (_: CancellationException) {
                        partFile.delete()
                        emitProgress(modelId, 0L, 0L, "cancelled")
                        postSuccess(
                            result,
                            mapOf(
                                "success" to false,
                                "cancelled" to true,
                                "error" to "Download cancelled."
                            )
                        )
                    } catch (t: Throwable) {
                        emitProgress(modelId, 0L, 0L, "error")
                        postSuccess(
                            result,
                            mapOf(
                                "success" to false,
                                "error" to (t.message ?: "Model download failed due to a network error.")
                            )
                        )
                    } finally {
                        try {
                            conn?.disconnect()
                        } catch (_: Throwable) {
                        }
                        activeDownloadModelId = null
                        activeDownloadJob = null
                    }
                }
            }

            "cancelDownload" -> {
                downloadCancelled.set(true)
                activeDownloadJob?.cancel()
                activeDownloadJob = null
                activeDownloadModelId = null
                result.success(mapOf("cancelled" to true))
            }

            "verifyLocalModelFile" -> {
                val filePath = call.argument<String>("filePath")
                val expectedSha = call.argument<String>("expectedSha256")
                scope.launch {
                    if (filePath.isNullOrBlank()) {
                        postSuccess(result, mapOf("verified" to false, "error" to "Missing file path"))
                        return@launch
                    }
                    val file = File(filePath)
                    if (!file.exists() || !file.isFile || file.length() <= 0L) {
                        postSuccess(result, mapOf("verified" to false, "error" to "Model file not found on device"))
                        return@launch
                    }
                    if (!file.name.lowercase().endsWith(".litertlm")) {
                        postSuccess(result, mapOf("verified" to false, "error" to "Unsupported format; expected .litertlm package"))
                        return@launch
                    }
                    try {
                        val actualSha = sha256File(file)
                        if (!expectedSha.isNullOrBlank() &&
                            !actualSha.equals(expectedSha.trim(), ignoreCase = true)
                        ) {
                            postSuccess(
                                result,
                                mapOf(
                                    "verified" to false,
                                    "sha256" to actualSha,
                                    "sizeBytes" to file.length(),
                                    "error" to "SHA-256 checksum mismatch"
                                )
                            )
                            return@launch
                        }
                        postSuccess(
                            result,
                            mapOf(
                                "verified" to true,
                                "sha256" to actualSha,
                                "sizeBytes" to file.length()
                            )
                        )
                    } catch (t: Throwable) {
                        postSuccess(
                            result,
                            mapOf("verified" to false, "error" to (t.message ?: "Verification error"))
                        )
                    }
                }
            }

            "initializeModel" -> {
                val modelId = call.argument<String>("modelId")
                val filePath = call.argument<String>("filePath")
                scope.launch {
                    if (modelId.isNullOrBlank() || filePath.isNullOrBlank() || !File(filePath).exists()) {
                        postSuccess(result, mapOf("initialized" to false))
                        return@launch
                    }
                    if (!isLiteRtLmAvailable()) {
                        unloadInternal()
                        postSuccess(result, mapOf("initialized" to false))
                        return@launch
                    }
                    try {
                        unloadInternal()
                        val modelFile = File(filePath)
                        val config = EngineConfig(
                            modelPath = modelFile.absolutePath,
                            backend = Backend.CPU(),
                            cacheDir = modelFile.parent
                        )
                        val newEngine = Engine(config)
                        newEngine.initialize()
                        synchronized(engineLock) {
                            engine = newEngine
                            loadedModelId = modelId
                            loadedModelPath = filePath
                        }
                        postSuccess(result, mapOf("initialized" to true))
                    } catch (_: Throwable) {
                        unloadInternal()
                        postSuccess(result, mapOf("initialized" to false))
                    }
                }
            }

            "smokeTest" -> {
                scope.launch {
                    val ok = synchronized(engineLock) {
                        engine != null && loadedModelId != null && loadedModelPath != null
                    }
                    postSuccess(result, mapOf("passed" to ok))
                }
            }

            "generateSummary" -> {
                val systemInstruction = call.argument<String>("systemInstruction").orEmpty()
                val historyContext = call.argument<String>("historyContext").orEmpty()
                val userQuestion = call.argument<String>("userQuestion").orEmpty()
                scope.launch {
                    val activeEngine = synchronized(engineLock) { engine }
                    if (activeEngine == null) {
                        postSuccess(result, mapOf("text" to null))
                        return@launch
                    }
                    try {
                        val convConfig = ConversationConfig(
                            systemInstruction = Contents.of(systemInstruction)
                        )
                        val prompt = buildString {
                            append("Recorded local Openetra history:\n")
                            append(historyContext)
                            append("\n\nUser request: ")
                            append(userQuestion)
                            append("\nRespond concisely in plain speech-friendly sentences using only the recorded history above.")
                        }
                        val responseText = activeEngine.createConversation(convConfig).use { conv ->
                            conv.sendMessage(prompt).toString().trim()
                        }
                        postSuccess(
                            result,
                            mapOf("text" to responseText.ifBlank { null })
                        )
                    } catch (_: Throwable) {
                        postSuccess(result, mapOf("text" to null))
                    }
                }
            }

            "unloadModel" -> {
                scope.launch {
                    unloadInternal()
                    postSuccess(result, null)
                }
            }

            "deleteModelFiles" -> {
                val modelId = call.argument<String>("modelId")
                scope.launch {
                    if (modelId == activeDownloadModelId) {
                        downloadCancelled.set(true)
                        activeDownloadJob?.cancel()
                    }
                    if (modelId == loadedModelId) {
                        unloadInternal()
                    }
                    val dir = modelsDir()
                    var deleted = false
                    if (dir.exists() && !modelId.isNullOrBlank()) {
                        val prefix = sanitizeFileName(modelId)
                        dir.listFiles()?.filter {
                            it.name.startsWith(prefix) || it.name.contains(modelId)
                        }?.forEach { f ->
                            if (f.delete()) deleted = true
                        }
                    }
                    postSuccess(result, mapOf("deleted" to deleted))
                }
            }

            else -> result.notImplemented()
        }
    }

    fun dispose() {
        downloadCancelled.set(true)
        activeDownloadJob?.cancel()
        unloadInternal()
        scope.cancel()
        progressSink = null
        channel.setMethodCallHandler(null)
        progressChannel.setStreamHandler(null)
    }
}
