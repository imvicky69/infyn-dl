<div align="center">
  <img src="assets/logo.png" alt="Infyn DL Logo" width="130" />
  <h1>Infyn DL</h1>
  <p><strong>Universal, Local-First Media & Music Downloader for Android</strong></p>

  <p>
    <a href="https://github.com/imvicky69/infyn-dl/releases"><img src="https://img.shields.io/github/v/release/imvicky69/infyn-dl?include_prereleases&logo=github&color=00B4D8&label=Release" alt="Latest Release"></a>
    <a href="https://github.com/imvicky69/infyn-dl/actions/workflows/ci.yml"><img src="https://img.shields.io/github/workflows/status/imvicky69/infyn-dl/CI%20&%20Code%20Quality?logo=github&label=CI" alt="CI Status"></a>
    <a href="https://github.com/imvicky69/infyn-dl/releases"><img src="https://img.shields.io/github/downloads/imvicky69/infyn-dl/total?color=success&logo=github" alt="Downloads"></a>
    <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter"></a>
    <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart"></a>
    <a href="https://github.com/yt-dlp/yt-dlp"><img src="https://img.shields.io/badge/Engine-yt--dlp%20Native-FF0000?logo=youtube&logoColor=white" alt="yt-dlp"></a>
    <a href="https://ffmpeg.org"><img src="https://img.shields.io/badge/Audio-FFmpeg%20Native-007808?logo=ffmpeg&logoColor=white" alt="FFmpeg"></a>
    <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Platform-Android%207.0%2B-3DDC84?logo=android&logoColor=white" alt="Android"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-black.svg" alt="License: MIT"></a>
  </p>
</div>

---

## 🌟 Overview

**Infyn DL** is a high-performance, privacy-respecting media and music downloader built with Flutter for Android. It executes **`yt-dlp` and `FFmpeg` locally on your device** without routing traffic through third-party servers, external cloud APIs, or tracking services.

Whether you are downloading a single 4K 60fps video, extracting native high-bitrate M4A/MP3 audio from YouTube Music, or batch-downloading full playlists and albums, Infyn DL delivers an uninterrupted, offline-first experience with a sleek, minimalist aesthetic.

---

## 📥 Downloads & Releases

Pre-compiled, signed APK packages are available on our [**GitHub Releases Page**](https://github.com/imvicky69/infyn-dl/releases).

| Package | File Name | Description |
| :--- | :--- | :--- |
| 📱 **ARM64 APK (Recommended)** | [`Infyn-DL-*-android-arm64.apk`](https://github.com/imvicky69/infyn-dl/releases/latest) | **Lightweight (~69 MB)**: Optimized for 99% of modern 64-bit Android phones and tablets. |
| 📱 **Universal APK** | [`Infyn-DL-*-android.apk`](https://github.com/imvicky69/infyn-dl/releases/latest) | Compatible with all Android architectures (`arm64-v8a`, `armeabi-v7a`, `x86_64`). |
| 📱 **ARMv7 APK** | [`Infyn-DL-*-android-armeabi-v7a.apk`](https://github.com/imvicky69/infyn-dl/releases/latest) | Optimized build for older 32-bit Android devices. |

---

## 🚀 What's New in v1.0.3

- **Instant Native M4A Streaming & Downloading**: Directly pulls native AAC/M4A streams without CPU-heavy local re-encoding. Downloads finish in seconds and conserve battery life.
- **Dedicated Playlist Folder Organization**: Tracks downloaded from curated or searched playlists are automatically routed into dedicated subdirectories (`Downloads/<PlaylistName>/`) and immediately appear as grouped playlists in your local library.
- **Instant (0ms) Playlist Caching & Background Revalidation**: Cached playlists load with zero delay. Background revalidation ensures freshest track listings without intrusive spinners.
- **Persistent Player State Across Restarts**: Infyn DL remembers your last played song, seek position, queue, shuffle, and repeat modes.
- **Recently Played Quick-Resume Strip**: A persistent, deduplicated history feed right above the library tabs to resume recent tracks with a single tap.
- **Curated Discover Catalog (v3)**: Explore 18 curated playlists across Ghazals, 90s/00s Bollywood, Desi Pop, Punjabi Hits, and Bhojpuri Classics.
- **Lock Screen & MediaSession Controls**: Full background playback integration with Android notification controls, album artwork, and lock screen media seekbars.

---

## ✨ Key Features

### 🎬 High-Resolution Video & Native Audio
- **Up to 4K / 1080p MP4 Video**: Automatic high-bitrate stream selection (`-S res,size,br`) with quality options (4K, 1080p, 720p, 480p, 360p).
- **Native M4A & Pristine MP3 Audio**: Native YouTube AAC streams for instant downloads or FFmpeg encoding with bitrate selection (320k, 192k, 128k).
- **YouTube Music, Playlists, Albums & Shorts**: Direct metadata extraction and download support for singles, full playlists, and Shorts.

### ⚡ Background Batch Downloads & Multi-Worker Pipeline
- **Parallel Worker Acceleration**: Multi-worker downloads for playlist queues with speed multiplier options (`1x`, `2x`, `3x`, `4x`, `5x`).
- **Selective Track Checkboxes**: Inspect playlist tracklists, preview durations, and select individual songs or batch download the whole collection.
- **Smart Duplicate Prevention**: Automatically inspects disk storage and history, skipping existing tracks in 0ms without re-downloading.

### 📱 Android-Native Storage & System Integration
- **Direct Public Downloads**: Files save cleanly to `Download/infyn-dl/` or custom subdirectories via Android Scoped Storage (`MediaStore.Downloads`).
- **Instant System Indexing**: Automatic `MediaScannerConnection` triggers ensure downloaded files appear immediately in Files by Google, Samsung My Files, VLC, and system media players.
- **Foreground Service & Notification**: Persistent notification bar displaying real-time download progress, track title, and cancel buttons.

### 🎵 In-App Player & Discovery Feed
- **Built-In Audio Player**: Mini-player and full-screen player with live progress scrubbing, volume controls, shuffle, and loop modes.
- **Persistent History Feed**: Quick resume of recently played music directly from the home library.
- **Offline-First Library**: Sort by title, artist, duration, or date added. Filter by Playlists, Tracks, or Liked Songs.

---

## 🏗️ Android Native Architecture

```
                      +-----------------------+
                      |   Infyn DL Flutter    |
                      | (UI & State Management|
                      +-----------+-----------+
                                  |
                                  | (Platform Channels)
                                  v
                      +-----------------------+
                      |  AndroidDownloaderSvc |
                      +-----------+-----------+
                                  | (MethodChannel & EventChannel)
                                  v
                      +-----------------------+
                      |  DownloaderPlugin.kt  |
                      +-----------+-----------+
                                  |
                      +-----------+-----------+
                      |  AndroidDownloadMgr   |
                      | (youtubedl-android &  |
                      |     ffmpeg-android)   |
                      +-----------+-----------+
                                  |
          +-----------------------+-----------------------+
          |                                               |
          v                                               v
+-----------------------+                       +-----------------------+
| DownloadForegroundSvc |                       |  MediaStorageHelper   |
| (Persistent Notifs &  |                       | (Scoped Storage &     |
|  Background Workers)  |                       |  MediaScanner Index)  |
+-----------------------+                       +-----------------------+
```

---

## 📁 Repository Structure

```
infyn-dl/
├── android/                         # Android native project & Kotlin platform channels
│   └── app/src/main/
│       ├── AndroidManifest.xml      # App permissions, foreground services & media session
│       └── kotlin/.../downloader/
│           ├── AndroidDownloadManager.kt    # Embedded yt-dlp & FFmpeg execution
│           ├── DownloadForegroundService.kt # Background notification & task management
│           ├── DownloaderPlugin.kt          # MethodChannel & EventChannel bridge
│           └── MediaStorageHelper.kt        # Scoped Storage & MediaStore publication
├── assets/                          # App logos & branding vectors
│   ├── logo.png                     # Primary application icon
│   └── logo-clear.png               # Transparent vector logo
├── catalog/                         # Curated playlists catalog
│   ├── catalog.schema.json          # Draft-07 JSON Schema validation
│   └── playlists.json               # Offline fallback catalog (v3)
├── lib/                             # Flutter cross-platform source code
│   ├── core/                        # Themes, colors & utilities
│   ├── features/
│   │   ├── downloader/              # Download engine, progress cards & batch queue
│   │   ├── home/                    # Shell navigation, curated playlists & recommendations
│   │   ├── library/                 # Local scanner, tracks, playlists & liked songs
│   │   ├── player/                  # Audio player, mini-player, queue & recently played
│   │   ├── search/                  # YouTube Music search, innertube & playlist detail
│   │   └── settings/                # Download directories, theme & audio quality
│   └── main.dart                    # Application entrypoint & service bootstrap
├── test/                            # Comprehensive unit & widget test suites
└── pubspec.yaml                     # Dependencies, assets & versioning
```

---

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK** (v3.19 or later): [Install Flutter](https://docs.flutter.dev/get-started/install)
2. **Android Studio** with:
   - Android SDK (API 26+)
   - Android SDK Build-Tools
   - Android NDK
3. **Physical Android Device or Emulator** (API 26+; API 29+ recommended for Scoped Storage testing)

---

### Running the App Locally

1. **Clone the repository**:
   ```bash
   git clone https://github.com/imvicky69/infyn-dl.git
   cd infyn-dl
   ```

2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

3. **Launch on your connected device or emulator**:
   ```bash
   flutter run -d android
   ```
   *(Note: Native `yt-dlp` and `FFmpeg` runtimes are automatically embedded via Gradle dependencies—no manual binary setups required!)*

---

## 📦 Building Android Release APKs

### Recommended: Split APKs per Architecture (~69 MB)
To build optimized packages for real phones:
```bash
flutter build apk --release --split-per-abi
```
Generated APK files:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (**~69 MB**, modern phones)
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (**~63 MB**, older 32-bit phones)

### Universal APK (All Architectures)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk` (~177 MB containing all native ABIs).

### Google Play App Bundle (AAB)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`.

---

## 🧪 Testing & Code Quality

Verify static analysis:
```bash
flutter analyze
```

Run automated test suite:
```bash
flutter test
```

---

## 🤝 Contributing

Contributions are warmly welcomed! Please review our [**Contributing Guide (CONTRIBUTING.md)**](CONTRIBUTING.md) for details on code style, issue templates, and pull request workflows.

---

## 🛡️ License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details.

---

## ⚖️ Legal Disclaimer

**Infyn DL** is intended for personal archiving of content that you own, content in the public domain, or content for which you have authorization from the copyright holder. The maintainers do not endorse copyright infringement and are not liable for any misuse of this software.
