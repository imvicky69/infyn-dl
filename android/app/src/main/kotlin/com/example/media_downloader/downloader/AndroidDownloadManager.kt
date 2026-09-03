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
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ConcurrentHashMap

object AndroidDownloadManager {
    private const val TAG = "AndroidDownloadManager"
    private val scope = CoroutineScope(Dispatchers.IO + Job())
    private val mainHandler = Handler(Looper.getMainLooper())

    private var isInitialized = false
    private var initError: String? = null

    private var eventSink: EventChannel.EventSink? = null
    private val activeJobs = ConcurrentHashMap<String, Job>()
    private val activeProcessIds = ConcurrentHashMap<String, String>()

    fun setEventSink(sink: EventChannel.EventSink?) {
        this.eventSink = sink
    }

    /**
     * Initializes the YoutubeDL and FFmpeg native runtimes on Android.
     */
    fun init(context: Context) {
        if (isInitialized) return
        try {
            YoutubeDL.getInstance().init(context.applicationContext)
            FFmpeg.getInstance().init(context.applicationContext)
            isInitialized = true
            initError = null
            Log.d(TAG, "YoutubeDL and FFmpeg successfully initialized on Android")
        } catch (e: Exception) {
            initError = e.message ?: "Unknown initialization error"
            Log.e(TAG, "Failed to initialize YoutubeDL / FFmpeg", e)
        }
    }

    fun isAvailable(): Boolean = isInitialized

    fun getBackendInfo(): Map<String, Any?> {
        return mapOf(
            "platform" to "android",
            "isAvailable" to isInitialized,
            "initError" to initError,
            "ytDlpVersion" to try { YoutubeDL.getInstance().version(null) } catch (_: Exception) { "bundled" }
        )
    }

    /**
     * Fetches real metadata and available formats for a given YouTube URL.
     */
    fun fetchMetadata(context: Context, url: String, callback: (Result<String>) -> Unit) {
        scope.launch {
            if (!isInitialized) {
                init(context)
            }
            if (!isInitialized) {
                mainHandler.post { callback(Result.failure(Exception(initError ?: "YoutubeDL not initialized"))) }
                return@launch
            }

            try {
                val request = YoutubeDLRequest(url).apply {
                    addOption("--dump-single-json")
                    addOption("--no-playlist")
                }
                val response = YoutubeDL.getInstance().execute(request)
                val json = response.out
                mainHandler.post { callback(Result.success(json)) }
            } catch (e: Exception) {
                Log.e(TAG, "fetchMetadata error", e)
                mainHandler.post { callback(Result.failure(e)) }
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
            if (!isInitialized) {
                init(context)
            }
            if (!isInitialized) {
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
                    addOption("--extractor-args", "youtube:player_client=android,web")
                    addOption("--yes-playlist")
                }
                val response = YoutubeDL.getInstance().execute(request)
                val json = response.out
                mainHandler.post { callback(Result.success(json)) }
            } catch (e: Exception) {
                Log.e(TAG, "fetchPlaylistMetadata error", e)
                mainHandler.post { callback(Result.failure(e)) }
            }
        }
    }

    /**
     * Starts a download on Android with live progress reporting and Scoped Storage publication.
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
            if (!isInitialized) {
                init(context)
            }
            if (!isInitialized) {
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
                addOption("-N", "4")

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
            var detectedTitle: String? = null
            val speedRegex = Regex("""at\s+([0-9.]+[A-Za-z/]+)""")
            val sizeRegex = Regex("""of\s+~?([0-9.]+[A-Za-z]+)""")

            try {
                val response = YoutubeDL.getInstance().execute(request, downloadId) { progressFloat, etaInSeconds, line ->
                    val safeProgress = progressFloat.coerceAtLeast(0f)
                    val progressRatio = (safeProgress / 100.0).coerceIn(0.0, 1.0)
                    val percentage = String.format("%.1f%%", safeProgress)
                    val etaFormatted = if (etaInSeconds > 0) {
                        String.format("%02d:%02d", etaInSeconds / 60, etaInSeconds % 60)
                    } else null

                    val speed = speedRegex.find(line)?.groupValues?.getOrNull(1)
                    val size = sizeRegex.find(line)?.groupValues?.getOrNull(1)

                    if (detectedTitle == null && line.contains("Destination:")) {
                        val pathPart = line.substringAfter("Destination:").trim()
                        val rawName = File(pathPart).nameWithoutExtension
                        detectedTitle = rawName.replace(Regex("""\.f[0-9]+$"""), "")
                    }

                    val titleToDisplay = detectedTitle ?: "Downloading Media"

                    // Update notification
                    DownloadForegroundService.updateProgress(
                        context,
                        downloadId,
                        titleToDisplay,
                        progressFloat.toInt(),
                        "$percentage • ${speed ?: ""} • ETA: ${etaFormatted ?: "--"}"
                    )

                    // Dispatch to Flutter
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
                            "rawLog" to line
                        )
                    )
                }

                // Processing / Merge state
                dispatchProgress(
                    mapOf(
                        "id" to downloadId,
                        "status" to "processing",
                        "progress" to 0.99,
                        "percentage" to "99%",
                        "title" to (detectedTitle ?: "Media Download")
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

                    dispatchProgress(
                        mapOf(
                            "id" to downloadId,
                            "status" to "completed",
                            "progress" to 1.0,
                            "percentage" to "100%",
                            "title" to (detectedTitle ?: finalStagingFile.nameWithoutExtension),
                            "path" to publicPath,
                            "filename" to finalStagingFile.name
                        )
                    )
                } else {
                    // Completed with stdout log
                    dispatchProgress(
                        mapOf(
                            "id" to downloadId,
                            "status" to "completed",
                            "progress" to 1.0,
                            "percentage" to "100%",
                            "title" to (detectedTitle ?: "Media Download"),
                            "path" to stagingDir.absolutePath
                        )
                    )
                }
            } catch (e: Exception) {
                if (e is YoutubeDLException && e.message?.contains("destroy") == true) {
                    dispatchProgress(
                        mapOf(
                            "id" to downloadId,
                            "status" to "cancelled",
                            "title" to (detectedTitle ?: "Media Download")
                        )
                    )
                } else {
                    Log.e(TAG, "Download execution failed", e)
                    dispatchProgress(
                        mapOf(
                            "id" to downloadId,
                            "status" to "failed",
                            "error" to (e.message ?: "Download failed on device"),
                            "title" to detectedTitle
                        )
                    )
                }
            } finally {
                activeProcessIds.remove(downloadId)
                activeJobs.remove(downloadId)
                DownloadForegroundService.stop(context)
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
