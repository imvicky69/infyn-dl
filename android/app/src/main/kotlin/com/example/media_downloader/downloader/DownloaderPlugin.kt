package com.example.media_downloader.downloader

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File

class DownloaderPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, PluginRegistry.RequestPermissionsResultListener {

    companion object {
        const val METHOD_CHANNEL_NAME = "com.example.media_downloader/downloader_methods"
        const val EVENT_CHANNEL_NAME = "com.example.media_downloader/downloader_events"
        private const val REQUEST_CODE_NOTIFICATIONS = 1002

        fun register(context: Context, messenger: BinaryMessenger): DownloaderPlugin {
            val plugin = DownloaderPlugin()
            plugin.init(context, messenger)
            return plugin
        }
    }

    private var context: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        init(binding.applicationContext, binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activity = binding.activity
        this.activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        this.activity = null
        this.activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.activity = binding.activity
        this.activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        this.activity = null
        this.activityBinding = null
    }

    fun init(ctx: Context, messenger: BinaryMessenger) {
        this.context = ctx
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME).apply {
            setMethodCallHandler(this@DownloaderPlugin)
        }
        eventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME).apply {
            setStreamHandler(this@DownloaderPlugin)
        }

        // Initialize YoutubeDL and FFmpeg runtimes early
        AndroidDownloadManager.init(ctx)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context
        if (ctx == null) {
            result.error("NO_CONTEXT", "Application context is not available", null)
            return
        }

        when (call.method) {
            "init" -> {
                AndroidDownloadManager.init(ctx)
                result.success(AndroidDownloadManager.isAvailable())
            }
            "isAvailable" -> {
                result.success(AndroidDownloadManager.isAvailable())
            }
            "getBackendInfo" -> {
                result.success(AndroidDownloadManager.getBackendInfo())
            }
            "hasNotificationPermission" -> {
                val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                } else {
                    NotificationManagerCompat.from(ctx).areNotificationsEnabled()
                }
                result.success(hasPermission)
            }
            "requestNotificationPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val act = activity
                    if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else if (act != null) {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            act,
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            REQUEST_CODE_NOTIFICATIONS
                        )
                    } else {
                        result.success(false)
                    }
                } else {
                    result.success(NotificationManagerCompat.from(ctx).areNotificationsEnabled())
                }
            }
            "isIgnoringBatteryOptimizations" -> {
                val powerManager = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
                val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    powerManager.isIgnoringBatteryOptimizations(ctx.packageName)
                } else {
                    true
                }
                result.success(isIgnoring)
            }
            "requestIgnoreBatteryOptimizations" -> {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (!powerManager.isIgnoringBatteryOptimizations(ctx.packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:${ctx.packageName}")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            ctx.startActivity(intent)
                        }
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("BATTERY_OPT_ERROR", e.localizedMessage ?: "Failed to open battery settings", null)
                }
            }
            "fetchMetadata" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "URL must not be empty", null)
                    return
                }

                AndroidDownloadManager.fetchMetadata(ctx, url) { res ->
                    res.fold(
                        onSuccess = { jsonString -> result.success(jsonString) },
                        onFailure = { error ->
                            result.error("FETCH_ERROR", error.localizedMessage ?: "Failed to fetch metadata", null)
                        }
                    )
                }
            }
            "fetchPlaylistMetadata" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "URL must not be empty", null)
                    return
                }

                AndroidDownloadManager.fetchPlaylistMetadata(ctx, url) { res ->
                    res.fold(
                        onSuccess = { jsonString -> result.success(jsonString) },
                        onFailure = { error ->
                            result.error("FETCH_ERROR", error.localizedMessage ?: "Failed to fetch playlist metadata", null)
                        }
                    )
                }
            }
            "startDownload" -> {
                val id = call.argument<String>("id") ?: System.currentTimeMillis().toString()
                val url = call.argument<String>("url")
                val format = call.argument<String>("format") ?: "mp4"
                val videoQuality = call.argument<String>("videoQuality")
                val audioQuality = call.argument<String>("audioQuality")
                val destinationDirectory = call.argument<String>("destinationDirectory")

                if (url.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "URL must not be empty", null)
                    return
                }

                AndroidDownloadManager.startDownload(
                    context = ctx,
                    downloadId = id,
                    url = url,
                    format = format,
                    videoQuality = videoQuality,
                    audioQuality = audioQuality,
                    destinationDirectory = destinationDirectory
                )
                result.success(id)
            }
            "cancelDownload" -> {
                val id = call.argument<String>("id")
                if (id != null) {
                    AndroidDownloadManager.cancelDownload(id)
                }
                result.success(true)
            }
            "updateEngine" -> {
                AndroidDownloadManager.updateYoutubeDLEngine(ctx) { res ->
                    res.fold(
                        onSuccess = { msg -> result.success(msg) },
                        onFailure = { error ->
                            result.error("UPDATE_ERROR", error.localizedMessage ?: "Failed to update engine", null)
                        }
                    )
                }
            }
            "openFile" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("INVALID_PATH", "File path cannot be empty", null)
                    return
                }

                try {
                    val file = File(path)
                    val mimeType = if (file.extension.equals("mp3", ignoreCase = true)) "audio/*" else "video/*"
                    val contentUri = if (path.startsWith("content://")) {
                        Uri.parse(path)
                    } else {
                        FileProvider.getUriForFile(ctx, "${ctx.packageName}.provider", file)
                    }

                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(contentUri, mimeType)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    ctx.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("OPEN_FAILED", e.localizedMessage ?: "Could not open file", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == REQUEST_CODE_NOTIFICATIONS) {
            val isGranted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(isGranted)
            pendingPermissionResult = null
            return true
        }
        return false
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        AndroidDownloadManager.setEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        AndroidDownloadManager.setEventSink(null)
    }
}
