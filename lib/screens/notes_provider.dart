import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:noteker/models/note.dart';
import 'package:noteker/services/drive_service.dart';
import 'package:noteker/services/note_repository.dart';
import 'package:noteker/utils/markdown_helpers.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noteker/l10n/app_localizations.dart';

class NotesProvider extends ChangeNotifier {
  final NoteRepository _noteRepo = SharedPrefsNoteRepository();
  final DriveService driveService = DriveService();

  // Core state
  final List<Note> _notes = [];
  String? _selectedNoteId;
  String _searchQuery = '';
  bool _sortByDateDesc = true;

  // UI state for wide-screen editor
  bool _isPreview = false;
  bool _isSplit = false;
  bool _mathEnabled = true;

  // Drive sync state
  String? _driveFolderId;
  final Map<String, String> _localToDriveId = {};
  final Map<String, SyncStatus> _syncStatus = {};
  final Map<String, DateTime> _lastSync = {};
  final Map<String, List<String>> _syncLogs = {};

  // Internal state for managing sync operations
  final Map<String, Timer> _inactivityTimers = {};
  final Set<String> _dirtyNotes = {};
  final Set<String> _uploadsInFlight = {};
  Timer? _periodicSyncTimer;
  bool _periodicSyncLoopActive = false;

  static const _kLocalDriveMapKey = 'local_drive_map_v1';

  // Getters
  List<Note> get notes => _notes;
  String? get selectedNoteId => _selectedNoteId;
  Note? get selectedNote => _selectedNoteId == null
      ? null
      : _notes.where((n) => n.id == _selectedNoteId).firstOrNull;
  String get searchQuery => _searchQuery;
  bool get sortByDateDesc => _sortByDateDesc;
  bool get isPreview => _isPreview;
  bool get isSplit => _isSplit;
  bool get mathEnabled => _mathEnabled;
  String? get driveFolderId => _driveFolderId;
  Map<String, SyncStatus> get syncStatus => _syncStatus;
  Map<String, DateTime> get lastSync => _lastSync;
  Map<String, List<String>> get syncLogs => _syncLogs;
  Map<String, String> get localToDriveId => _localToDriveId;

  List<Note> get filteredAndSortedNotes {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = _notes.where((n) {
      if (q.isEmpty) return true;
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q);
    }).toList();

    if (_sortByDateDesc) {
      filtered.sort((a, b) => b.date.compareTo(a.date));
    } else {
      filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return filtered;
  }

  NotesProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadLocalDriveMap();
    await _ensureWebClientIdProvided();

    final loadedNotes = await _noteRepo.loadNotes();
    _notes.clear();
    _notes.addAll(loadedNotes);
    _notes.sort((a, b) => b.date.compareTo(a.date));

    final prefs = await SharedPreferences.getInstance();
    _mathEnabled = prefs.getBool(kPrefKeyMathEnabled) ?? true;

    notifyListeners();
  }

  // Public methods to modify state

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortBy(bool byDate) {
    _sortByDateDesc = byDate;
    notifyListeners();
  }

  void selectNote(String? noteId) {
    // Before switching, if the previously selected note is dirty, trigger an upload.
    final prevId = _selectedNoteId;
    if (prevId != null && prevId != noteId) {
      final prevNote = _notes.firstWhere((n) => n.id == prevId, orElse: () => _notes.first);
      if (_dirtyNotes.contains(prevId)) {
        uploadNote(prevNote);
      }
    }
    _selectedNoteId = noteId;
    notifyListeners();
  }

  void togglePreview() {
    _isPreview = !_isPreview;
    notifyListeners();
  }

  void toggleSplit() {
    _isSplit = !_isSplit;
    notifyListeners();
  }

  Future<void> toggleMath() async {
    _mathEnabled = !_mathEnabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefKeyMathEnabled, _mathEnabled);
  }

  Future<void> addOrUpdateNote(Note note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note;
    } else {
      _notes.insert(0, note);
    }
    _notes.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();

    unawaited(_noteRepo.saveNotes(_notes));

    // Mark note as dirty and schedule for upload after inactivity.
    _dirtyNotes.add(note.id);
    _inactivityTimers[note.id]?.cancel();
    _inactivityTimers[note.id] = Timer(const Duration(seconds: 10), () {
      uploadNote(note);
    });
  }

  Future<void> deleteNote(String id, {bool fromDrive = false}) async {
    final driveId = _localToDriveId[id];
    if (fromDrive && driveId != null && driveService.isSignedIn) {
      try {
        _syncStatus[id] = SyncStatus.syncing;
        notifyListeners();
        await driveService.deleteFile(driveId);
        _localToDriveId.remove(id);
        await _saveLocalDriveMap();
      } catch (e) {
        debugPrint('[Drive] delete error: $e');
        _syncStatus[id] = SyncStatus.error;
        notifyListeners();
        // Don't proceed with local deletion if Drive delete failed
        return;
      }
    }

    _notes.removeWhere((note) => note.id == id);
    if (_selectedNoteId == id) {
      _selectedNoteId = null;
    }
    notifyListeners();
    unawaited(_noteRepo.saveNotes(_notes));
  }

  Future<void> setDriveFolder(String folderId) async {
    _driveFolderId = folderId;
    notifyListeners();
    // Immediately sync all notes from Drive into local storage, then start periodic sync.
    await syncFromDrive();
    _startPeriodicSync();
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _stopPeriodicSyncLoop();
    if (kIsWeb) {
      _startPeriodicSyncLoop();
    } else {
      _periodicSyncTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => syncFromDrive(),
      );
    }
  }

  // Drive sync logic

  Future<void> uploadNote(Note note) async {
    if (!driveService.isSignedIn || _driveFolderId == null) return;
    if (_uploadsInFlight.contains(note.id)) {
      _dirtyNotes.add(note.id);
      return;
    }

    _uploadsInFlight.add(note.id);
    _syncStatus[note.id] = SyncStatus.syncing;
    notifyListeners();

    try {
      var driveId = _localToDriveId[note.id];
  String normalize(String s) => s.replaceAll('\r\n', '\n').trim();
  final localNormalized = normalize(note.content);
      if (driveId != null) {
        // Only push update if content differs from Drive
        final driveContent = await driveService.downloadFileContent(driveId);
        if (normalize(driveContent) == localNormalized) {
          // No change, mark as synced
          _updateSyncState(note.id, driveId, 'NoChange');
        } else {
          final updated = await driveService.updateMarkdownFile(driveId, note.title, note.content);
          _updateSyncState(note.id, updated.id, 'Updated');
        }
      } else {
        // Try to find a matching file by name before creating a new one.
        final files = await driveService.listMarkdownFiles(_driveFolderId!);
        final match = files.firstWhere(
          (f) => (f.name ?? '').replaceAll('.md', '') == note.title,
          orElse: () => drive.File(), // Dummy file with no ID
        );

        if (match.id != null) {
          // If a file exists with the same name, compare contents before updating.
          final driveContent = await driveService.downloadFileContent(match.id!);
          if (normalize(driveContent) == localNormalized) {
            // Contents equal, just record mapping and mark synced.
            _updateSyncState(note.id, match.id, 'Mapped (no change)');
          } else {
            final updated = await driveService.updateMarkdownFile(match.id!, note.title, note.content);
            _updateSyncState(note.id, updated.id, 'Updated matched');
          }
        } else {
          // New local note: create on Drive (since there is no remote counterpart).
          final created = await driveService.createMarkdownFile(_driveFolderId!, note.title, note.content);
          _updateSyncState(note.id, created.id, 'Created');
        }
      }

      _dirtyNotes.remove(note.id);
      _inactivityTimers[note.id]?.cancel();
    } catch (e) {
      _syncStatus[note.id] = SyncStatus.error;
      _syncLogs.putIfAbsent(note.id, () => []).add('Upload error: $e');
      debugPrint('[Drive] upload error: $e');
    } finally {
      _uploadsInFlight.remove(note.id);
      notifyListeners();
      if (_dirtyNotes.contains(note.id)) {
        Future.microtask(() => uploadNote(note));
      }
    }
  }

  void _updateSyncState(String localId, String? driveId, String logPrefix) {
    if (driveId != null && driveId.isNotEmpty) {
      _localToDriveId[localId] = driveId;
      _saveLocalDriveMap();
    }
    _lastSync[localId] = DateTime.now();
    _syncLogs.putIfAbsent(localId, () => []).add('$logPrefix $driveId at ${_lastSync[localId]}');
    _syncStatus[localId] = SyncStatus.synced;
  }

  Future<void> syncFromDrive() async {
    if (!driveService.isSignedIn || _driveFolderId == null) return;
    try {
      final files = await driveService.listMarkdownFiles(_driveFolderId!);
      for (final f in files) {
        final id = f.id!;
        final existing = _notes.where((n) => _localToDriveId[n.id] == id).toList();
        final content = await driveService.downloadFileContent(id);
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
          await addOrUpdateNote(note);
          _localToDriveId[note.id] = id;
          _updateSyncState(note.id, id, 'Imported');
        } else {
          // Existing note, update it.
          final note = existing.first;
          // Only update local note if content or timestamp differ.
          final localContent = note.content;
          final normalize = (String s) => s.replaceAll('\r\n', '\n').trim();
          if (normalize(localContent) != normalize(content) || note.date.isBefore(f.modifiedTime ?? note.date)) {
            final updated = Note(
              id: note.id,
              title: title,
              content: content,
              date: f.modifiedTime ?? DateTime.now(),
            );
            await addOrUpdateNote(updated);
            _updateSyncState(updated.id, id, 'Pulled');
          } else {
            // No change; still ensure mapping and last sync recorded.
            _localToDriveId[note.id] = id;
            _updateSyncState(note.id, id, 'Mapped');
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Drive Sync] error: $e');
    }
  }

  // Helper methods

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

  Future<void> _ensureWebClientIdProvided() async {
    if (!kIsWeb) return;
    const clientId = '611993003321-66s7r0342ljmshg3eup589u5pnqabe76.apps.googleusercontent.com';
    try {
      final existing = await driveService.getWebClientId();
      if (existing == null || existing.isEmpty) {
        await driveService.setWebClientId(clientId);
        debugPrint('[Drive] web client id set from code');
      }
    } catch (e) {
      debugPrint('[Drive] could not set web client id: $e');
    }
  }

  void _startPeriodicSyncLoop() {
    if (_periodicSyncLoopActive) return;
    _periodicSyncLoopActive = true;
    () async {
      while (_periodicSyncLoopActive) {
        await Future.delayed(const Duration(seconds: 60));
        if (!_periodicSyncLoopActive) break;
        unawaited(syncFromDrive());
      }
    }();
  }

  void _stopPeriodicSyncLoop() {
    _periodicSyncLoopActive = false;
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    _stopPeriodicSyncLoop();
    for (var timer in _inactivityTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  // Demo and Walkthrough logic
  Future<void> ensureDemoNote(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final demoSeen = prefs.getBool('demo_shown_v1') ?? false;
    if (!demoSeen) {
      final loc = AppLocalizations.of(context);
      final demo = Note(
        id: 'demo-1',
        title: loc.demoTitle,
        content: loc.demoContent,
        date: DateTime.now(),
      );
      if (!_notes.any((n) => n.id == demo.id)) {
        await addOrUpdateNote(demo);
        selectNote(demo.id);
      }
      await prefs.setBool('demo_shown_v1', true);
    }
  }

  Future<bool> shouldShowWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    final walkthroughShown = prefs.getBool('walkthrough_shown_v1') ?? false;
    if (!walkthroughShown) {
      await prefs.setBool('walkthrough_shown_v1', true);
      return true;
    }
    return false;
  }

  // Import a note from Drive, creating a new local note and mapping it.
  Future<void> importNoteFromDrive(drive.File file) async {
    if (!driveService.isSignedIn) return;

    final content = await driveService.downloadFileContent(file.id!);
    final title = (file.name ?? 'Untitled').replaceAll('.md', '');

    // Create a new note with a new local ID
    final newNote = Note(
      id: Random().nextInt(100000).toString(),
      title: title,
      content: content,
      date: file.modifiedTime ?? DateTime.now(),
    );

    await addOrUpdateNote(newNote);
    _updateSyncState(newNote.id, file.id, 'Imported');
    selectNote(newNote.id);
  }
}