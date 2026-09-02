package com.example.media_downloader.downloader

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

object MediaStorageHelper {
    private const val TAG = "MediaStorageHelper"

    /**
     * Copies a completed download file from the app-private staging directory into
     * user-accessible public storage using Scoped Storage (MediaStore) on Android 10+
     * or standard Downloads directory on Android 9 and below.
     *
     * @return The accessible display path of the published file.
     */
    fun publishToPublicStorage(
        context: Context,
        sourceFile: File,
        mimeType: String,
        isAudio: Boolean
    ): String {
        if (!sourceFile.exists() || sourceFile.length() == 0L) {
            Log.e(TAG, "Source file does not exist or is empty: ${sourceFile.absolutePath}")
            return sourceFile.absolutePath
        }

        val fileName = sourceFile.name

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ (API 29+) Scoped Storage via MediaStore
            publishViaMediaStore(context, sourceFile, fileName, mimeType, isAudio)
        } else {
            // Android 9 and below (Legacy direct external directory)
            publishLegacy(context, sourceFile, fileName)
        }
    }

    private fun publishViaMediaStore(
        context: Context,
        sourceFile: File,
        fileName: String,
        mimeType: String,
        isAudio: Boolean
    ): String {
        val resolver = context.contentResolver
        val collection: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (isAudio) {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
        } else {
            MediaStore.Files.getContentUri("external")
        }

        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.IS_PENDING, 1)
                val relativePath = if (isAudio) {
                    Environment.DIRECTORY_MUSIC + "/infyn-yt"
                } else {
                    Environment.DIRECTORY_DOWNLOADS + "/infyn-yt"
                }
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            }
        }

        var itemUri: Uri? = null
        try {
            itemUri = resolver.insert(collection, contentValues)
            if (itemUri == null) {
                Log.e(TAG, "Failed to create MediaStore entry for $fileName")
                return sourceFile.absolutePath
            }

            resolver.openOutputStream(itemUri)?.use { outStream ->
                FileInputStream(sourceFile).use { inStream ->
                    inStream.copyTo(outStream)
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(itemUri, contentValues, null, null)
            }

            // Clean up staging file
            try {
                sourceFile.delete()
            } catch (_: Exception) {}

            val relativeFolder = if (isAudio) "Music/infyn-yt" else "Download/infyn-yt"
            return "/storage/emulated/0/$relativeFolder/$fileName"
        } catch (e: Exception) {
            Log.e(TAG, "Error writing to MediaStore", e)
            if (itemUri != null) {
                try {
                    resolver.delete(itemUri, null, null)
                } catch (_: Exception) {}
            }
            return sourceFile.absolutePath
        }
    }

    private fun publishLegacy(
        context: Context,
        sourceFile: File,
        fileName: String
    ): String {
        try {
            val downloadsDir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                "infyn-yt"
            )
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }

            val targetFile = File(downloadsDir, fileName)
            FileInputStream(sourceFile).use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }

            MediaScannerConnection.scanFile(
                context,
                arrayOf(targetFile.absolutePath),
                null
            ) { path, uri ->
                Log.d(TAG, "Legacy file scanned: $path -> $uri")
            }

            try {
                sourceFile.delete()
            } catch (_: Exception) {}

            return targetFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Legacy copy error", e)
            return sourceFile.absolutePath
        }
    }
}
