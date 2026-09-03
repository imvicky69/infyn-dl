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
     * Determines the appropriate MIME type from file extension and audio/video mode.
     */
    fun getMimeType(file: File, isAudio: Boolean): String {
        return when (file.extension.lowercase()) {
            "mp3" -> "audio/mpeg"
            "m4a" -> "audio/mp4"
            "opus" -> "audio/opus"
            "flac" -> "audio/flac"
            "wav" -> "audio/wav"
            "aac" -> "audio/aac"
            "ogg" -> "audio/ogg"
            "mp4" -> "video/mp4"
            "mkv" -> "video/x-matroska"
            "webm" -> if (isAudio) "audio/webm" else "video/webm"
            "avi" -> "video/x-msvideo"
            "mov" -> "video/quicktime"
            else -> if (isAudio) "audio/mpeg" else "video/mp4"
        }
    }

    /**
     * Copies a completed download file from the app-private staging directory into
     * user-accessible public storage using Scoped Storage (MediaStore) on Android 10+
     * or standard public directory on Android 9 and below.
     *
     * @return The accessible display path of the published file.
     */
    fun publishMedia(
        context: Context,
        sourceFile: File,
        mimeType: String,
        isAudio: Boolean,
        customSubfolder: String? = null,
        preferMusicDirectory: Boolean = false
    ): String {
        if (!sourceFile.exists() || sourceFile.length() == 0L) {
            Log.e(TAG, "Source file does not exist or is empty: ${sourceFile.absolutePath}")
            return sourceFile.absolutePath
        }

        val fileName = sourceFile.name

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ (API 29+) Scoped Storage via MediaStore
            publishToStorage(context, sourceFile, fileName, mimeType, isAudio, customSubfolder, preferMusicDirectory)
        } else {
            // Android 9 and below (Legacy direct external directory)
            publishLegacy(context, sourceFile, fileName, mimeType, customSubfolder, preferMusicDirectory)
        }
    }

    private fun publishToStorage(
        context: Context,
        sourceFile: File,
        fileName: String,
        mimeType: String,
        isAudio: Boolean,
        customSubfolder: String? = null,
        preferMusicDirectory: Boolean = false
    ): String {
        val resolver = context.contentResolver
        val folderName = customSubfolder?.trim()?.takeIf { it.isNotBlank() } ?: "infyn-dl"

        val targetBaseDir = if (preferMusicDirectory) {
            Environment.DIRECTORY_MUSIC
        } else {
            Environment.DIRECTORY_DOWNLOADS
        }

        val collection: Uri = if (preferMusicDirectory) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }

        val relativePath = "$targetBaseDir/$folderName"

        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
        }

        var itemUri: Uri? = null
        try {
            itemUri = resolver.insert(collection, contentValues)
            if (itemUri == null) {
                Log.e(TAG, "Failed to create MediaStore entry for $fileName in $relativePath")
                return sourceFile.absolutePath
            }

            resolver.openOutputStream(itemUri)?.use { outStream ->
                FileInputStream(sourceFile).use { inStream ->
                    inStream.copyTo(outStream)
                }
            }

            contentValues.clear()
            contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(itemUri, contentValues, null, null)

            // Clean up staging file
            try {
                sourceFile.delete()
            } catch (_: Exception) {}

            val physicalPath = "/storage/emulated/0/$relativePath/$fileName"

            // Trigger MediaScanner so file manager and players index it immediately
            try {
                MediaScannerConnection.scanFile(
                    context,
                    arrayOf(physicalPath),
                    arrayOf(mimeType)
                ) { path, uri ->
                    Log.d(TAG, "MediaStore file indexed: $path -> $uri")
                }
            } catch (e: Exception) {
                Log.w(TAG, "MediaScanner scan failed", e)
            }

            Log.i(TAG, "Successfully published $fileName to $physicalPath ($mimeType)")
            return physicalPath
        } catch (e: Exception) {
            Log.e(TAG, "Error writing to MediaStore for $fileName", e)
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
        fileName: String,
        mimeType: String,
        customSubfolder: String? = null,
        preferMusicDirectory: Boolean = false
    ): String {
        try {
            val folderName = customSubfolder?.trim()?.takeIf { it.isNotBlank() } ?: "infyn-dl"
            val targetBaseDirType = if (preferMusicDirectory) {
                Environment.DIRECTORY_MUSIC
            } else {
                Environment.DIRECTORY_DOWNLOADS
            }

            val targetDir = File(
                Environment.getExternalStoragePublicDirectory(targetBaseDirType),
                folderName
            )
            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }

            val targetFile = File(targetDir, fileName)
            FileInputStream(sourceFile).use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }

            // Clean up staging file
            try {
                sourceFile.delete()
            } catch (_: Exception) {}

            MediaScannerConnection.scanFile(
                context,
                arrayOf(targetFile.absolutePath),
                arrayOf(mimeType)
            ) { path, uri ->
                Log.d(TAG, "Legacy file scanned: $path -> $uri")
            }

            Log.i(TAG, "Successfully published legacy file to ${targetFile.absolutePath}")
            return targetFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Error in legacy publish for $fileName", e)
            return sourceFile.absolutePath
        }
    }
}
