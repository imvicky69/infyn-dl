package com.example.media_downloader.downloader

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicReference
import java.io.File
import java.util.concurrent.ConcurrentHashMap

object AndroidDownloadManager {
    private const val TAG = "AndroidDownloadManager"
    private val scope = CoroutineScope(Dispatchers.IO + Job())
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var isInitialized = false
    @Volatile
    private var isInitializing = false
    private var initError: String? = null

    private var eventSink: EventChannel.EventSink? = null
    private val activeJobs = ConcurrentHashMap<String, Job>()
    private val activeProcessIds = ConcurrentHashMap<String, String>()

    /**
     * Atomic snapshot of yt-dlp progress, written by the callback thread and
     * consumed by the dispatch coroutine. Keeps the callback ultra-lightweight.
     */
    private data class ProgressSnapshot(val progress: Float, val etaSec: Long, val line: String)

    fun setEventSink(sink: EventChannel.EventSink?) {
        this.eventSink = sink
    }

    /**
     * Initializes the YoutubeDL and FFmpeg native runtimes on Android asynchronously.
     */
    fun init(context: Context) {
        if (isInitialized || isInitializing) return
        isInitializing = true
        scope.launch(Dispatchers.IO) {
            try {
                YoutubeDL.getInstance().init(context.applicationContext)
                FFmpeg.getInstance().init(context.applicationContext)
                isInitialized = true
                initError = null
                Log.d(TAG, "YoutubeDL and FFmpeg successfully initialized on Android")

                // Automatically check for latest yt-dlp binary update in background
                try {
                    val status = YoutubeDL.getInstance().updateYoutubeDL(context.applicationContext, YoutubeDL.UpdateChannel._STABLE)
                    Log.d(TAG, "yt-dlp auto-update check result: $status")
                } catch (e: Throwable) {
                    Log.w(TAG, "Optional background yt-dlp update check: ${e.message}")
                }
            } catch (t: Throwable) {
                isInitialized = false
                initError = "${t.javaClass.simpleName}: ${t.localizedMessage ?: t.message}"
                Log.e(TAG, "Failed to initialize YoutubeDL / FFmpeg", t)
            } finally {
                isInitializing = false
            }
        }
    }

    fun updateYoutubeDLEngine(context: Context, callback: (Result<String>) -> Unit) {
        scope.launch {
            try {
                val status = YoutubeDL.getInstance().updateYoutubeDL(context.applicationContext, YoutubeDL.UpdateChannel._STABLE)
                val ver = try { YoutubeDL.getInstance().version(context.applicationContext) } catch (_: Throwable) { "latest" }
                mainHandler.post { callback(Result.success("Updated yt-dlp to $ver ($status)")) }
            } catch (t: Throwable) {
                Log.e(TAG, "updateYoutubeDLEngine error", t)
                mainHandler.post { callback(Result.failure(Exception(t.localizedMessage ?: "Failed to update engine"))) }
            }
        }
    }

    private suspend fun ensureInitialized(context: Context): Boolean {
        if (isInitialized) return true
        init(context)
        var attempts = 0
        while (isInitializing && attempts < 100) {
            kotlinx.coroutines.delay(100)
            attempts++
        }
        return isInitialized
    }

    fun isAvailable(): Boolean = isInitialized

    fun getBackendInfo(): Map<String, Any?> {
        return mapOf(
            "platform" to "android",
            "isAvailable" to isInitialized,
            "initError" to initError,
            "ytDlpVersion" to try { YoutubeDL.getInstance().version(null) } catch (_: Throwable) { "bundled" }
        )
    }

    /**
     * Fetches real metadata and available formats for a given YouTube URL.
     */
    fun fetchMetadata(context: Context, url: String, callback: (Result<String>) -> Unit) {
        scope.launch {
            if (!ensureInitialized(context)) {
                mainHandler.post { callback(Result.failure(Exception(initError ?: "YoutubeDL not initialized on Android"))) }
                return@launch
            }

            try {
                val request = YoutubeDLRequest(url).apply {
                    addOption("--dump-single-json")
                    addOption("--no-playlist")
                    addOption("--no-update")
                    addOption("--no-check-certificates")
                    addOption("--socket-timeout", "15")
                    addOption("--retries", "3")
                    addOption("--extractor-args", "youtube:player_client=android,web;player_skip=configs,webpage")
                }
                val response = YoutubeDL.getInstance().execute(request)
                val json = response.out
                mainHandler.post { callback(Result.success(json)) }
            } catch (t: Throwable) {
                Log.e(TAG, "fetchMetadata error", t)
                mainHandler.post { callback(Result.failure(Exception(t.localizedMessage ?: "Failed to fetch metadata"))) }
            }
        }
    }

    /**
     * Fast-fetches playlist items without downloading.
     */
    fun fetchPlaylistMetadata(
        context: Context,
        url: String,
        callback: (Result<String>) -> Unit
    ) {
        scope.launch {
            if (!ensureInitialized(context)) {
                mainHandler.post {
                    callback(Result.failure(Exception(initError ?: "Downloader not initialized on Android")))
                }
                return@launch
            }

            try {
                val normalizedUrl = if (url.contains("music.youtube.com/playlist")) {
                    url.replace("music.youtube.com/playlist", "www.youtube.com/playlist")
                } else {
                    url
                }
                val request = YoutubeDLRequest(normalizedUrl).apply {
                    addOption("--flat-playlist")
                    addOption("--dump-single-json")
                    addOption("--no-update")
                    addOption("--no-check-certificates")
                    addOption("--socket-timeout", "15")
                    addOption("--retries", "3")
                    addOption("--extractor-args", "youtube:player_client=android,web;player_skip=configs,webpage")
                    addOption("--yes-playlist")
                }
                val response = YoutubeDL.getInstance().execute(request)
                val json = response.out
                mainHandler.post { callback(Result.success(json)) }
            } catch (t: Throwable) {
                Log.e(TAG, "fetchPlaylistMetadata error", t)
                mainHandler.post { callback(Result.failure(Exception(t.localizedMessage ?: "Failed to fetch playlist metadata"))) }
            }
        }
    }

    /**
     * Starts a high-speed download on Android with live progress reporting and Scoped Storage publication.
     */
    fun startDownload(
        context: Context,
        downloadId: String,
        url: String,
        format: String, // "mp4" or "mp3"
        videoQuality: String?, // e.g. "best", "1080p", "720p", "480p", "360p"
        audioQuality: String?, // e.g. "0", "2", "5"
        destinationDirectory: String? = null
    ) {
        val job = scope.launch {
            if (!ensureInitialized(context)) {
                dispatchProgress(
                    mapOf(
                        "id" to downloadId,
                        "status" to "failed",
                        "error" to (initError ?: "Native downloader not initialized on Android")
                    )
                )
                return@launch
            }

            val isAudio = format.lowercase() == "mp3"
            val stagingDir = File(context.cacheDir, "downloads_staging").apply {
                if (!exists()) mkdirs()
            }

            dispatchProgress(
                mapOf(
                    "id" to downloadId,
                    "status" to "preparing",
                    "progress" to 0.0,
                    "percentage" to "0%"
                )
            )

            val initialTitle = "Downloading Media..."
            DownloadForegroundService.start(context, downloadId, initialTitle)

            val outputTemplate = "${stagingDir.absolutePath}/%(title)s.%(ext)s"
            val request = YoutubeDLRequest(url).apply {
                addOption("-o", outputTemplate)
                addOption("--no-playlist")
                addOption("--newline")
                addOption("--no-update")
                addOption("--no-check-certificates")
                addOption("--no-mtime")
                // ios player_client: YouTube does NOT throttle iOS streams (unlike the android client
                // which is capped at ~200-500KB/s). ios also returns DASH fragmented streams,
                // making -N parallel fragment downloading actually effective on Android.
                addOption("--extractor-args", "youtube:player_client=ios,web")

                // 8 parallel fragment streams — works correctly with DASH streams from ios client
                addOption("-N", "8")
                addOption("--http-chunk-size", "10M")
                // Auto-detect & retry if YouTube throttles mid-download (re-fetches with fresh URLs)
                addOption("--throttled-rate", "100K")

                // Network reliability & anti-hang timeouts for mobile connections
                addOption("--socket-timeout", "30")
                addOption("--retries", "10")
                addOption("--fragment-retries", "10")
                addOption("--retry-sleep", "1")
                addOption("--file-access-retries", "5")

                if (isAudio) {
                    addOption("-x")
                    addOption("--audio-format", "mp3")
                    val qualityVal = audioQuality ?: "0"
                    addOption("--audio-quality", qualityVal)
                } else {
                    addOption("-S", "res,size,br")
                    val formatString = when (videoQuality?.lowercase()) {
                        "1080p" -> "bv[height<=1080]+ba/b[height<=1080]/b"
                        "720p" -> "bv[height<=720]+ba/b[height<=720]/b"
                        "480p" -> "bv[height<=480]+ba/b[height<=480]/b"
                        "360p" -> "bv[height<=360]+ba/b[height<=360]/b"
                        else -> "bv+ba/b"
                    }
                    addOption("-f", formatString)
                    addOption("--merge-output-format", "mp4")
                }
            }

            activeProcessIds[downloadId] = downloadId

            // Thread-safe atomic state — yt-dlp callback runs on its own native thread,
            // NOT on the coroutine thread. Using var here would be a data race.
            val detectedTitle = AtomicReference<String?>(null)
            val latestSnapshot = AtomicReference<ProgressSnapshot?>(null)
            val speedRegex = Regex("""at\s+([0-9.]+[A-Za-z/]+)""")
            val sizeRegex = Regex("""of\s+~?([0-9.]+[A-Za-z]+)""")

            // Timer-based dispatch coroutine: polls atomic state every 350ms.
            // This fully decouples IPC (Notification + EventChannel) from the
            // hot yt-dlp callback thread — eliminating GC pressure & main-thread flooding.
            val dispatchJob = scope.launch {
                while (isActive) {
                    delay(350)
                    val snap = latestSnapshot.getAndSet(null) ?: continue
                    val safeProgress = snap.progress.coerceAtLeast(0f)
                    val progressRatio = (safeProgress / 100.0).coerceIn(0.0, 1.0)
                    val percentage = String.format("%.1f%%", safeProgress)
                    val etaFormatted = if (snap.etaSec > 0) {
                        String.format("%02d:%02d", snap.etaSec / 60, snap.etaSec % 60)
                    } else null
                    val speed = speedRegex.find(snap.line)?.groupValues?.getOrNull(1)
                    val size = sizeRegex.find(snap.line)?.groupValues?.getOrNull(1)
                    val titleToDisplay = detectedTitle.get() ?: "Downloading Media"

                    DownloadForegroundService.updateProgress(
                        context, downloadId, titleToDisplay,
                        safeProgress.toInt(),
                        "$percentage • ${speed ?: ""} • ETA: ${etaFormatted ?: "--"}"
                    )
                    dispatchProgress(
                        mapOf(
                            "id" to downloadId,
                            "status" to "downloading",
                            "progress" to progressRatio,
                            "percentage" to percentage,
                            "speed" to speed,
                            "eta" to etaFormatted,
                            "totalSize" to size,
                            "title" to titleToDisplay,
                        )
                    )
                }
            }

            try {
                // Ultra-lightweight callback: only update atomic state.
                // NO IPC, NO regex, NO String.format — just two atomic writes.
                YoutubeDL.getInstance().execute(request, downloadId) { progressFloat, etaInSeconds, line ->
                    latestSnapshot.set(ProgressSnapshot(progressFloat, etaInSeconds, line))
                    if (detectedTitle.get() == null && line.contains("Destination:")) {
                        try {
                            val rawName = File(line.substringAfter("Destination:").trim()).nameWithoutExtension
                            detectedTitle.set(rawName.replace(Regex("""\.f[0-9]+$"""), ""))
                        } catch (_: Exception) {}
                    }
                }

                // Processing / Merge state
                dispatchProgress(
                    mapOf(
                        "id" to downloadId,
                        "status" to "processing",
                        "progress" to 0.99,
                        "percentage" to "99%",
                        "title" to (detectedTitle.get() ?: "Media Download")
                    )
                )

                // Locate generated file in staging directory
                val stagingFiles = stagingDir.listFiles { file ->
                    file.isFile && !file.name.endsWith(".part") && !file.name.endsWith(".ytdl") && !file.name.endsWith(".temp")
                }

                val finalStagingFile = stagingFiles?.maxByOrNull { it.lastModified() }

                if (finalStagingFile != null && finalStagingFile.exists()) {
                    val mimeType = MediaStorageHelper.getMimeType(finalStagingFile, isAudio)
                    val isMusicDir = destinationDirectory?.contains("Music", ignoreCase = true) == true
                    val customSubfolder = destinationDirectory?.let { dest ->
                        when {
                            dest.contains("Download/") -> dest.substringAfter("Download/").trim()
                            dest.contains("Music/") -> dest.substringAfter("Music/").trim()
                            dest.endsWith("Download", ignoreCase = true) || dest.endsWith("Music", ignoreCase = true) -> ""
                            else -> File(dest).name
                        }
                    }?.takeIf { it.isNotBlank() } ?: "infyn-dl"

                    val publicPath = MediaStorageHelper.publishMedia(
                        context = context,
                        sourceFile = finalStagingFile,
                        mimeType = mimeType,
                        isAudio = isAudio,
                        customSubfolder = customSubfolder,
                        preferMusicDirectory = isMusicDir
                    )

                    val finalTitle = detectedTitle.get() ?: finalStagingFile.nameWithoutExtension
                    DownloadForegroundService.showCompleted(context, finalTitle, "Download complete • Saved to Downloads/infyn-dl")
                    dispatchProgress(
                        mapOf(
                            "id" to downloadId,
                            "status" to "completed",
                            "progress" to 1.0,
                            "percentage" to "100%",
                            "title" to finalTitle,
                            "path" to publicPath,
                            "filename" to finalStagingFile.name
                        )
                    )
                } else {
                    // Completed with stdout log
                    val finalTitle = detectedTitle.get() ?: "Media Download"
                    DownloadForegroundService.showCompleted(context, finalTitle, "Download complete • Saved to Downloads/infyn-dl")
                    dispatchProgress(
                        mapOf(
                            "id" to downloadId,
                            "status" to "completed",
                            "progress" to 1.0,
                            "percentage" to "100%",
                            "title" to finalTitle,
                            "path" to stagingDir.absolutePath
                        )
                    )
                }
            } catch (e: Exception) {
                if (e is YoutubeDLException && e.message?.contains("destroy") == true) {
                    DownloadForegroundService.stop(context)
                    dispatchProgress(
                        mapOf(
                            "id" to downloadId,
                            "status" to "cancelled",
                            "title" to (detectedTitle.get() ?: "Media Download")
                        )
                    )
                } else {
                    Log.e(TAG, "Download execution failed", e)
                    val errorMsg = e.message ?: "Download failed on device"
                    DownloadForegroundService.showError(context, detectedTitle.get() ?: "Media Download", errorMsg)
                    dispatchProgress(
                        mapOf(
                            "id" to downloadId,
                            "status" to "failed",
                            "error" to errorMsg,
                            "title" to detectedTitle.get()
                        )
                    )
                }
            } finally {
                dispatchJob.cancel() // Stop the dispatch coroutine before cleanup
                activeProcessIds.remove(downloadId)
                activeJobs.remove(downloadId)
                if (activeJobs.isEmpty()) {
                    DownloadForegroundService.stop(context)
                }
            }
        }
        activeJobs[downloadId] = job
    }

    /**
     * Cancels an ongoing download process immediately.
     */
    fun cancelDownload(downloadId: String) {
        try {
            YoutubeDL.getInstance().destroyProcessById(downloadId)
        } catch (e: Exception) {
            Log.w(TAG, "Error destroying process $downloadId", e)
        }
        activeJobs[downloadId]?.cancel()
        activeJobs.remove(downloadId)
        activeProcessIds.remove(downloadId)

        dispatchProgress(
            mapOf(
                "id" to downloadId,
                "status" to "cancelled"
            )
        )
    }

    private fun dispatchProgress(data: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(data)
        }
    }
}
