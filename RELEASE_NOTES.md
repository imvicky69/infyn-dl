# 🚀 Infyn DL v1.0.4 — Release Notes

Universal, local-first media downloader & offline music player for **Android**.

---

## 🌟 Highlights & What's New in v1.0.4

### 🎶 Expanded Curated Playlists Catalog (v4)
- **17 New Curated Playlists**: Added 17 high-energy and soulful playlists across **Punjabi** (*Punjabi Song Playlist 2026*, *Punjabi Hits Collection*), **Bhojpuri** (*Bhojpuri Essentials*, *Bhojpuri Hits 2022/2023*, *Presenting Pawan Singh*, *Bhojpuri Energy Boosters*, *10s Bhojpuri*), **Hindi Romance & Indie** (*10s Bollywood Romance Hits*, *Slow Songs*, *Bollywood Dance Hitlist*, *Weakness*, *Presenting KK*, *Presenting Pritam*), **Desi Pop** (*I-Pop Hits!*, *Xweet Archives*), and **Devotional** (*Chhath Puja Songs*).
- **Permanent High-Resolution Artwork**: Replaced expired temporary image URLs with permanent, high-definition `yt3.googleusercontent.com` and `img.youtube.com` artwork.
- **Automatic Cache Invalidation**: Catalog version bumped to `v4` to automatically invalidate older device cache and deliver the new playlist catalog immediately.

### 🔍 Unified Search & Downloader Workflow
- **All-in-One Search Hub**: Direct YouTube and YouTube Music link pasting and playlist download workflow are now seamlessly integrated into the Search screen.
- **Streamlined Navigation**: Polished bottom navigation with 4 focused destinations: **Music**, **Search**, **Library**, and **Settings**.
- **Accurate Playlist Metadata on Link Paste**: Properly resolves and displays YouTube playlist title and tracks, ensuring songs are saved into cleanly named folders.
- **Clean Reset**: Smoothly resets search state when navigating back from external link searches.

### 🤫 Silent Batch Download Notifications
- Batch downloading now uses a silent foreground notification channel while downloading songs. Alert sounds and vibrations only trigger once the entire batch has successfully completed.

### 📥 Fetch All Playlist Songs in Downloaded Folders
- Inside downloaded playlist folders, a **"Fetch All Playlist Songs"** action is now available to retrieve the full online YouTube Music track list.
- Easily see which tracks are already **Saved** locally and download remaining songs individually or via **"Download All Missing"** directly into the same folder.

### ⏰ Smart Sleep Timer (Now Playing Three-Dots Menu)
- **Fall Asleep to Music**: Easily set a sleep timer directly from the **three-dots menu (`...`)** on the Now Playing player screen.
- **Flexible Modes & Presets**: Choose quick presets (5, 10, 15, 30, 45, 60 minutes), dial a custom time, or enable **"End of this song"** mode to finish the current track before stopping.
- **Gentle Audio Fade-Out**: Smoothly lowers the volume over the final seconds so playback ceases peacefully without waking you up.
- **Live Countdown Status**: Displays remaining sleep time in the menu and a live indicator chip while active.

### ❤️ Liked Songs & Dark Mode Polish
- **1-Tap Unlike**: Easily remove songs from Liked Songs with immediate undo snackbar feedback.
- **Dynamic White Logo**: Automatically switches to the crisp white branding logo in dark mode.
- **Improved Contrast**: Fixed button pill text visibility in dark mode across the player and library.
- **Real App Version**: Settings screen now displays the actual installed application version and release status.

---

## 📦 Download Packages

| Package | File Name | Size | Target Architecture |
| :--- | :--- | :--- | :--- |
| 📱 **ARM64 APK (Recommended)** | [`Infyn-DL-v1.0.4-android-arm64.apk`](https://github.com/imvicky69/infyn-dl/releases/download/v1.0.4/Infyn-DL-v1.0.4-android-arm64.apk) | **70.0 MB** | **Modern Smartphones & Tablets** (ARM64 / AArch64) |
| 🌐 **Universal APK** | [`Infyn-DL-v1.0.4-android-universal.apk`](https://github.com/imvicky69/infyn-dl/releases/download/v1.0.4/Infyn-DL-v1.0.4-android-universal.apk) | **178.3 MB** | **All Android Devices** (Universal fallback) |
| 📱 **ARMv7 APK** | [`Infyn-DL-v1.0.4-android-armeabi-v7a.apk`](https://github.com/imvicky69/infyn-dl/releases/download/v1.0.4/Infyn-DL-v1.0.4-android-armeabi-v7a.apk) | **63.3 MB** | **Legacy 32-bit Android Devices** |
| 💻 **x86_64 APK** | [`Infyn-DL-v1.0.4-android-x86_64.apk`](https://github.com/imvicky69/infyn-dl/releases/download/v1.0.4/Infyn-DL-v1.0.4-android-x86_64.apk) | **73.0 MB** | **Android Emulators & Chromebooks** |

---

## 🔒 SHA-256 Checksums

Verify package authenticity using SHA-256:

```text
46d41c06d8a06fe67519f8390db104a0d31073057cfcf9bb93d1dceec4edf894  Infyn-DL-v1.0.4-android-arm64.apk
ca760c552bce959a6c2c3a4105435d2d9d6b1542f89b81a74b40e95d25ce35df  Infyn-DL-v1.0.4-android-armeabi-v7a.apk
818ead33070e354210e3b6ee2bf5f5ee3995f6461cd4df1aaf7a90d0258b642a  Infyn-DL-v1.0.4-android-x86_64.apk
5ad244eaea69452eec7ce215369dfdb102f630fbc93550d5799db6940ff26e75  Infyn-DL-v1.0.4-android-universal.apk
```

---

## 📲 Android Installation Guide

1. Download **`Infyn-DL-v1.0.4-android-arm64.apk`** (recommended for modern Android devices).
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

**Full Changelog**: https://github.com/imvicky69/infyn-dl/commits/v1.0.4
