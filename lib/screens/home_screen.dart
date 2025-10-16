import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:noteker/l10n/app_localizations_shim.dart' show AppLocalizations;

import 'package:noteker/models/note.dart';
import 'package:noteker/services/drive_service.dart';
import 'package:noteker/services/note_repository.dart';
import 'package:noteker/widgets/note_card.dart';
import 'package:noteker/widgets/note_editor.dart';
import 'package:noteker/screens/settings_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:noteker/providers/gamification_provider.dart';
import 'package:noteker/utils/markdown_helpers.dart';
import 'package:noteker/widgets/note_markdown_view.dart';
import 'package:noteker/widgets/achievement_toaster.dart';
import 'package:noteker/widgets/sidebar_notes_list.dart';
import 'package:noteker/widgets/editor_header.dart';

// Private intent used for the Show Walkthrough keyboard shortcut.
class _ShowWalkthroughIntent extends Intent {
  const _ShowWalkthroughIntent();
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Note> _notes = [];
  final NoteRepository _noteRepo = SharedPrefsNoteRepository();
  String _searchQuery = '';
  bool _sortByDateDesc = true;

  void _addOrUpdateNote(Note? note) {
    if (note == null) return;
    setState(() {
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note;
      } else {
        _notes.insert(0, note);
      }
      _notes.sort((a, b) => b.date.compareTo(a.date)); // Keep notes sorted
    });
  // persist notes
  unawaited(_noteRepo.saveNotes(_notes));
    // Mark note as dirty and (re)start 10s inactivity timer for upload.
    // Upload is started in the background so the UI doesn't lock while syncing.
    _dirtyNotes.add(note.id);
    _inactivityTimers[note.id]?.cancel();
    _inactivityTimers[note.id] = Timer(const Duration(seconds: 10), () {
      // fire-and-forget background upload; _uploadNote updates status and calls setState.
      _uploadNote(note);
    });
  }

  // Upload or update a single note to Drive. Called after inactivity or on selection change.
  Future<void> _uploadNote(Note note) async {
    if (!_driveService.isSignedIn || _driveFolderId == null) return;
    // If an upload for this note is already in flight, mark dirty and skip
    if (_uploadsInFlight.contains(note.id)) {
      _dirtyNotes.add(note.id);
      return;
    }
    _uploadsInFlight.add(note.id);
    _syncStatus[note.id] = SyncStatus.syncing;
    setState(() {});
    try {
      var driveId = _localToDriveId[note.id];
      if (driveId != null) {
        final updated = await _driveService.updateMarkdownFile(
          driveId,
          note.title,
          note.content,
        );
        driveId = updated.id;
        _lastSync[note.id] = DateTime.now();
        _syncLogs
            .putIfAbsent(note.id, () => [])
            .add('Updated ${updated.id} at ${_lastSync[note.id]}');
        _syncStatus[note.id] = SyncStatus.synced;
      } else {
        final files = await _driveService.listMarkdownFiles(_driveFolderId!);
        final matches = files
            .where((f) => (f.name ?? '').replaceAll('.md', '') == note.title)
            .toList();
        if (matches.isNotEmpty) {
          final match = matches.first;
          final updated = await _driveService.updateMarkdownFile(
            match.id!,
            note.title,
            note.content,
          );
          driveId = updated.id;
          _lastSync[note.id] = DateTime.now();
          _syncLogs
              .putIfAbsent(note.id, () => [])
              .add('Updated matched ${updated.id} at ${_lastSync[note.id]}');
          _syncStatus[note.id] = SyncStatus.synced;
        } else {
          final created = await _driveService.createMarkdownFile(
            _driveFolderId!,
            note.title,
            note.content,
          );
          driveId = created.id!;
          _lastSync[note.id] = DateTime.now();
          _syncLogs
              .putIfAbsent(note.id, () => [])
              .add('Created ${created.id} at ${_lastSync[note.id]}');
          _syncStatus[note.id] = SyncStatus.synced;
        }
        if (driveId != null && driveId.isNotEmpty) {
          _localToDriveId[note.id] = driveId;
          await _saveLocalDriveMap();
        }
      }
      _dirtyNotes.remove(note.id);
      _inactivityTimers[note.id]?.cancel();
      setState(() {});
      // upload complete - remove from in-flight and if dirty again requeue
      _uploadsInFlight.remove(note.id);
      if (_dirtyNotes.contains(note.id)) {
        // schedule an immediate re-upload in background
        Future.microtask(() => _uploadNote(note));
      }
    } catch (e) {
      _syncStatus[note.id] = SyncStatus.error;
      _syncLogs.putIfAbsent(note.id, () => []).add('Upload error: $e');
      debugPrint('[Drive] upload error: $e');
      setState(() {});
      _uploadsInFlight.remove(note.id);
    }
  }

  String? _selectedNoteId;
  final DriveService _driveService = DriveService();
  String? _driveFolderId;
  // Map local note id -> drive file id for syncing/uploads
  final Map<String, String> _localToDriveId = {};
  static const _kLocalDriveMapKey = 'local_drive_map_v1';

  // Debounce timer for uploads
  Timer? _debounceUploadTimer;

  // Periodic sync timer
  Timer? _periodicSyncTimer;
  // For web, Timer.periodic can cause debug proxy issues in some setups. Use a
  // web-safe async loop instead when running on web.
  bool _periodicSyncLoopActive = false;
  // Preview toggle for the inline editor
  bool _isPreview = false;

  // Sync status per note
  final Map<String, SyncStatus> _syncStatus = {};
  // Per-note last sync timestamp and logs
  final Map<String, DateTime> _lastSync = {};
  final Map<String, List<String>> _syncLogs = {};
  // Per-note inactivity timers (for 10s upload) and dirty tracking
  final Map<String, Timer> _inactivityTimers = {};
  final Set<String> _dirtyNotes = {};
  // Uploads currently in flight (per-note guard)
  final Set<String> _uploadsInFlight = {};
  // Split editor flag (side-by-side editor + preview)
  bool _isSplit = false;
  // Math rendering preference (persisted)
  bool _mathEnabled = true;

  Future<void> _deleteNote(String id) async {
    // If mapped to Drive, attempt to delete on Drive first
    final driveId = _localToDriveId[id];
    if (driveId != null && _driveService.isSignedIn) {
      try {
        _syncStatus[id] = SyncStatus.syncing;
        setState(() {});
        await _driveService.deleteFile(driveId);
        _syncStatus[id] = SyncStatus.synced;
      } catch (e) {
        debugPrint('[Drive] delete error: $e');
        _syncStatus[id] = SyncStatus.error;
      }
      // remove mapping and persist
      _localToDriveId.remove(id);
      await _saveLocalDriveMap();
    }

    setState(() {
      _notes.removeWhere((note) => note.id == id);
      if (_selectedNoteId == id) {
        _selectedNoteId = null;
      }
    });
    unawaited(_noteRepo.saveNotes(_notes));
  }

  void _showSyncLogs(String noteId) {
    final logs = _syncLogs[noteId] ?? [];
    final last = _lastSync[noteId];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sync info'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (last != null) Text('Last sync: ${DateFormat.yMMMd().add_jm().format(last)}'),
              const SizedBox(height: 8),
              const Text('Logs:'),
              const SizedBox(height: 6),
              if (logs.isEmpty) const Text('No logs yet'),
              if (logs.isNotEmpty) ...logs.reversed.take(10).map((l) => Text('• $l')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(String noteId) async {
    final driveId = _localToDriveId[noteId];
    final choices = <String>[];
    choices.add('Delete locally');
    if (driveId != null && _driveService.isSignedIn) {
      choices.add('Delete from Drive too');
    }

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm delete'),
          content: Text(
            driveId != null
                ? 'This note exists on Drive. Do you want to delete locally, or delete it from Drive as well?'
                : 'Delete this note locally?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('Delete locally'),
              child: const Text('Delete locally'),
            ),
            if (driveId != null && _driveService.isSignedIn)
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop('Delete from Drive too'),
                child: const Text('Delete from Drive'),
              ),
          ],
        );
      },
    );

    if (result == null) return;
    if (result == 'Delete locally') {
      await _deleteNote(noteId);
    } else if (result == 'Delete from Drive too') {
      // Force a remote delete (this will also remove local note)
      await _deleteNote(noteId);
    }
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            'Choose Theme',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // keep simplified theme choices here; the app-level ThemeProvider is still in main.dart
              Text('Theme switching is available in the main app.'),
            ],
          ),
        );
      },
    );
  }

  Future<void> _connectDrive() async {
    try {
      // If running on web, ensure a clientId is configured or prompt for it.
      if (kIsWeb) {
        final prefsClientId = await _driveService.getWebClientId();
        if (!mounted) return;
        if (prefsClientId == null) {
          final clientId = await _promptForWebClientId();
          if (!mounted) return;
          if (clientId == null) return;
          await _driveService.setWebClientId(clientId);
        }
      }

      debugPrint('Starting Drive sign-in...');
      final account = await _driveService.signIn();
      if (!mounted) return;
      if (account == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Drive sign-in canceled')));
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Signed in: ${account.email}')));
      if (!mounted) return;
      setState(() {});
      // After sign-in prompt user to select or create a folder
      await _promptSelectOrCreateFolder();
    } catch (e, st) {
      debugPrint('[Drive] sign-in error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Drive sign-in failed: $e')));
    }
  }

  Future<void> _promptSelectOrCreateFolder() async {
    final controller = TextEditingController(text: 'Noteker Notes');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Drive Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Create/Select'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final folderId = await _driveService.ensureFolder(result);
      if (!mounted) return;
      setState(() {
        _driveFolderId = folderId;
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('drive_last_folder_id', folderId);
      } catch (_) {}
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Folder ready')));
      // Start periodic sync every 60 seconds. Use Timer.periodic on native
      // platforms but a Future.delayed loop on web to avoid debug/proxy issues
      // seen with Timer streams in some web environments.
      _periodicSyncTimer?.cancel();
      _stopPeriodicSyncLoop();
      if (kIsWeb) {
        _startPeriodicSyncLoop();
      } else {
        _periodicSyncTimer = Timer.periodic(
          const Duration(seconds: 60),
          (_) => _syncFromDrive(),
        );
      }
    }
  }

  Future<void> _attemptRestoreDriveSession() async {
    try {
      final account = await _driveService.signInSilently();
      if (account == null) return;
      final prefs = await SharedPreferences.getInstance();
      final lastFolder = prefs.getString('drive_last_folder_id');
      if (lastFolder != null && lastFolder.isNotEmpty) {
        setState(() {
          _driveFolderId = lastFolder;
        });
        _periodicSyncTimer?.cancel();
        _stopPeriodicSyncLoop();
        if (kIsWeb) {
          _startPeriodicSyncLoop();
        } else {
          _periodicSyncTimer = Timer.periodic(
            const Duration(seconds: 60),
            (_) => _syncFromDrive(),
          );
        }
      }
    } catch (e) {
      debugPrint('[Drive] restore session failed: $e');
    }
  }

  void _startPeriodicSyncLoop() {
    if (_periodicSyncLoopActive) return;
    _periodicSyncLoopActive = true;
    // Fire-and-forget async loop
    () async {
      while (_periodicSyncLoopActive) {
        await Future.delayed(const Duration(seconds: 60));
        if (!_periodicSyncLoopActive) break;
        // Don't await to avoid blocking the loop if sync hangs; let it run
        // asynchronously.
        _unawaited(_syncFromDrive());
      }
    }();
  }

  void _stopPeriodicSyncLoop() {
    _periodicSyncLoopActive = false;
  }

  // Simple fire-and-forget helper; keeps code explicit without depending on
  // SDK-side `unawaited` helper exports which vary across SDK versions.
  void _unawaited(Future<void> f) {}

  @override
  void dispose() {
    _debounceUploadTimer?.cancel();
    _periodicSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _attemptRestoreDriveSession();
    _loadLocalDriveMap();
    _ensureWebClientIdProvided();
    // load persisted notes
    _noteRepo.loadNotes().then((loaded) {
      if (!mounted) return;
      setState(() {
        _notes.clear();
        _notes.addAll(loaded);
        _notes.sort((a, b) => b.date.compareTo(a.date));
      });
    });
    // load math preference
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _mathEnabled = p.getBool(kPrefKeyMathEnabled) ?? true;
      });
    });
    // Insert a demo note on first run to showcase math and line-breaks and show walkthrough once
    SharedPreferences.getInstance().then((p) async {
      final demoSeen = p.getBool('demo_shown_v1') ?? false;
      final walkthroughShown = p.getBool('walkthrough_shown_v1') ?? false;
      if (!demoSeen) {
        final loc = AppLocalizations.of(context);
        final demo = Note(
          id: 'demo-1',
          title: loc.demoTitle,
          content: loc.demoContent,
          date: DateTime.now(),
        );
        // merge only if not present
        if (!_notes.any((n) => n.id == demo.id)) {
          setState(() {
            _notes.insert(0, demo);
            _selectedNoteId = demo.id;
          });
          await _noteRepo.saveNotes(_notes);
        }
        await p.setBool('demo_shown_v1', true);
        // Show a short walkthrough after the demo is inserted (only once)
        if (!walkthroughShown) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showWalkthrough();
            p.setBool('walkthrough_shown_v1', true);
          });
        }
      }
    });
  }

  // Demo content provided by AppLocalizations (see lib/l10n/app_en.arb for source).

  // Show or focus the demo note; if removed, re-insert it. Scroll/select it in the UI.
  Future<void> _showDemoNote() async {
    final demoId = 'demo-1';
    final existing = _notes.where((n) => n.id == demoId).toList();
      if (existing.isEmpty) {
        final loc = AppLocalizations.of(context);
      final demo = Note(
        id: demoId,
        title: loc.demoTitle,
        content: loc.demoContent,
        date: DateTime.now(),
      );
      setState(() {
        _notes.insert(0, demo);
        _selectedNoteId = demo.id;
      });
      await _noteRepo.saveNotes(_notes);
    } else {
      setState(() {
        _selectedNoteId = demoId;
      });
    }
  }

  // A small walkthrough dialog with a few pages explaining core features.
  Future<void> _showWalkthrough() async {
    var page = 0;
    final pages = <Widget>[
      const SizedBox(
        width: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome to Noteker!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('A minimal local-first note app with optional Drive sync and LaTeX support.'),
          ],
        ),
      ),
      const SizedBox(
        width: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create & Edit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Tap + to create a note. Edit inline on wide screens, or open the full editor on mobile.'),
          ],
        ),
      ),
      const SizedBox(
        width: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Math & Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Toggle math rendering using the ƒ button. Single newlines are preserved in the preview.'),
          ],
        ),
      ),
      const SizedBox(
        width: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Drive Sync', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Connect to Google Drive to backup and sync your notes across devices.'),
          ],
        ),
      ),
    ];

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setInnerState) {
          return AlertDialog(
            title: Text('Quick tour (${page + 1}/${pages.length})'),
            content: pages[page],
            actions: [
              TextButton(
                onPressed: () {
                  if (page > 0) {
                    setInnerState(() => page -= 1);
                  } else {
                    Navigator.of(ctx2).pop();
                  }
                },
                child: const Text('Back'),
              ),
              TextButton(
                onPressed: () {
                  if (page < pages.length - 1) {
                    setInnerState(() => page += 1);
                  } else {
                    Navigator.of(ctx2).pop();
                  }
                },
                child: Text(page < pages.length - 1 ? 'Next' : 'Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx2).pop();
                  // Open demo after closing
                  _showDemoNote();
                },
                child: const Text('Show Demo'),
              ),
            ],
          );
        });
      },
    );
  }
 

  Future<void> _ensureWebClientIdProvided() async {
    if (!kIsWeb) return;
    const clientId =
        '611993003321-66s7r0342ljmshg3eup589u5pnqabe76.apps.googleusercontent.com';
    try {
      final existing = await _driveService.getWebClientId();
      if (existing == null || existing.isEmpty) {
        await _driveService.setWebClientId(clientId);
        debugPrint('[Drive] web client id set from code');
      } else {
        debugPrint('[Drive] web client id already present');
      }
    } catch (e) {
      debugPrint('[Drive] could not set web client id: $e');
    }
  }

  Future<void> _loadLocalDriveMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kLocalDriveMapKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(jsonStr);
        _localToDriveId.clear();
        decoded.forEach((k, v) {
          if (v is String) _localToDriveId[k] = v;
        });
      }
    } catch (e) {
      debugPrint('[DriveMap] could not load local->drive map: $e');
    }
  }




  Future<void> _saveLocalDriveMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalDriveMapKey, json.encode(_localToDriveId));
    } catch (e) {
      debugPrint('[DriveMap] could not save local->drive map: $e');
    }
  }

  // Return a filtered & sorted view of notes for display in the sidebar.
  List<Note> _filteredAndSortedNotes(List<Note> source) {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = source.where((n) {
      if (q.isEmpty) return true;
      final title = n.title.toLowerCase();
      final content = n.content.toLowerCase();
      return title.contains(q) || content.contains(q);
    }).toList();
    if (_sortByDateDesc) {
      filtered.sort((a, b) => b.date.compareTo(a.date));
    } else {
      filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return filtered;
  }

  // Sync files from Drive folder and merge new/updated notes into local list
  Future<void> _syncFromDrive() async {
    if (!_driveService.isSignedIn || _driveFolderId == null) return;
    try {
      final files = await _driveService.listMarkdownFiles(_driveFolderId!);
      for (final f in files) {
        final id = f.id!;
        final existing = _notes
            .where((n) => n.id == id || _localToDriveId[n.id] == id)
            .toList();
        final content = await _driveService.downloadFileContent(id);
        final title = (f.name ?? 'Untitled').replaceAll('.md', '');
        if (existing.isEmpty) {
          final note = Note(
            id: id,
            title: title,
            content: content,
            date: f.modifiedTime ?? DateTime.now(),
          );
          _addOrUpdateNote(note);
          _localToDriveId[note.id] = id;
          _lastSync[note.id] = DateTime.now();
          _syncLogs
              .putIfAbsent(note.id, () => [])
              .add('Imported $id at ${_lastSync[note.id]}');
        } else {
          // Update the first matching note
          final note = existing.first;
          final updated = Note(
            id: note.id == id ? id : note.id,
            title: title,
            content: content,
            date: f.modifiedTime ?? DateTime.now(),
          );
          _addOrUpdateNote(updated);
          _localToDriveId[updated.id] = id;
          _lastSync[updated.id] = DateTime.now();
          _syncLogs
              .putIfAbsent(updated.id, () => [])
              .add('Pulled $id at ${_lastSync[updated.id]}');
        }
      }
    } catch (e) {
      debugPrint('[Drive Sync] error: $e');
    }
  }

  Future<void> _showDriveFilesAndImport() async {
    if (!_driveService.isSignedIn || _driveFolderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect and select a folder first')),
      );
      return;
    }
    final files = await _driveService.listMarkdownFiles(_driveFolderId!);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Markdown files'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: files.isEmpty
                ? const Center(child: Text('No markdown files found'))
                : ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final f = files[index];
                      return ListTile(
                        title: Text(f.name ?? 'Unnamed'),
                        subtitle: Text(f.modifiedTime?.toString() ?? ''),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          final content = await _driveService
                              .downloadFileContent(f.id!);
                          final title = (f.name ?? 'Untitled').replaceAll(
                            '.md',
                            '',
                          );
                          final note = Note(
                            id: f.id!,
                            title: title,
                            content: content,
                            date: f.modifiedTime ?? DateTime.now(),
                          );
                          _addOrUpdateNote(note);
                          if (!mounted) return;
                          setState(() {
                            _selectedNoteId = note.id;
                          });
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _promptForWebClientId() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Web OAuth Client ID'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Paste client id (xxxx.apps.googleusercontent.com)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // Responsive layout: show a sidebar on wide screens containing the list
    // of notes and an editor in the main area. On narrow screens fall back to
    // the original grid + full-screen editor flow.
    final isWide = MediaQuery.of(context).size.width >= 800;
    // Add a keyboard shortcut (Meta/Ctrl+H) to open the walkthrough.
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyH): const _ShowWalkthroughIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyH): const _ShowWalkthroughIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ShowWalkthroughIntent: CallbackAction<_ShowWalkthroughIntent>(onInvoke: (i) {
            _showWalkthrough();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Notes'),
              actions: [
                Consumer<GamificationProvider>(
                  builder: (context, gp, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.local_fire_department, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text('${gp.streak}'),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 64,
                          height: 10,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: gp.progressToNext.clamp(0, 1)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('Lv ${gp.level}'),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Share note',
                  onPressed: () async {
                    final note = _selectedNoteId == null
                        ? null
                        : _notes.firstWhere((n) => n.id == _selectedNoteId, orElse: () => _notes.isEmpty ? null as dynamic : _notes.first);
                    if (note == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a note to share')));
                      return;
                    }
                    await Share.share(note.content, subject: note.title);
                    if (mounted) context.read<GamificationProvider>().addXp(20);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () => _showThemeDialog(context),
                ),
                IconButton(
                  icon: const Icon(Icons.cloud),
                  tooltip: 'Connect Drive',
                  onPressed: () => _connectDrive(),
                ),
                IconButton(
                  icon: const Icon(Icons.file_download),
                  tooltip: 'Import from Drive',
                  onPressed: () => _showDriveFilesAndImport(),
                ),
                // Overflow menu for demo/walkthrough actions
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'show_demo') {
                      _showDemoNote();
                    } else if (v == 'show_walkthrough') {
                      _showWalkthrough();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'show_demo', child: Text('Show Demo')),
                    const PopupMenuItem(value: 'show_walkthrough', child: Text('Show Walkthrough')),
                  ],
                ),
              ],
            ),
            body: Stack(
              children: [
                isWide ? _buildWideLayout(context) : _buildNarrowLayout(context),
                // Achievement toast overlay
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: const AchievementToaster(),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                if (isWide) {
                  // Create a new blank note and open it inline
                  final newNote = Note(
                    id: Random().nextInt(100000).toString(),
                    title: 'Untitled Note',
                    content: '',
                    date: DateTime.now(),
                  );
                  _addOrUpdateNote(newNote);
                  setState(() {
                    _selectedNoteId = newNote.id;
                  });
                } else {
                  // Full-screen editor that autosaves via onChanged
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteEditorScreen(
                        onChanged: (note) => _addOrUpdateNote(note),
                      ),
                    ),
                  );
                }
              },
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
    );
  }

  // Wide layout builds
  Widget _buildWideLayout(BuildContext context) {
    final selectedNote = _selectedNoteId == null
        ? null
        : (_notes.where((n) => n.id == _selectedNoteId).isEmpty
              ? null
              : _notes.firstWhere((n) => n.id == _selectedNoteId));
    return Row(
      children: [
        // Sidebar
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              right: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search notes',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              setState(() {
                                _searchQuery = v.trim();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          tooltip: 'Sort',
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'date', child: Text('Date')),
                            const PopupMenuItem(value: 'title', child: Text('Title')),
                          ],
                          onSelected: (v) {
                            setState(() {
                              if (v == 'date') {
                                _sortByDateDesc = true;
                              } else {
                                _sortByDateDesc = false;
                              }
                            });
                          },
                          child: const Icon(Icons.sort),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SidebarNotesList(
                  notes: _filteredAndSortedNotes(_notes),
                  selectedId: _selectedNoteId,
                  syncStatus: _syncStatus,
                  onShowSync: (id) => _showSyncLogs(id),
                  onDelete: (id) async => await _confirmAndDelete(id),
                  onSelect: (note) {
                    final prevId = _selectedNoteId;
                    if (prevId != null && prevId != note.id) {
                      final prevNote = _notes.firstWhere((n) => n.id == prevId, orElse: () => note);
                      if (_dirtyNotes.contains(prevId)) {
                        _uploadNote(prevNote);
                      }
                    }
                    setState(() {
                      _selectedNoteId = note.id;
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        // Main area: inline editor when a note is selected, otherwise prompt.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: selectedNote == null
                ? Center(
                    child: Text(
                      'Select a note from the left to edit it, or tap + to create one.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EditorHeader(
                        note: selectedNote,
                        syncText: _syncStatus[selectedNote.id] == SyncStatus.syncing
                            ? 'Saving…'
                            : _syncStatus[selectedNote.id] == SyncStatus.synced
                                ? 'Saved'
                                : _syncStatus[selectedNote.id] == SyncStatus.error
                                    ? 'Error'
                                    : (_dirtyNotes.contains(selectedNote.id) ? 'Unsaved changes' : ''),
                        isPreview: _isPreview,
                        onTogglePreview: () {
                          setState(() {
                            _isPreview = !_isPreview;
                          });
                        },
                        mathEnabled: _mathEnabled,
                        onToggleMath: () async {
                          final prefs = await SharedPreferences.getInstance();
                          setState(() {
                            _mathEnabled = !_mathEnabled;
                          });
                          await prefs.setBool(kPrefKeyMathEnabled, _mathEnabled);
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: _isSplit
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: NoteEditor(
                                        note: selectedNote,
                                        onChanged: (updated) {
                                          _addOrUpdateNote(updated);
                                          setState(() {
                                            _selectedNoteId = updated.id;
                                          });
                                        },
                                      ),
                                    ),
                                    const VerticalDivider(width: 1),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: SingleChildScrollView(
                                          child: NoteMarkdownView(content: selectedNote.content, mathEnabled: _mathEnabled),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : (_isPreview
                                  ? Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: SingleChildScrollView(
                                         child: NoteMarkdownView(content: selectedNote.content, mathEnabled: _mathEnabled),
                                      ),
                                    )
                                  : NoteEditor(
                                      note: selectedNote,
                                      onChanged: (updated) {
                                        _addOrUpdateNote(updated);
                                        setState(() {
                                          _selectedNoteId = updated.id;
                                        });
                                      },
                                    )),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // Narrow layout keeps original MasonryGridView behaviour
  Widget _buildNarrowLayout(BuildContext context) {
    return _notes.isEmpty
        ? Center(
            child: Text(
              'No notes yet.\nTap + to create one!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        : MasonryGridView.count(
            padding: const EdgeInsets.all(12.0),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: _notes.length,
            itemBuilder: (context, index) {
              final note = _notes[index];
              return NoteCard(
                note: note,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteEditorScreen(
                        note: note,
                        onChanged: (n) => _addOrUpdateNote(n),
                      ),
                    ),
                  );
                },
                onDelete: () async {
                  await _deleteNote(note.id);
                },
                status: _syncStatus[note.id],
              );
            },
          );
  }
}
