package com.example.media_downloader.downloader

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DownloaderPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL_NAME = "com.example.media_downloader/downloader_methods"
        const val EVENT_CHANNEL_NAME = "com.example.media_downloader/downloader_events"

        fun register(context: Context, messenger: BinaryMessenger): DownloaderPlugin {
            val plugin = DownloaderPlugin()
            plugin.init(context, messenger)
            return plugin
        }
    }

    private var context: Context? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null

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
            "startDownload" -> {
                val id = call.argument<String>("id") ?: System.currentTimeMillis().toString()
                val url = call.argument<String>("url")
                val format = call.argument<String>("format") ?: "mp4"
                val videoQuality = call.argument<String>("videoQuality")
                val audioQuality = call.argument<String>("audioQuality")

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
                    audioQuality = audioQuality
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
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        AndroidDownloadManager.setEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        AndroidDownloadManager.setEventSink(null)
    }
}
