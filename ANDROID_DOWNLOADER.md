# Android Native Downloader for `infyn-dl`

This document details the architecture, packaging, platform channels, storage model, and maintenance procedures for the Android-native downloader implementation in `infyn-dl`.

---

## 1. Overview & Architecture

The Android downloader runs entirely **locally on the device**, requiring no backend servers, Python interpreters, or Termux installations.

```
Flutter UI (DownloaderScreen)
       ↓
DownloaderService (Dart abstraction)
       ↓
AndroidDownloaderService (Platform Channel Adapter)
       ↓  (MethodChannel & EventChannel)
DownloaderPlugin (Kotlin)
       ↓
AndroidDownloadManager
       ├── DownloadForegroundService (Notification & Background Persistence)
       ├── YoutubeDL (Local yt-dlp + Embedded Python Runtime)
       ├── FFmpeg (Native Android ARM64/x86_64 Binaries)
       └── MediaStorageHelper (Scoped Storage & MediaStore Publication)
```

---

## 2. Packaging & Native Dependencies

The application packages native runtimes via **`io.github.junkfood02.youtubedl-android`** (the library powering the Seal open-source downloader):

```kotlin
// android/app/build.gradle.kts
dependencies {
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-service:2.8.7")
}
```

- **`library:0.18.1`**: Bundles a standalone C/C++ Python runtime and yt-dlp executable for Android ABI targets: `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- **`ffmpeg:0.18.1`**: Bundles native FFmpeg binaries for stream merging and audio extraction.
- **`android:extractNativeLibs="true"`**: Configured in `AndroidManifest.xml` so the Android runtime unpacks the native shared libraries into app-executable storage.

---

## 3. Flutter ↔ Android Platform Channels

Communication between Dart and Kotlin is strictly decoupled through two channels:

### A. MethodChannel: `com.example.media_downloader/downloader_methods`
- **`init`**: Initializes `YoutubeDL` and `FFmpeg` instances.
- **`isAvailable`**: Returns `true` if native engines are ready.
- **`getBackendInfo`**: Returns runtime version and platform metadata.
- **`fetchMetadata`**: Executes `yt-dlp --dump-single-json` on background coroutines (`Dispatchers.IO`) and returns JSON metadata (title, uploader, thumbnail, duration, available resolutions).
- **`startDownload`**: Accepts `{ id, url, format, videoQuality, audioQuality }` and launches a non-blocking background download job.
- **`cancelDownload`**: Kills the process via `YoutubeDL.getInstance().destroyProcessById(id)`.

### B. EventChannel: `com.example.media_downloader/downloader_events`
Streams live download progress dictionaries to Dart:
```json
{
  "id": "1725324123",
  "status": "downloading",
  "progress": 0.42,
  "percentage": "42.0%",
  "speed": "4.8MiB/s",
  "eta": "00:15",
  "totalSize": "68.2MiB",
  "title": "Example Video",
  "path": "/storage/emulated/0/Download/infyn-dl/Example Video.mp4"
}
```
Possible statuses: `preparing`, `downloading`, `processing`, `completed`, `failed`, `cancelled`.

---

## 4. Modern Android Scoped Storage (`MediaStore`)

Implemented in `MediaStorageHelper.kt`:

1. **Android 10+ (API 29+)**:
   - The file is initially downloaded to the private app cache (`context.cacheDir/downloads_staging`).
   - Once completed and merged, `MediaStorageHelper` inserts an entry into `MediaStore.Downloads` (for MP4) or `MediaStore.Audio.Media` (for MP3) with `IS_PENDING = 1`.
   - The stream is copied to the public `Uri`, and `IS_PENDING` is flipped to `0`.
   - Files appear in the public `/storage/emulated/0/Download/infyn-dl/` directory, immediately visible in VLC, Files by Google, Gallery, and Android music players.
2. **Android 9 and Older (API <= 28)**:
   - Written to `Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)`.
   - `MediaScannerConnection.scanFile()` is called to index the file in the Android media library.

---

## 5. Background Execution & Foreground Service

To prevent Android's battery optimizer from terminating active downloads when the user switches apps or turns off their screen:
- **`DownloadForegroundService`** runs as an ongoing service with `foregroundServiceType="dataSync"`.
- Displays a clean notification containing:
  - Video title
  - Live progress bar (determinate or indeterminate)
  - Speed & ETA (`45% • 5.2 MB/s • ETA: 00:12`)
  - A **Cancel** button that triggers `AndroidDownloadManager.cancelDownload(id)` directly from the notification shade.
- Service terminates cleanly and dismisses notification upon download completion or cancellation.

---

## 6. Android Permissions

| Permission | Purpose |
| :--- | :--- |
| `INTERNET` | Downloading video streams from YouTube |
| `ACCESS_NETWORK_STATE` | Verifying network connectivity |
| `FOREGROUND_SERVICE` | Keeping downloads alive in the background |
| `FOREGROUND_SERVICE_DATA_SYNC` | Android 14+ specific foreground service type for network transfers |
| `POST_NOTIFICATIONS` | Android 13+ runtime permission to show download progress notifications |
| `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion="28"`) | Legacy storage access for Android 9 and older |

---

## 7. High-Speed Downloading & Network Resilience

To achieve maximum throughput and prevent freezing or format errors on Android:

1. **Chunk-Range Streaming & Buffering (`--http-chunk-size 10M`, `--buffer-size 64K`)**:
   Requests media in 10MB chunk ranges, bypassing YouTube's continuous stream rate limiter.
2. **Multi-Threaded Fragment Downloads (`-N 6`)**:
   Downloads 6 stream fragments concurrently to saturate available Wi-Fi and 5G/4G bandwidth without causing mobile memory or socket pressure.
3. **Socket Timeouts & Anti-Hang Timeouts**:
   `--socket-timeout 30`, `--retries 10`, `--fragment-retries 10`, and `--file-access-retries 5` prevent unhandled socket drops or network jitter from freezing the download job.
4. **IPC & Event Throttling**:
   Atomic snapshot polling in `AndroidDownloadManager.kt` prevents Android Binder saturation and main-thread UI jank.
5. **Direct Player Client Configuration**:
   Extractor args use `youtube:player_client=android,web;player_skip=configs,webpage` to retrieve full formats without triggering PO-token/SABR format skipping warnings.

---

## 8. How to Update yt-dlp and FFmpeg in the Future

### Option A: In-App Core Update
Users can tap **Check Update** in the app Settings screen, which runs `AndroidDownloadManager.updateYoutubeDLEngine()` in the background to fetch the latest `yt-dlp` release.

### Option B: Update Gradle Dependencies
Update the dependency version in `android/app/build.gradle.kts`:
```kotlin
implementation("io.github.junkfood02.youtubedl-android:library:<NEW_VERSION>")
implementation("io.github.junkfood02.youtubedl-android:ffmpeg:<NEW_VERSION>")
```

