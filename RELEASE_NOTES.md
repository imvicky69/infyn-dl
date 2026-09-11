# 🚀 Infyn DL v1.0.3 — Release Notes

Universal, local-first media downloader & offline music player for **Android**.

---

## 🌟 Highlights & What's New in v1.0.3

### 🔔 In-App GitHub Release Update Checker
- **Direct GitHub Releases Sync**: Infyn DL can now check GitHub for new versions directly from the app.
- **Settings Screen Notification Card**: Whenever a new release is published, a prominent update card appears with release notes and a 1-tap **"Download Update (APK)"** action button.
- **Configurable Startup Checks**: Added an **"Auto-Check for Updates"** toggle in **Settings** to check for updates asynchronously on app launch without interrupting your playback.

### ⚡ Optimized Split APKs (Down to 69 MB!)
- Release packages are now split per Android ABI architecture:
  - **ARM64-v8a**: **69.4 MB** (Optimized for 99% of modern phones — reduced by ~65% from 177 MB!).
  - **ARMv7a**: **62.7 MB** (Targeted for older 32-bit devices).
  - **x86_64**: **72.4 MB** (Targeted for Android emulators and Chromebooks).
  - **Universal**: **177.6 MB** (Compatible with all devices).

### 🎵 Persistent Audio Player & Playback State
- **Instant Resume**: Your last played song, playback timestamp, volume, loop mode, and queue are saved and restored immediately across app restarts.
- **0ms Feed & Catalog Caching**: Featured playlist tracks are cached locally, eliminating network lag and loading spinners when reopening playlists.

### 📁 Smart Playlist Routing & Library Sync
- **Dedicated Subfolders**: Songs downloaded from featured playlists are automatically routed to `Download/infyn-dl/<PlaylistName>/`.
- **Instant Grid Reflection**: Downloaded playlists immediately appear in the upper "Playlists" section with cover art and track counts.
- **Duplicate Prevention**: Intelligently skips re-downloading songs that already exist in your local library.

### 🎧 Background Audio Service
- Full Android MediaSession integration with persistent lock screen playback controls, notification controls, and Bluetooth earphone event handling.

---

## 📦 Download Packages

| Package | File Name | Size | Target Architecture |
| :--- | :--- | :--- | :--- |
| 📱 **ARM64 APK (Recommended)** | [`Infyn-DL-v1.0.3-android-arm64.apk`](https://github.com/imvicky69/infyn-dl/releases/download/v1.0.3/Infyn-DL-v1.0.3-android-arm64.apk) | **69.4 MB** | **Modern Smartphones & Tablets** (ARM64 / AArch64) |
| 🌐 **Universal APK** | [`Infyn-DL-v1.0.3-android-universal.apk`](https://github.com/imvicky69/infyn-dl/releases/download/v1.0.3/Infyn-DL-v1.0.3-android-universal.apk) | **177.6 MB** | **All Android Devices** (Universal fallback) |
| 📱 **ARMv7 APK** | [`Infyn-DL-v1.0.3-android-armeabi-v7a.apk`](https://github.com/imvicky69/infyn-dl/releases/download/v1.0.3/Infyn-DL-v1.0.3-android-armeabi-v7a.apk) | **62.7 MB** | **Legacy 32-bit Android Devices** |
| 💻 **x86_64 APK** | [`Infyn-DL-v1.0.3-android-x86_64.apk`](https://github.com/imvicky69/infyn-dl/releases/download/v1.0.3/Infyn-DL-v1.0.3-android-x86_64.apk) | **72.4 MB** | **Android Emulators & Chromebooks** |

---

## 🔒 SHA-256 Checksums

Verify package authenticity using SHA-256:

```text
fce3ecb17b5d4ce16dca23e5ec716fe4036fcc89ba9326b0fe475f7a419a544b  Infyn-DL-v1.0.3-android-arm64.apk
1c2d0a8dc614ddda57e079cf15d7ec4eb9d9fff611b1ebf33e5b22915dcea61a  Infyn-DL-v1.0.3-android-armeabi-v7a.apk
88ef06d02b8feb550e3c00c43f28e264246d42d23df63de4dcf6a766b22e367d  Infyn-DL-v1.0.3-android-x86_64.apk
d7b6e1ede53af3893d34f8538da74e7acb19a6eabc5fd3cf5ca62dd0a4b6c135  Infyn-DL-v1.0.3-android-universal.apk
```

---

## 📲 Android Installation Guide

1. Download **`Infyn-DL-v1.0.3-android-arm64.apk`** (recommended for modern Android devices).
2. Tap the downloaded file in your browser or file manager.
3. If prompted with *"For your security, your phone is not allowed to install unknown apps from this source"*, tap **Settings** and enable **"Allow from this source"**.
4. Tap **Install** and launch **Infyn DL**.
5. Grant notification and storage permissions when prompted to enable background downloading and lock screen music controls.

---

## 🛠️ Verification & Building from Source

```bash
git clone https://github.com/imvicky69/infyn-dl.git
cd infyn-dl
flutter pub get
flutter test
flutter build apk --release --split-per-abi
```

---

**Full Changelog**: https://github.com/imvicky69/infyn-dl/commits/v1.0.3
