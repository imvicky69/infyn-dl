package com.example.media_downloader.downloader

import android.content.Context
import android.os.Environment
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
import kotlinx.coroutines.SupervisorJob
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
    // SupervisorJob: a failure in one download coroutine does NOT cancel sibling downloads.
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
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

                // Clean up any stale staging artifacts from prior sessions
                try {
                    File(context.cacheDir, "downloads_staging").deleteRecursively()
                } catch (_: Exception) {}

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
            "isInitializing" to isInitializing,
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
        destinationDirectory: String? = null,
        isBatch: Boolean = false,
        isLastBatchItem: Boolean = true,
        batchPlaylistName: String? = null
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
            val stagingDir = File(File(context.cacheDir, "downloads_staging"), downloadId).apply {
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

            val initialTitle = if (isBatch && !batchPlaylistName.isNullOrBlank()) {
                "Downloading $batchPlaylistName..."
            } else {
                "Downloading Media..."
            }
            DownloadForegroundService.start(context, downloadId, initialTitle)

            val outputTemplate = "${stagingDir.absolutePath}/%(title)s.%(ext)s"
            val request = YoutubeDLRequest(url).apply {
                addOption("-o", outputTemplate)
                addOption("--no-playlist")
                addOption("--newline")
                addOption("--no-update")
                addOption("--no-check-certificates")
                addOption("--no-mtime")

                // High-speed parallel fragment downloading and chunk buffering
                addOption("-N", "8")
                addOption("--http-chunk-size", "10M")
                addOption("--buffer-size", "64K")

                // Network reliability & anti-hang timeouts for mobile connections
                addOption("--socket-timeout", "30")
                addOption("--retries", "10")
                addOption("--fragment-retries", "10")
                addOption("--retry-sleep", "1")
                addOption("--file-access-retries", "5")

                if (isAudio) {
                    // Prefer the native AAC/M4A stream from YouTube (itag 140, ~128 kbps).
                    // This avoids ALL FFmpeg post-processing — no transcode, no remux.
                    // audioQuality selects the tier:
                    //   "high"  → prefer opus ~160 kbps (WebM) if m4a unavailable; best quality
                    //   "mid"   → native m4a ~128 kbps (default, always available)
                    //   "low"   → 48 kbps m4a mobile stream (smallest file)
                    // Note: we do NOT use --extract-audio or --audio-format m4a, because those
                    // flags unconditionally invoke FFmpeg even on an already-correct stream.
                    val audioFormatString = when (audioQuality) {
                        "high" -> "bestaudio[ext=m4a][abr>120]/bestaudio[ext=m4a]/bestaudio[acodec=aac]/bestaudio/best"
                        "low"  -> "worstaudio[ext=m4a]/bestaudio[ext=m4a][abr<=64]/bestaudio[ext=m4a]/worstaudio/worst/best"
                        else   -> "bestaudio[ext=m4a]/bestaudio[acodec=aac]/bestaudio/best"
                    }
                    addOption("-f", audioFormatString)
                    // No --extract-audio, no --audio-format: keep native container as-is.
                    // Fragment parallelism for audio (segments are small; 8 is effective on mobile)
                    addOption("-N", "8")
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

            // Timer-based dispatch coroutine: polls atomic state every 250ms.
            // Check snapshot immediately first (no leading delay) so the first
            // progress event fires in <100ms instead of waiting a full 350ms cycle.
            val dispatchJob = scope.launch {
                var firstCheck = true
                while (isActive) {
                    if (!firstCheck) delay(250)
                    firstCheck = false
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

                // Locate generated file in the job's dedicated staging directory
                val finalStagingFile = if (isAudio) {
                    // Prefer m4a (native YouTube AAC stream, no re-encode).
                    // Fallback to opus/ogg (opus remuxed), then any other audio.
                    // We no longer produce .mp3 — direct remux skips FFmpeg entirely.
                    val audioExts = listOf("m4a", "opus", "ogg", "aac", "flac", "wav", "mp3", "webm", "mp4")
                    audioExts.firstNotNullOfOrNull { ext ->
                        stagingDir.listFiles { file ->
                            file.isFile &&
                            !file.name.endsWith(".part") &&
                            !file.name.endsWith(".ytdl") &&
                            !file.name.endsWith(".temp") &&
                            file.extension.equals(ext, ignoreCase = true)
                        }?.maxByOrNull { it.lastModified() }
                    }
                } else {
                    stagingDir.listFiles { file ->
                        file.isFile && !file.name.endsWith(".part") && !file.name.endsWith(".ytdl") && !file.name.endsWith(".temp") &&
                        file.extension.lowercase() in listOf("mp4", "mkv", "webm", "mov", "avi")
                    }?.maxByOrNull { it.lastModified() }
                }

                if (finalStagingFile != null && finalStagingFile.exists()) {
                    val targetDir = if (!destinationDirectory.isNullOrBlank()) {
                        File(destinationDirectory)
                    } else {
                        File(context.getExternalFilesDir(if (isAudio) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_DOWNLOADS) ?: context.filesDir, "Music")
                    }
                    if (!targetDir.exists()) {
                        targetDir.mkdirs()
                    }
                    val targetFile = File(targetDir, finalStagingFile.name)
                    finalStagingFile.copyTo(targetFile, overwrite = true)
                    val savedPath = targetFile.absolutePath

                    // Immediate cleanup of staging directory
                    try {
                        finalStagingFile.delete()
                        stagingDir.deleteRecursively()
                    } catch (_: Exception) {}

                    val finalTitle = detectedTitle.get() ?: finalStagingFile.nameWithoutExtension
                    val remainingJobs = (activeJobs.size - 1).coerceAtLeast(0)
                    if (isBatch) {
                        if (isLastBatchItem) {
                            val completeTitle = if (!batchPlaylistName.isNullOrBlank()) {
                                "Batch Complete: $batchPlaylistName"
                            } else {
                                "Download Complete"
                            }
                            DownloadForegroundService.showCompleted(context, completeTitle, "All songs saved")
                        } else {
                            // Intermediate batch item: keep it completely silent!
                            DownloadForegroundService.showItemFinished(
                                context,
                                finalTitle,
                                "Saved • Downloading next song..."
                            )
                        }
                    } else {
                        if (remainingJobs <= 0) {
                            DownloadForegroundService.showCompleted(context, finalTitle, "Download complete")
                        } else {
                            DownloadForegroundService.showItemFinished(context, finalTitle, "$remainingJobs remaining download(s)...")
                        }
                    }
                    dispatchProgress(
                        mapOf(
                            "id" to downloadId,
                            "status" to "completed",
                            "progress" to 1.0,
                            "percentage" to "100%",
                            "title" to finalTitle,
                            "path" to savedPath,
                            "filename" to finalStagingFile.name
                        )
                    )
                } else {
                    // yt-dlp exited without producing a usable output file.
                    // This can happen if the stream was skipped (already downloaded),
                    // or if a temp/part file was left behind. Treat this as a failure
                    // so the Dart layer does NOT store a broken directory path as outputFilePath.
                    val finalTitle = detectedTitle.get() ?: "Media Download"
                    Log.w(TAG, "Download '$downloadId' completed but no output file found in staging dir: ${stagingDir.absolutePath}")
                    if (!isBatch || isLastBatchItem) {
                        DownloadForegroundService.showError(context, finalTitle, "Output file not found after download")
                    }
                    dispatchProgress(
                        mapOf(
                            "id" to downloadId,
                            "status" to "failed",
                            "error" to "Output file not found. The video may be unavailable or already downloaded.",
                            "title" to finalTitle
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
                    val rawMsg = e.message ?: "Download failed on device"
                    val errorMsg = cleanErrorMessage(rawMsg)
                    if (!isBatch || isLastBatchItem) {
                        DownloadForegroundService.showError(context, detectedTitle.get() ?: "Media Download", errorMsg)
                    }
                    dispatchProgress(
                        mapOf(
                            "id" to downloadId,
                            "status" to "failed",
                            "error" to errorMsg,
                            "title" to detectedTitle.get(),
                            "rawLog" to rawMsg
                        )
                    )
                }
            } finally {
                dispatchJob.cancel() // Stop the dispatch coroutine before cleanup
                activeProcessIds.remove(downloadId)
                activeJobs.remove(downloadId)
                try {
                    stagingDir.deleteRecursively()
                } catch (_: Exception) {}
                if (activeJobs.isEmpty()) {
                    if (!isBatch || isLastBatchItem) {
                        DownloadForegroundService.stop(context)
                    }
                }
            }
        }
        activeJobs[downloadId] = job
    }

    /**
     * Cancels an ongoing download process immediately.
     */
    fun cancelDownload(context: Context? = null, downloadId: String) {
        try {
            YoutubeDL.getInstance().destroyProcessById(downloadId)
        } catch (e: Exception) {
            Log.w(TAG, "Error destroying process $downloadId", e)
        }
        activeJobs[downloadId]?.cancel()
        activeJobs.remove(downloadId)
        activeProcessIds.remove(downloadId)

        if (context != null && activeJobs.isEmpty()) {
            DownloadForegroundService.stop(context)
        }

        dispatchProgress(
            mapOf(
                "id" to downloadId,
                "status" to "cancelled"
            )
        )
    }

    /**
     * Cancels all ongoing download jobs immediately.
     */
    fun cancelAll(context: Context? = null) {
        for ((id, _) in activeProcessIds) {
            try {
                YoutubeDL.getInstance().destroyProcessById(id)
            } catch (e: Exception) {
                Log.w(TAG, "Error destroying process $id", e)
            }
        }
        for ((_, job) in activeJobs) {
            job.cancel()
        }
        activeJobs.clear()
        activeProcessIds.clear()
        if (context != null) {
            DownloadForegroundService.stop(context)
        }
    }

    private fun cleanErrorMessage(raw: String?): String {
        if (raw.isNullOrBlank()) return "Download failed on device"
        if (raw.contains("Private video", ignoreCase = true)) return "This video is private and cannot be downloaded."
        if (raw.contains("Video unavailable", ignoreCase = true)) return "The requested YouTube video is unavailable."
        if (raw.contains("Sign in to confirm your age", ignoreCase = true)) return "This video requires age confirmation."
        if (raw.contains("Incomplete YouTube ID", ignoreCase = true) || raw.contains("not a valid URL", ignoreCase = true)) return "Invalid YouTube URL provided."
        val cleanLines = raw.lines()
            .map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith("WARNING", ignoreCase = true) && !it.startsWith("[debug]", ignoreCase = true) }

        val errorLine = cleanLines.lastOrNull { it.startsWith("ERROR:", ignoreCase = true) }
            ?: cleanLines.lastOrNull()
            ?: raw

        val message = errorLine.removePrefix("ERROR:").trim()
        if (message.contains("HTTP Error 403", ignoreCase = true)) {
            return "Access forbidden (403). Please tap 'Check Update' in Settings."
        }
        if (message.contains("Requested format is not available", ignoreCase = true)) {
            return "Requested media format is unavailable. Try another quality option."
        }

        return message
    }

    private fun dispatchProgress(data: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(data)
        }
    }
}
