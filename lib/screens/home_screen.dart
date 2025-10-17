import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations_shim.dart' show AppLocalizations;
import '../models/note.dart';
import '../providers/gamification_provider.dart';
import '../services/drive_service.dart';
import '../services/note_repository.dart';
import '../utils/markdown_helpers.dart';
import '../widgets/achievement_toaster.dart';
import '../widgets/editor_header.dart';
import '../widgets/note_card.dart';
import '../widgets/note_editor.dart';
import '../widgets/note_markdown_view.dart';
import '../widgets/sidebar_notes_list.dart';
import 'settings_screen.dart';

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
  final bool _sortByDateDesc = true;

  void _addOrUpdateNote(Note? note) {
    if (note == null) {
      return;
    }
    
    setState(() {
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note;
      } else {
        _notes.insert(0, note);
      }
      _notes.sort((a, b) => b.date.compareTo(a.date));
    });
    
    // persist notes
    _unawaited(_noteRepo.saveNotes(_notes));
    // Mark note as dirty and start timer for upload
    _dirtyNotes.add(note.id);
    _inactivityTimers[note.id]?.cancel();
    _inactivityTimers[note.id] = Timer(const Duration(seconds: 10), () {
      _uploadNote(note);
    });
  }

  // Upload or update a single note to Drive
  Future<void> _uploadNote(Note note) async {
    if (!_driveService.isSignedIn || _driveFolderId == null) {
      return;
    }
    
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
          driveId = created.id;
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
      
      _uploadsInFlight.remove(note.id);
      if (_dirtyNotes.contains(note.id)) {
        _unawaited(Future.microtask(() => _uploadNote(note)));
      }
    } on Exception catch (e) {
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
  final Map<String, String> _localToDriveId = {};
  static const _kLocalDriveMapKey = 'local_drive_map_v1';

  Timer? _debounceUploadTimer;
  Timer? _periodicSyncTimer;
  bool _isPreview = false;
  bool _mathEnabled = true;

  final Map<String, SyncStatus> _syncStatus = {};
  final Map<String, DateTime> _lastSync = {};
  final Map<String, List<String>> _syncLogs = {};
  final Map<String, Timer> _inactivityTimers = {};
  final Set<String> _dirtyNotes = {};
  final Set<String> _uploadsInFlight = {};

  Future<void> _deleteNote(String id) async {
    final driveId = _localToDriveId[id];
    if (driveId != null && _driveService.isSignedIn) {
      try {
        _syncStatus[id] = SyncStatus.syncing;
        setState(() {});
        await _driveService.deleteFile(driveId);
        _syncStatus[id] = SyncStatus.synced;
      } on Exception catch (e) {
        debugPrint('[Drive] delete error: $e');
        _syncStatus[id] = SyncStatus.error;
      }
      _localToDriveId.remove(id);
      await _saveLocalDriveMap();
    }

    setState(() {
      _notes.removeWhere((note) => note.id == id);
      if (_selectedNoteId == id) {
        _selectedNoteId = null;
      }
    });
    _unawaited(_noteRepo.saveNotes(_notes));
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
    final choices = <String>['Delete locally'];
    if (driveId != null && _driveService.isSignedIn) {
      choices.add('Delete from Drive too');
    }

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm delete'),
        content: Text(
          driveId != null
              ? 'This note exists on Drive. Do you want to delete locally, or delete it from Drive as well?'
              : 'Delete this note locally?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
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
      ),
    );

    if (result == null) {
      return;
    }
    if (result == 'Delete locally') {
      await _deleteNote(noteId);
    } else if (result == 'Delete from Drive too') {
      await _deleteNote(noteId);
    }
  }

  void _unawaited(Future<void> f) {}

  Future<void> _saveLocalDriveMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalDriveMapKey, json.encode(_localToDriveId));
    } on Exception catch (e) {
      debugPrint('[DriveMap] could not save local->drive map: $e');
    }
  }

  @override
  void dispose() {
    _debounceUploadTimer?.cancel();
    _periodicSyncTimer?.cancel();
    for (final timer in _inactivityTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    
    // load persisted notes
    _noteRepo.loadNotes().then((loaded) {
      if (!mounted) {
        return;
      }
      setState(() {
        _notes
          ..clear()
          ..addAll(loaded)
          ..sort((a, b) => b.date.compareTo(a.date));
      });
    });
    
    // load math preference
    SharedPreferences.getInstance().then((p) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mathEnabled = p.getBool(kPrefKeyMathEnabled) ?? true;
      });
      
      // Show demo and walkthrough on first run
      final demoSeen = p.getBool('demo_shown_v1') ?? false;
      final walkthroughShown = p.getBool('walkthrough_shown_v1') ?? false;
      if (!demoSeen && mounted) {
        final loc = AppLocalizations.of(context);
        final demo = Note(
          id: 'demo-1',
          title: loc.demoTitle,
          content: loc.demoContent,
          date: DateTime.now(),
        );
        setState(() {
          _addOrUpdateNote(demo);
          _selectedNoteId = demo.id;
        });
        p.setBool('demo_shown_v1', true);
        
        // Show a short walkthrough after the demo is inserted (only once)
        if (!walkthroughShown) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showWalkthrough();
            p.setBool('walkthrough_shown_v1', true);
          });
        }
      }
    });

    // Initialize Drive sync (silent sign-in, ensure folder, periodic sync)
    // Fire-and-forget to avoid delaying first frame
    _unawaited(_initDriveSync());
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    
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
                  icon: Icon(_driveService.isSignedIn ? Icons.cloud_done : Icons.cloud_off),
                  tooltip: _driveService.isSignedIn ? 'Drive: Signed in' : 'Drive: Sign in',
                  onPressed: () async {
                    if (!_driveService.isSignedIn) {
                      try {
                        // Ensure web client ID is set before attempting sign-in
                        await _ensureWebClientIdProvided();
                        
                        final account = await _driveService.signIn();
                        if (account == null) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Google Sign-In failed or was canceled.')),
                          );
                          return;
                        }
                      } on Exception catch (e) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sign-in error: $e')),
                        );
                        return;
                      }
                      try {
                        final folderChoice = await _showFolderPickerDialog();
                        if (folderChoice == null) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Folder selection canceled.')),
                          );
                          return;
                        }
                        final folderId = folderChoice == 'create_noteker'
                            ? await _driveService.ensureFolder('Noteker')
                            : folderChoice;
                        if (!context.mounted) {
                          return;
                        }
                        setState(() {
                          _driveFolderId = folderId;
                        });
                        // Save the folder ID for future silent sign-ins
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('drive_folder_id', folderId);
                        await _loadLocalDriveMap();
                        await _syncFromDrive();
                        _periodicSyncTimer?.cancel();
                        _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) => _syncDirtyNotes());
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Drive connected.')),
                        );
                      } on Exception catch (e) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Drive setup failed: $e')),
                        );
                      }
                    } else {
                      await _driveService.signOut();
                      _periodicSyncTimer?.cancel();
                      setState(() {
                        _driveFolderId = null;
                      });
                      // Clear stored folder ID
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('drive_folder_id');
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signed out of Drive.')),
                      );
                    }
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'More options',
                  onSelected: (String value) {
                    if (value == 'show_demo') {
                      _showDemoNote();
                    } else if (value == 'show_walkthrough') {
                      _showWalkthrough();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'show_demo',
                      child: ListTile(
                        leading: Icon(Icons.lightbulb_outline),
                        title: Text('Show Demo'),
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'show_walkthrough',
                      child: ListTile(
                        leading: Icon(Icons.help_outline),
                        title: Text('Show Walkthrough'),
                        dense: true,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
            body: Stack(
              children: [
                if (isWide)
                  _buildWideLayout(context)
                else
                  _buildNarrowLayout(context),
                const Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: AchievementToaster(),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                if (isWide) {
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
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => NoteEditorScreen(
                        onChanged: _addOrUpdateNote,
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

  Widget _buildWideLayout(BuildContext context) {
    final selectedNote = _selectedNoteId == null
        ? null
        : (_notes.where((n) => n.id == _selectedNoteId).isEmpty
              ? null
              : _notes.firstWhere((n) => n.id == _selectedNoteId));
    
    return Row(
      children: [
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
                    TextField(
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
                  ],
                ),
              ),
              Expanded(
                child: SidebarNotesList(
                  notes: _filteredAndSortedNotes(_notes),
                  selectedId: _selectedNoteId,
                  syncStatus: _syncStatus,
                  onShowSync: _showSyncLogs,
                  onDelete: _confirmAndDelete,
                  onSelect: (note) {
                    setState(() {
                      _selectedNoteId = note.id;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
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
                          if (!context.mounted) {
                            return;
                          }
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
                          child: _isPreview
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
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context) =>
      _notes.isEmpty
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
                    MaterialPageRoute<void>(
                      builder: (context) => NoteEditorScreen(
                        note: note,
                        onChanged: _addOrUpdateNote,
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
  

  List<Note> _filteredAndSortedNotes(List<Note> source) {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = source.where((n) {
      if (q.isEmpty) {
        return true;
      }
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

  Future<void> _initDriveSync() async {
    try {
      // Ensure web client ID is set before attempting sign-in
      await _ensureWebClientIdProvided();
      
      final account = await _driveService.signInSilently();
      if (account == null) {
        return;
      }

      // Only proceed with sync if we have a previously configured folder
      final prefs = await SharedPreferences.getInstance();
      final storedFolderId = prefs.getString('drive_folder_id');
      if (storedFolderId == null) {
        // No folder configured yet, wait for manual setup
        return;
      }

      await _loadLocalDriveMap();
      if (!context.mounted) {
        return;
      }
      setState(() {
        _driveFolderId = storedFolderId;
      });
      await _syncFromDrive();
      _periodicSyncTimer?.cancel();
      _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) => _syncDirtyNotes());
    } on Object catch (_) {
      // ignore init failures; user can tap the cloud icon to retry
    }
  }

  Future<void> _loadLocalDriveMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLocalDriveMapKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _localToDriveId
        ..clear()
        ..addAll(decoded.map((k, v) => MapEntry(k, v as String)));
    } on Object catch (_) {
      // ignore corrupt map
    }
  }

  void _syncDirtyNotes() {
    if (!_driveService.isSignedIn || _driveFolderId == null) {
      return;
    }
    final ids = List<String>.from(_dirtyNotes);
    for (final id in ids) {
      final maybe = _notes.where((n) => n.id == id);
      if (maybe.isEmpty) {
        continue;
      }
      final note = maybe.first;
      _unawaited(_uploadNote(note));
    }
  }

  Future<String?> _showFolderPickerDialog() async {
    final folders = await _driveService.listFolders();
    if (!mounted) {
      return null;
    }
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Drive Folder'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            children: [
              const Text('Select a folder to sync your notes with, or create a new one.'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: folders.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        leading: const Icon(Icons.create_new_folder),
                        title: const Text('Create "Noteker" folder'),
                        onTap: () => Navigator.of(ctx).pop('create_noteker'),
                      );
                    }
                    final folder = folders[index - 1];
                    return ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(folder.name ?? 'Unnamed Folder'),
                      subtitle: folder.modifiedTime != null
                          ? Text('Modified: ${DateFormat.yMMMd().format(folder.modifiedTime!)}')
                          : null,
                      onTap: () => Navigator.of(ctx).pop(folder.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncFromDrive() async {
    if (!_driveService.isSignedIn || _driveFolderId == null) {
      return;
    }
    try {
      final files = await _driveService.listMarkdownFiles(_driveFolderId!);
      for (final f in files) {
        final id = f.id!;
        final existing = _notes.where((n) => _localToDriveId[n.id] == id).toList();
        final content = await _driveService.downloadFileContent(id);
        final title = (f.name ?? 'Untitled').replaceAll('.md', '');

        if (existing.isEmpty) {
          // New note from Drive, create a new local note.
          final newLocalId = Random().nextInt(100000).toString();
          final note = Note(
            id: newLocalId,
            title: title,
            content: content,
            date: f.modifiedTime ?? DateTime.now(),
          );
          _addOrUpdateNote(note);
          _localToDriveId[note.id] = id;
          _lastSync[note.id] = DateTime.now();
          _syncLogs.putIfAbsent(note.id, () => []).add('Imported $id at ${_lastSync[note.id]}');
          _syncStatus[note.id] = SyncStatus.synced;
        } else {
          // Existing note, update it.
          final note = existing.first;
          // Only update local note if content or timestamp differ.
          final localContent = note.content;
          String normalize(String s) => s.replaceAll('\r\n', '\n').trim();
          if (normalize(localContent) != normalize(content) || note.date.isBefore(f.modifiedTime ?? note.date)) {
            final updated = Note(
              id: note.id,
              title: title,
              content: content,
              date: f.modifiedTime ?? DateTime.now(),
            );
            _addOrUpdateNote(updated);
            _lastSync[updated.id] = DateTime.now();
            _syncLogs.putIfAbsent(updated.id, () => []).add('Pulled $id at ${_lastSync[updated.id]}');
            _syncStatus[updated.id] = SyncStatus.synced;
          } else {
            // No change; still ensure mapping and last sync recorded.
            _localToDriveId[note.id] = id;
            _lastSync[note.id] = DateTime.now();
            _syncLogs.putIfAbsent(note.id, () => []).add('Mapped $id at ${_lastSync[note.id]}');
            _syncStatus[note.id] = SyncStatus.synced;
          }
        }
      }
      await _saveLocalDriveMap();
      setState(() {});
    } on Exception catch (e) {
      debugPrint('[Drive Sync] error: $e');
    }
  }

  Future<void> _ensureWebClientIdProvided() async {
    if (!kIsWeb) {
      return;
    }
    const clientId = '611993003321-66s7r0342ljmshg3eup589u5pnqabe76.apps.googleusercontent.com';
    try {
      final existing = await _driveService.getWebClientId();
      if (existing == null || existing.isEmpty) {
        await _driveService.setWebClientId(clientId);
        debugPrint('[Drive] web client id set from code');
      } else {
        debugPrint('[Drive] web client id already present');
      }
    } on Exception catch (e) {
      debugPrint('[Drive] could not set web client id: $e');
    }
  }

  // Show or focus the demo note; if removed, re-insert it. Scroll/select it in the UI.
  Future<void> _showDemoNote() async {
    const demoId = 'demo-1';
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
        _addOrUpdateNote(demo);
        _selectedNoteId = demo.id;
      });
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setInnerState) => AlertDialog(
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
        ),
      ),
    );
  }
}
