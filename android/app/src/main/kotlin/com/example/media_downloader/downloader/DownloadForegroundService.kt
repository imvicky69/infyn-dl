package com.example.media_downloader.downloader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.media_downloader.MainActivity

class DownloadForegroundService : Service() {

    companion object {
        private const val TAG = "DownloadForegroundService"
        const val CHANNEL_ID = "infyn_yt_downloads_channel"
        const val CHANNEL_COMPLETE_ID = "infyn_yt_completed_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START = "com.example.media_downloader.START"
        const val ACTION_UPDATE = "com.example.media_downloader.UPDATE"
        const val ACTION_COMPLETE = "com.example.media_downloader.COMPLETE"
        const val ACTION_ITEM_FINISHED = "com.example.media_downloader.ITEM_FINISHED"
        const val ACTION_ERROR = "com.example.media_downloader.ERROR"
        const val ACTION_STOP = "com.example.media_downloader.STOP"
        const val ACTION_CANCEL_DOWNLOAD = "com.example.media_downloader.CANCEL_DOWNLOAD"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_PROGRESS = "extra_progress"
        const val EXTRA_STATUS_TEXT = "extra_status_text"
        const val EXTRA_DOWNLOAD_ID = "extra_download_id"

        fun start(context: Context, downloadId: String, title: String) {
            try {
                val intent = Intent(context, DownloadForegroundService::class.java).apply {
                    action = ACTION_START
                    putExtra(EXTRA_DOWNLOAD_ID, downloadId)
                    putExtra(EXTRA_TITLE, title)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Throwable) {
                Log.w(TAG, "Could not start foreground service: ${e.message}")
            }
        }

        fun updateProgress(context: Context, downloadId: String, title: String, progress: Int, statusText: String) {
            try {
                val intent = Intent(context, DownloadForegroundService::class.java).apply {
                    action = ACTION_UPDATE
                    putExtra(EXTRA_DOWNLOAD_ID, downloadId)
                    putExtra(EXTRA_TITLE, title)
                    putExtra(EXTRA_PROGRESS, progress)
                    putExtra(EXTRA_STATUS_TEXT, statusText)
                }
                context.startService(intent)
            } catch (e: Throwable) {
                Log.w(TAG, "Could not update progress: ${e.message}")
            }
        }

        fun showCompleted(context: Context, title: String, statusText: String) {
            try {
                val intent = Intent(context, DownloadForegroundService::class.java).apply {
                    action = ACTION_COMPLETE
                    putExtra(EXTRA_TITLE, title)
                    putExtra(EXTRA_STATUS_TEXT, statusText)
                }
                context.startService(intent)
            } catch (e: Throwable) {
                Log.w(TAG, "Could not show completion: ${e.message}")
            }
        }

        fun showItemFinished(context: Context, title: String, statusText: String) {
            try {
                val intent = Intent(context, DownloadForegroundService::class.java).apply {
                    action = ACTION_ITEM_FINISHED
                    putExtra(EXTRA_TITLE, title)
                    putExtra(EXTRA_STATUS_TEXT, statusText)
                }
                context.startService(intent)
            } catch (e: Throwable) {
                Log.w(TAG, "Could not show item finished: ${e.message}")
            }
        }

        fun showError(context: Context, title: String, errorMsg: String) {
            try {
                val intent = Intent(context, DownloadForegroundService::class.java).apply {
                    action = ACTION_ERROR
                    putExtra(EXTRA_TITLE, title)
                    putExtra(EXTRA_STATUS_TEXT, errorMsg)
                }
                context.startService(intent)
            } catch (e: Throwable) {
                Log.w(TAG, "Could not show error: ${e.message}")
            }
        }

        fun stop(context: Context) {
            try {
                val intent = Intent(context, DownloadForegroundService::class.java).apply {
                    action = ACTION_STOP
                }
                context.startService(intent)
            } catch (e: Throwable) {
                Log.w(TAG, "Could not stop service: ${e.message}")
            }
        }
    }

    private var currentDownloadId: String? = null
    private var currentTitle: String = "Media Download"
    private var wakeLock: PowerManager.WakeLock? = null
    private var lastNotificationProgress = -1
    private var lastNotificationStatus = ""

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                acquireWakeLock()
                currentDownloadId = intent.getStringExtra(EXTRA_DOWNLOAD_ID)
                currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: "Media Download"
                lastNotificationProgress = -1
                lastNotificationStatus = ""
                val notification = buildOngoingNotification(currentTitle, 0, "Connecting to YouTube...", true)
                startForegroundCompat(notification)
            }
            ACTION_UPDATE -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
                val statusText = intent.getStringExtra(EXTRA_STATUS_TEXT) ?: "Downloading..."
                if (progress != lastNotificationProgress || statusText != lastNotificationStatus) {
                    lastNotificationProgress = progress
                    lastNotificationStatus = statusText
                    val notification = buildOngoingNotification(title, progress, statusText, false)
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    manager.notify(NOTIFICATION_ID, notification)
                }
            }
            ACTION_COMPLETE -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Download Complete"
                val statusText = intent.getStringExtra(EXTRA_STATUS_TEXT) ?: "Saved to Downloads/infyn-dl"
                showTerminalNotification(title, statusText, false)
                releaseWakeLock()
                stopForegroundCompat()
                stopSelf()
            }
            ACTION_ERROR -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Download Failed"
                val statusText = intent.getStringExtra(EXTRA_STATUS_TEXT) ?: "Failed to download media"
                showTerminalNotification(title, statusText, true)
                releaseWakeLock()
                stopForegroundCompat()
                stopSelf()
            }
            ACTION_ITEM_FINISHED -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Item Downloaded"
                val statusText = intent.getStringExtra(EXTRA_STATUS_TEXT) ?: "Downloads in progress..."
                showTerminalNotification(title, "Saved to Downloads/infyn-dl", false)
                val notification = buildOngoingNotification(currentTitle, 0, statusText, true)
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(NOTIFICATION_ID, notification)
            }
            ACTION_CANCEL_DOWNLOAD -> {
                AndroidDownloadManager.cancelAll()
                releaseWakeLock()
                stopForegroundCompat()
                stopSelf()
            }
            ACTION_STOP -> {
                releaseWakeLock()
                stopForegroundCompat()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun startForegroundCompat(notification: Notification) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "startForeground error: ${e.message}", e)
        }
    }

    private fun stopForegroundCompat() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (e: Throwable) {
            Log.w(TAG, "stopForeground error: ${e.message}")
        }
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun acquireWakeLock() {
        if (wakeLock == null) {
            try {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "InfynDL:DownloadForegroundWakeLock"
                ).apply {
                    setReferenceCounted(false)
                    acquire(30 * 60 * 1000L /* 30 minutes max */)
                }
                Log.d(TAG, "WakeLock acquired for background downloading")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to acquire WakeLock: ${e.message}")
            }
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "WakeLock released")
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.w(TAG, "Failed to release WakeLock: ${e.message}")
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val progressChannel = NotificationChannel(
                CHANNEL_ID,
                "Live Downloads",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live download speed, ETA, and progress"
                setShowBadge(false)
            }

            val completeChannel = NotificationChannel(
                CHANNEL_COMPLETE_ID,
                "Completed Downloads",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Notifies when a media download finishes"
                setShowBadge(true)
            }

            manager.createNotificationChannel(progressChannel)
            manager.createNotificationChannel(completeChannel)
        }
    }

    private fun buildOngoingNotification(
        title: String,
        progress: Int,
        statusText: String,
        isIndeterminate: Boolean
    ): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val cancelIntent = Intent(this, DownloadForegroundService::class.java).apply {
            action = ACTION_CANCEL_DOWNLOAD
        }
        val cancelPendingIntent = PendingIntent.getService(
            this,
            1,
            cancelIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(statusText)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Cancel", cancelPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        if (isIndeterminate) {
            builder.setProgress(100, 0, true)
        } else {
            builder.setProgress(100, progress, false)
        }

        return builder.build()
    }

    private fun showTerminalNotification(title: String, message: String, isError: Boolean) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val icon = if (isError) android.R.drawable.stat_notify_error else android.R.drawable.stat_sys_download_done
        val cleanSummary = if (message.length > 80) message.take(77) + "..." else message
        val notification = NotificationCompat.Builder(this, CHANNEL_COMPLETE_ID)
            .setContentTitle(title)
            .setContentText(cleanSummary)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setSmallIcon(icon)
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        val notificationId = (System.currentTimeMillis() % 100000).toInt() + 2000
        manager.notify(notificationId, notification)
    }
}
