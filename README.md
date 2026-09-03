<div align="center">
  <img src="assets/logo.png" alt="Infyn DL Logo" width="130" />
  <h1>Infyn DL</h1>
  <p><strong>Universal, Local-First Media & Music Downloader for Windows & Android</strong></p>

  <p>
    <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter"></a>
    <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart"></a>
    <a href="https://github.com/yt-dlp/yt-dlp"><img src="https://img.shields.io/badge/Engine-yt--dlp%20Native-FF0000?logo=youtube&logoColor=white" alt="yt-dlp"></a>
    <a href="https://ffmpeg.org"><img src="https://img.shields.io/badge/Audio-FFmpeg%20320k-007808?logo=ffmpeg&logoColor=white" alt="FFmpeg"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-black.svg" alt="License: MIT"></a>
    <img src="https://img.shields.io/badge/Platforms-Windows%20%7C%20Android-4B0082" alt="Platforms">
  </p>
</div>

---

## 🌟 Overview

**Infyn DL** is a high-performance, privacy-respecting media downloader built with Flutter. It executes **`yt-dlp` and `FFmpeg` locally on your device** without routing traffic through third-party servers or APIs.

Whether you're grabbing a 4K 60fps video, extracting 320kbps pristine audio from YouTube Music, or batch-downloading a 200+ track playlist in parallel, Infyn DL provides a clean, responsive, and distraction-free experience across Windows desktop and Android mobile devices.

---

## ✨ Key Features

### 🎬 High-Resolution Video & Audio
- **Up to 4K / 1080p MP4 Video**: Automatic high-bitrate stream selection (`-S res,size,br`) with custom quality presets (4K, 1080p, 720p, 480p, 360p).
- **320kbps Pristine Audio Extraction**: Direct MP3 encoding powered by FFmpeg with bitrate selection (320k, 192k, 128k).
- **YouTube Music & Shorts Support**: Seamless extraction of full tracks, playlists, albums, and Shorts.

### ⚡ Parallel Playlist Batching & Selective Downloads
- **Multi-Worker Acceleration**: Download multiple playlist tracks simultaneously with user-configurable parallel worker speeds (`1x`, `2x`, `3x`, `4x`, `5x`).
- **Multi-Threaded Fragment Chunking (`-N 4`)**: Multi-connection stream chunking per file to bypass bandwidth throttling.
- **Selective Item Checkboxes**: Preview entire playlists with track lengths and toggle items individually or use **Select All / Deselect All**.
- **Smart Duplicate Detection**: Automatically checks existing files on disk and in history, instantly skipping duplicates in 0ms without re-downloading.

### 📱 Android-Native Storage & Scoped Storage
- **Direct Public Downloads Directory**: Automatically saves files to `Download/infyn-dl/` (or custom folders) using Android Scoped Storage `MediaStore.Downloads`.
- **Instant System Indexing**: Runs `MediaScannerConnection` on completion so downloads appear immediately in Files by Google, Samsung My Files, VLC, and system media players without requiring a device restart.
- **Background Foreground Service**: Persistent notifications with live progress bar and cancel actions.

### 📚 Downloads Library & Cache
- **Local History**: Built-in library screen categorized by `All`, `Playlists`, `Videos`, and `Audio`.
- **Instant Playback**: Tap to open and play downloaded videos and music in your default media player.
- **Deduplication Guarantee**: Keeps a clean cache with options to delete history entries and physical files from disk.

### 🎨 Modern Minimalist Design
- **Black & White Aesthetics**: Clean, monochrome visual design system with zero visual clutter.
- **Single-Line Features Capsule**: Space-saving inline stat pills for capabilities.
- **Responsive Layout**: Adapts dynamically from mobile phones to high-resolution desktop monitors.

---

## 🏗️ Architecture

```
                                  +-----------------------+
                                  |    Infyn DL Flutter   |
                                  | (UI & State Management|
                                  +-----------+-----------+
                                              |
                     +------------------------+------------------------+
                     |                                                 |
                     v (Desktop)                                       v (Mobile)
          +-----------------------+                         +-----------------------+
          | WindowsDownloaderSvc  |                         | AndroidDownloaderSvc  |
          +-----------+-----------+                         +-----------+-----------+
                      |                                                 | (MethodChannel & EventChannel)
                      v                                                 v
          +-----------------------+                         +-----------------------+
          |  Local Process Runner |                         |  DownloaderPlugin.kt  |
          |  (yt-dlp.exe + FFmpeg)|                         +-----------+-----------+
          +-----------------------+                                     |
                                                            +-----------+-----------+
                                                            |  AndroidDownloadMgr   |
                                                            | (YoutubeDL-Android &  |
                                                            |     FFmpeg-Kit)       |
                                                            +-----------+-----------+
                                                                        |
                                                            +-----------+-----------+
                                                            |  MediaStorageHelper   |
                                                            | (Scoped Storage &     |
                                                            |  MediaScanner)        |
                                                            +-----------------------+
```

---

## 📁 Repository Structure

```
media_downloader/
├── android/                         # Android native project & Kotlin platform channels
│   └── app/src/main/kotlin/.../downloader/
│       ├── AndroidDownloadManager.kt  # Local YoutubeDL & FFmpeg execution engine
│       ├── DownloadForegroundService.kt # Background notification service
│       ├── DownloaderPlugin.kt       # MethodChannel & EventChannel bindings
│       └── MediaStorageHelper.kt     # Scoped Storage & MediaStore publication
├── assets/                          # App branding & infinity icons
│   ├── logo.png                     # Official Infyn DL icon
│   └── logo-clear.png               # Transparent vector logo
├── lib/                             # Core Flutter application source
│   ├── core/
│   │   ├── theme/app_theme.dart     # Design system & dark/light tokens
│   │   └── utils/                   # Path resolution & native file openers
│   ├── features/
│   │   ├── downloader/              # Downloader feature (models, screens, services, widgets)
│   │   ├── home/                    # Main shell navigation
│   │   ├── library/                 # History, filters & playback
│   │   └── settings/                # Storage paths, parallel speed & preferences
│   └── main.dart                    # App initialization
├── test/                            # Unit and integration test suites
│   ├── widget_test.dart             # UI widget tests
│   └── windows_downloader_integration_test.dart # Local process integration tests
├── tool/
│   └── setup_binaries.ps1           # Windows binary fetcher for yt-dlp & FFmpeg
├── windows/                         # Windows C++ runner & executable packaging
└── pubspec.yaml                     # Dependencies & assets configuration
```

---

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK** (v3.19 or later): [Install Flutter](https://docs.flutter.dev/get-started/install)
2. **Git**: [Install Git](https://git-scm.com/)

---

### Windows Development Setup

1. **Install Visual Studio Community** with the *"Desktop development with C++"* workload.
2. **Clone the repository**:
   ```bash
   git clone https://github.com/imvicky69/infyn-dl.git
   cd infyn-dl
   ```
3. **Download Windows Binaries (`yt-dlp.exe` and `ffmpeg.exe`)**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tool\setup_binaries.ps1
   ```
4. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```
5. **Run the Windows application**:
   ```bash
   flutter run -d windows
   ```

---

### Android Development Setup

1. **Install Android Studio** and set up an Android Virtual Device (AVD) running API 26 or higher (API 29+ recommended for Scoped Storage testing).
2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```
3. **Launch the app on your emulator or physical device**:
   ```bash
   flutter run -d android
   ```
   *(Note: The Android build automatically bundles `youtubedl-android` and `ffmpeg-kit` so no manual binary downloads are required!)*

---

## 🧪 Testing & Code Quality

Run static code analysis:
```bash
flutter analyze
```

Run the full automated test suite:
```bash
flutter test
```

---

## 🤝 Contributing

Contributions are what make the open-source community an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**!

Please review our [**Contributing Guide (CONTRIBUTING.md)**](CONTRIBUTING.md) for details on code style, branch naming conventions, submitting issues, and opening pull requests.

---

## 🛡️ License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.

---

## ⚖️ Legal Disclaimer

**Infyn DL** is intended for downloading content that you own, content in the public domain, or content for which you have express permission from the copyright holder. The developers of Infyn DL do not endorse copyright infringement and are not liable for any misuse of this software.
