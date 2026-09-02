<div align="center">
  <img src="assets/logo-clear.png" alt="infyn-yt Logo" width="120" />
  <h1>infyn-yt</h1>
  <p><strong>A modern, minimalist, high-speed YouTube media downloader for Windows & Android.</strong></p>
</div>

---

## Features

- **Pristine Video Downloads**: Up to 4K / 1080p MP4 with automatic high-bitrate stream selection (`-S res,size,br`).
- **High-Fidelity Audio Extraction**: Extract crisp MP3 audio (320kbps, 192kbps, 128kbps) powered by FFmpeg.
- **Real-Time Pre-Fetch**: Automatically analyzes YouTube links to fetch video thumbnails, titles, duration, and exact file sizes for every format before you download.
- **Modern Monochrome UI**: Clean, Scandinavian/Apple-inspired black & white design system without clutter.
- **Adaptive Layout**: Fully responsive across Windows desktop and Android mobile displays.
- **Built-in JS Challenge Solving**: Bundled QuickJS / Node.js support solves YouTube's `[jsc]` challenge, unlocking full-resolution streams.

---

## Project Structure

```
media_downloader/
├── assets/
│   └── logo-clear.png               # Official app logo
├── lib/
│   ├── core/
│   │   ├── theme/app_theme.dart     # Modern monochrome design tokens
│   │   └── utils/
│   │       └── process_path_resolver.dart # Resolves yt-dlp, ffmpeg, and runtimes
│   ├── features/downloader/
│   │   ├── models/                  # DownloadFormat, VideoMetadata, MediaQuality
│   │   ├── screens/
│   │   │   └── downloader_screen.dart # Main responsive downloader UI
│   │   ├── services/
│   │   │   ├── downloader_service.dart # Platform abstraction
│   │   │   └── windows_downloader_service.dart # Windows yt-dlp & ffmpeg backend
│   │   └── widgets/                 # Modular UI components
│   └── main.dart                    # Application entry point
├── test/
│   ├── widget_test.dart             # UI widget tests (6 tests)
│   └── windows_downloader_integration_test.dart # Backend integration tests (3 tests)
├── tool/
│   └── setup_binaries.ps1           # Script to download yt-dlp & FFmpeg on Windows
└── windows/                         # Windows desktop runner & CMake bundling
```

---

## Windows Setup for Developers

1. **Install Flutter & Visual Studio (Desktop development with C++)**.
2. **Download Windows Dependencies**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tool\setup_binaries.ps1
   ```
3. **Run the App**:
   ```bash
   flutter run -d windows
   ```

---

## Testing & Quality Assurance

Run all automated unit and integration tests:
```bash
flutter test
```

Run static analysis:
```bash
flutter analyze
```

---

## License
MIT License
