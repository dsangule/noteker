# Changelog

All notable changes to Noteker will be documented in this file.

## [Unreleased]

### Features

- **Google Drive Sync**: Complete Google Drive integration with folder selection
  - Choose any existing Drive folder or create new "Noteker" folder
  - Bidirectional sync with conflict resolution
  - Background uploads and periodic sync
- **Font Scaling**: Dynamic font size adjustment with safe fallbacks
- **Sharing**: Share notes via system share sheet
- **Onboarding**: Interactive walkthrough and demo content
- **Gamification**: Streaks, levels, and achievement system
- **Advanced Markdown**: Math rendering (LaTeX), code blocks, task lists
- **Material 3**: Dynamic colors, themes, responsive design

### Technical Improvements

- **Cross-platform**: Android, iOS, Web, macOS, Windows, Linux
- **State Management**: Provider pattern with local state management
- **Error Handling**: Comprehensive error boundaries and logging
- **Performance**: Optimized rendering and memory management
- **Code Quality**: Strict linting and clean architecture

## Project Structure

```
lib/
├── main.dart                        # App entry point and providers
├── models/note.dart                 # Note data model
├── providers/
│   ├── theme_provider.dart          # Theme, colors, font scaling
│   ├── gamification_provider.dart   # Streaks and achievements
│   └── notes_provider.dart          # Notes management (re-export)
├── screens/
│   ├── home_screen.dart             # Main UI with notes and editor
│   ├── notes_provider.dart          # Notes state and Drive sync
│   └── settings_screen.dart         # Settings and preferences
├── services/
│   ├── drive_service.dart           # Google Drive operations
│   └── note_repository.dart         # Local storage
├── widgets/                         # Reusable UI components
└── utils/                           # Helpers and utilities
```

## Development Status

- ✅ **Core Functionality**: Notes CRUD, editing, search
- ✅ **Drive Sync**: Folder selection, bidirectional sync
- ✅ **UI/UX**: Responsive design, Material 3, accessibility
- ✅ **Performance**: Optimized for all platforms
- ✅ **Testing**: Unit tests for core utilities
- ✅ **Documentation**: Complete setup and usage guides

## Getting Started

See [README.md](README.md) for installation and setup instructions.
