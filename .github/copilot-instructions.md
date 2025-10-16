### Quick context

This is a small Flutter app (lib/main.dart) named "noteker". It is a single-package, local-first notes UI intended as a minimal reference app. Key libraries (see `pubspec.yaml`) include: `provider` for state, `google_fonts` for typography, `flutter_staggered_grid_view` for the Masonry layout, and `intl` for date formatting.

### Big-picture architecture (what to know fast)

- Single-module Flutter app. Entry point: `lib/main.dart`. There are no platform backend services in this repository — all data is in-memory in the `HomeScreen` state.
- Major responsibilities found in `lib/main.dart`:
  - Theme definitions and switching: `AppThemes` + `ThemeProvider` (ChangeNotifier + `Provider`).
  - UI: `NotesApp` (root), `HomeScreen` (list + CRUD hooks), `NoteCard`, `NoteEditorScreen`.
  - Data model: `Note` class (id, title, content, date).

Why it’s structured this way: the app is intentionally minimal and keeps model and UI co-located in `main.dart` for simplicity and demo purposes. Expect small, self-contained changes to be made in this file most of the time.

### Common developer workflows & commands

- Build & run (usual Flutter flows):
  - Debug on macOS/iOS simulator or Android: use `flutter run` in the repo root.
  - Build release artifacts: `flutter build apk` / `flutter build ios` as needed.
- Tests: no test files currently; use `flutter test` to run tests if/when added.
- Linting: project includes `analysis_options.yaml` and `flutter_lints` in `pubspec.yaml`. Run `flutter analyze` to check static issues.

### Project-specific conventions & patterns

- Single-file demo pattern: most app logic lives in `lib/main.dart`. When expanding features, follow the project's implied convention: keep small widgets and simple models in the same folder and prefer composition over deep architecture until the app grows.
- Theme switching: Themes are compared by reference in `ThemeProvider.setTheme`. When adding themes, add them to `AppThemes` and call `themeProvider.setTheme(...)` from UI.
- In-memory model: The `HomeScreen._notes` list is the single source of truth at runtime. Editing/creating returns a `Note` from `Navigator.pop(newNote)` and the caller merges it via `_addOrUpdateNote`. Keep that flow when refactoring: editor -> Navigator.pop(note) -> add/update in parent.
- IDs: note ids are strings generated with `Random().nextInt(100000).toString()`. When moving to persistent storage, maintain the string id contract.

### Integration points & external dependencies

- No external network or database integrations exist in this repo. The `pubspec.yaml` dependencies to be aware of:
  - `provider` (state)
  - `google_fonts` (typography)
  - `flutter_staggered_grid_view` (Masonry layout)
  - `intl` (date formatting)

When upgrading dependencies, run `flutter pub upgrade` then `flutter analyze` and smoke-test in an emulator.

### Patterns the AI should follow when editing code here

- Keep changes minimal and local: prefer editing `lib/main.dart` and adding new files under `lib/` rather than rearranging project-level configuration.
- Preserve the in-memory flow and Navigator usage: editor screens return a `Note` object via `Navigator.pop` — maintain that contract.
- If adding persistence, add a new abstraction (e.g., `lib/services/note_repo.dart`) and inject it into `HomeScreen` via constructor parameters or a Provider. Do not tightly couple platform code into widgets.
- Keep theming centralized in `AppThemes` and avoid scattering hard-coded colors.

### Small examples from the codebase

- Theme switch (existing): see `HomeScreen._showThemeDialog` which calls `themeProvider.setTheme(AppThemes.obsidianTheme)`.
- Editor -> Save contract: `NoteEditorScreen` creates a `Note` and calls `Navigator.of(context).pop(newNote)`. `HomeScreen` awaits the Navigator result and merges using `_addOrUpdateNote`.

### When to ask for clarification

- If a change requires persistent storage, ask whether to use local file storage, SQLite (`sqflite`), or a cloud backend.
- If adding navigation structure (routes), confirm whether to keep `MaterialPageRoute` pushes or move to named routes.

### Files to inspect first (fast links)

- `lib/main.dart` — entrypoint and most code.
- `pubspec.yaml` — dependencies and SDK constraints.
- `analysis_options.yaml` — lint rules.

If anything here is incorrect or you want extra details (storage, routing, tests), tell me which area to expand and I will update this file.
