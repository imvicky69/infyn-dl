# Contributing to Infyn DL

First off, thank you for considering contributing to **Infyn DL**! 🎉

Open source thrives because of people like you. Whether you're fixing a bug, adding support for new extractors, improving UI/UX, or polishing documentation, your help is warmly welcomed.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [How Can I Contribute?](#how-can-i-contribute)
   - [Reporting Bugs](#reporting-bugs)
   - [Suggesting Features](#suggesting-features)
   - [Pull Requests](#pull-requests)
3. [Development Workflow](#development-workflow)
   - [Prerequisites](#prerequisites)
   - [Setting Up the Project](#setting-up-the-project)
   - [Coding Standards & Style Guidelines](#coding-standards--style-guidelines)
   - [Testing & Quality Checks](#testing--quality-checks)
4. [Commit Message Conventions](#commit-message-conventions)
5. [Community & Questions](#community--questions)

---

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

---

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report, please check existing issues to ensure the problem hasn't already been reported. When creating a bug report, include:

- **A clear, descriptive title**.
- **Steps to reproduce** the bug.
- **Expected vs. actual behavior**.
- **Platform information** (e.g., Windows 11 64-bit, Android 14 API 34).
- **Relevant logs or screenshots** (you can find logs via `flutter logs` or Android logcat).

### Suggesting Features

Feature suggestions are tracked as GitHub issues. When proposing a new feature:

- Use a clear and descriptive title.
- Provide a step-by-step description of the proposed feature and why it would be beneficial.
- Include mockups, wireframes, or screenshots if applicable.

---

## Development Workflow

### Prerequisites

- **Flutter SDK**: 3.19.x or later (`flutter doctor` should report no issues).
- **Dart SDK**: 3.x (bundled with Flutter).
- **For Windows**: Visual Studio 2022 Community with *"Desktop development with C++"*.
- **For Android**: Android Studio with Android SDK (API 26+), Android NDK, and CMake.

---

### Setting Up the Project

1. **Fork the Repository** on GitHub.
2. **Clone your fork locally**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/infyn-dl.git
   cd infyn-dl
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/imvicky69/infyn-dl.git
   ```
4. **Install dependencies**:
   ```bash
   flutter pub get
   ```
5. **Download Windows Binaries** (if developing on Windows):
   ```powershell
   powershell -ExecutionPolicy Bypass -File tool\setup_binaries.ps1
   ```
6. **Create a topic branch**:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

---

### Coding Standards & Style Guidelines

- **Dart & Flutter**:
  - Follow the official [Effective Dart](https://dart.dev/guides/language/effective-dart) style guide.
  - Run `dart format .` before committing to format code automatically.
  - Keep widgets focused, small, and reusable.
  - Prefer immutable state models.
- **Theme & Colors**:
  - Never hardcode ad-hoc colors in widgets. Always use `AppColors` from `lib/core/theme/app_theme.dart`.
- **Platform Channels & Abstraction**:
  - Maintain the clean separation defined in `DownloaderService` (`lib/features/downloader/services/downloader_service.dart`).
  - Keep platform-specific code isolated in `WindowsDownloaderService` and `AndroidDownloaderService` / `AndroidDownloadManager.kt`.
- **Android Scoped Storage**:
  - Follow Android Scoped Storage best practices via `MediaStorageHelper.kt` to ensure public visibility and MediaStore indexing.

---

### Testing & Quality Checks

All contributions must pass automated tests and static analysis before being merged:

1. **Format Code**:
   ```bash
   dart format --output=none --set-exit-if-changed .
   ```
2. **Run Linter / Static Analysis**:
   ```bash
   flutter analyze
   ```
3. **Run Unit & Integration Tests**:
   ```bash
   flutter test
   ```

If you add new features or fix a bug, please write corresponding tests in the `test/` directory.

---

## Commit Message Conventions

We follow [Conventional Commits](https://www.conventionalcommits.org/) for clear, structured git history:

- `feat:` A new feature for the user
- `fix:` A bug fix
- `docs:` Documentation-only changes
- `style:` Formatting, missing semicolons, etc. (no code change)
- `refactor:` Code restructuring without changing functionality
- `test:` Adding or updating tests
- `chore:` Build scripts, package dependencies, CI updates

**Example:**
```bash
git commit -m "feat(playlist): add selective track checkboxes and parallel queue"
```

---

## Submitting a Pull Request (PR)

1. **Rebase your branch on upstream `main`**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```
2. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
3. **Open a Pull Request** against `imvicky69/infyn-dl:main`.
4. Fill out the PR description template explaining:
   - What changed.
   - Screenshots / GIFs (especially for UI changes).
   - How it was tested.

Thank you for helping build **Infyn DL**! 🚀
