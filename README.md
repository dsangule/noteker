# Noteker 📝

Noteker is a modern, local-first note-taking app built with Flutter. It blends a clean UX with powerful features like optional Google Drive sync, gamification, and advanced Markdown with LaTeX math rendering. Runs on Android, iOS, Web, macOS, Windows, and Linux.

## ✨ Features

- **📱 Cross‑platform**: Android, iOS, Web, Windows, macOS, Linux
- **☁️ Drive sync (optional)**: Google Drive backup/sync with folder selection and background uploads
- **🎮 Gamification**: Streaks, level progression, achievement toaster
- **📝 Markdown+Math**: Markdown preview with LaTeX (`$...$`, `$$...$$`), code blocks, task lists
- **🎨 Material 3**: Dynamic color (Android 12+/macOS), light/dark themes, font scaling
- **🔍 Search**: Real‑time filtering by title/content
- **📐 Responsive UI**: Inline editor on wide screens, dedicated editor on mobile
- **🌍 I18n**: App localizations with ARB files
- **⚡ Offline‑first**: Notes stored locally; sync when available
- **📤 Sharing**: Share notes via system share sheet
- **🎯 Onboarding**: Interactive walkthrough and demo content

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>= 3.9.2)
- Dart SDK
- Android Studio or VS Code with Flutter extensions
- Google Cloud Console project (only if enabling Drive sync)

### Installation

1. **Clone**
   ```bash
   git clone https://github.com/yourusername/noteker.git
   cd noteker
   ```

2. **Install deps**
   ```bash
   flutter pub get
   ```

3. **Run**
   ```bash
   flutter run
   ```

4. **(Optional) Enable Google Drive sync**
   - Create a project in the [Google Cloud Console](https://console.cloud.google.com/)
   - Enable the Google Drive API
   - Create OAuth 2.0 credentials (Web and/or iOS/Android as applicable)
   - Configure the client IDs via your `DriveService` implementation
   - On web, the app can set a client ID at runtime (see `DriveService.setWebClientId` usage)

## 🏗️ Architecture

The app uses Provider for state management and a service/repository pattern for data persistence and sync.

```
lib/
├── main.dart                        # App entry point, error boundaries, provider setup
├── models/
│   └── note.dart                    # Note data model
├── providers/
│   ├── theme_provider.dart          # Theme/dynamic color/font scaling
│   ├── gamification_provider.dart   # Streaks, levels, achievements
│   ├── notes_provider.dart          # Re-export of screens/notes_provider.dart
│   └── notes_provider_refactored.dart # Simplified provider (experimental)
├── screens/
│   ├── home_screen.dart             # Main UI with notes, editor, and Drive sync
│   ├── notes_provider.dart          # Notes state management and Drive operations
│   └── settings_screen.dart         # App settings and preferences
├── services/
│   ├── drive_service.dart           # Google Drive integration (upload/download)
│   ├── drive_file_service.dart      # Alternative Drive service (unused)
│   └── note_repository.dart         # Local persistence (SharedPreferences)
├── widgets/
│   ├── note_editor.dart             # Note editing interface
│   ├── note_markdown_view.dart      # Markdown + math preview
│   ├── math_element_builder.dart    # Markdown math syntaxes/builders
│   ├── katex_view_mobile.dart       # Native math via flutter_math_fork
│   ├── katex_view_web.dart          # KaTeX on web (platform view)
│   ├── code_block_builder.dart      # Fenced code rendering + copy
│   ├── task_list_builder.dart       # Task lists [ ] / [x]
│   ├── editor_header.dart           # Editor toolbar (preview/math/share)
│   ├── note_card.dart               # Note preview cards
│   ├── sidebar_notes_list.dart      # Notes sidebar for wide screens
│   └── achievement_toaster.dart     # Achievement overlay
├── utils/
│   ├── markdown_helpers.dart        # Line breaks, math pre-processing helpers
│   ├── logger.dart, error_handler.dart, performance_monitor.dart
│   └── dev_utils.dart
└── l10n/                            # ARB files and localizations shim
```

### State Management

- **Provider** for app‑wide state (`ThemeProvider`, `GamificationProvider`)
- **HomeScreen** manages notes list, selection, and UI state locally
- **NotesProvider** (in screens/) handles notes CRUD and Drive sync operations

### Data Layer

- **Local**: `SharedPreferences` via `SharedPrefsNoteRepository`
- **Cloud**: `DriveService` for Google Drive (sign‑in, folder selection, CRUD)
- **Mapping**: Local note IDs ↔ Drive file IDs persisted in prefs
- **Sync**: Bidirectional sync with conflict resolution (Drive wins on conflicts)

### Markdown + Math Rendering

- Uses `flutter_markdown` with custom syntaxes/builders in `math_element_builder.dart`
- Inline math: `$ ... $`
- Block math: lines starting/ending with `$$`
- Rendering:
  - Mobile/desktop: `flutter_math_fork` (`katex_view_mobile.dart`)
  - Web: KaTeX via CDN and platform view (`katex_view_web.dart`)
- Line breaks: `preserveLineBreaks()` converts single newlines to hard breaks except inside fenced code

### UX Details

- Wide screens: split view with sidebar and inline editor/preview
- Narrow screens: grid of notes; tap to open full editor
- **Keyboard shortcuts**: Cmd/Ctrl + H for walkthrough
- **Sharing**: Share button in editor header for system share sheet
- **Onboarding**: Auto-shows demo note and walkthrough on first launch
- **Menu options**: Access demo and walkthrough via 3-dot menu
- Achievement toaster overlay at bottom

## 🛠️ Development

### Code Quality

- Lints configured in `analysis_options.yaml` (strict casts/inference, many style rules)
- Run analyzer:
  ```bash
  flutter analyze
  ```
- Common patterns used:
  - Guard `BuildContext` after async with `if (!context.mounted) return;`
  - Use `Future.microtask` for post‑build state updates

### Testing

- Unit tests live in `test/`
- Current tests cover markdown helpers:
  - `preserveLineBreaks()`
  - `processMath()`

Commands:
```bash
# Run unit tests
flutter test -r compact

# Coverage report
flutter test --coverage
```

### Building

```bash
# Android
flutter build apk --release

# iOS (requires Xcode setup)
flutter build ios --release

# Web
flutter build web --release

# Desktop
flutter build windows --release  # Windows
flutter build macos --release    # macOS
flutter build linux --release    # Linux
```

### Linting & Formatting

```bash
flutter analyze
dart format .
```

### Drive Sync Setup (Detailed)

1. Create a Google Cloud project and enable the Drive API
2. Create OAuth 2.0 credentials (Web client for web; iOS/Android for mobile)
3. Configure authorized redirect URIs for web
4. Provide client IDs to `DriveService`
   - On web, `DriveService.setWebClientId()` may be called at runtime before sign‑in
5. In the app, tap the cloud icon to sign in and **choose a Drive folder** for sync

## 📱 Screenshots

Add screenshots/gifs demonstrating:
- Home split view (editor vs preview)
- Mobile editor
- Math rendering (inline + block)
- Drive sync status

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Flutter/Dart style guide
- Write/extend tests for new features
- Keep `analysis_options.yaml` green
- Use conventional commits

## 📄 License

MIT — see [LICENSE](LICENSE)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Packages: `flutter_markdown`, `flutter_math_fork`, `provider`, `shared_preferences`, `share_plus`
- Contributors and beta testers

## 🔐 Privacy & Security

- Notes are stored locally (SharedPreferences) and optionally synced to a private folder in your Google Drive
- Google sign‑in tokens are handled by platform SDKs; no credentials are stored in the repo
- Do not commit API keys or client IDs

## ❓ FAQ

- **Math isn't rendering on web?** Ensure KaTeX CDN is reachable. Reload the page; the script loads asynchronously.
- **Context used after async warnings?** The app guards with `context.mounted`. Follow the pattern in `home_screen.dart`.
- **Why are single newlines kept?** `preserveLineBreaks()` converts them to hard breaks for readable paragraphs.
- **Can I disable math?** Toggle the ƒ button in the editor header. Preference is saved in `SharedPreferences`.
- **How do I choose a Drive folder?** Tap the cloud icon and select from your existing folders or create a new "Noteker" folder.
- **How do I access the walkthrough?** Use Cmd/Ctrl + H or the 3-dot menu → "Show Walkthrough".
- **Can I share notes?** Use the share button in the editor header to share via system share sheet.

## 📞 Support

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/yourusername/noteker/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/yourusername/noteker/discussions)
- 📧 **Contact**: your.email@example.com

---

Made with ❤️ using Flutter
