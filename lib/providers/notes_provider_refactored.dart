import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';
import '../services/note_repository.dart';
import '../utils/markdown_helpers.dart';

/// Simplified NotesProvider focused on core note management
class NotesProvider extends ChangeNotifier {
  NotesProvider() {
    _init();
  }

  final NoteRepository _noteRepo = SharedPrefsNoteRepository();

  // Core state
  final List<Note> _notes = [];
  String? _selectedNoteId;
  String _searchQuery = '';
  bool _sortByDateDesc = true;

  // UI state for wide-screen editor
  bool _isPreview = false;
  bool _isSplit = false;
  bool _mathEnabled = true;

  // Getters
  List<Note> get notes => List.unmodifiable(_notes);
  String? get selectedNoteId => _selectedNoteId;
  String get searchQuery => _searchQuery;
  bool get sortByDateDesc => _sortByDateDesc;
  bool get isPreview => _isPreview;
  bool get isSplit => _isSplit;
  bool get mathEnabled => _mathEnabled;

  Note? get selectedNote {
    if (_selectedNoteId == null) {
      return null;
    }
    try {
      return _notes.firstWhere((n) => n.id == _selectedNoteId);
    } on Exception {
      return null;
    }
  }

  List<Note> get filteredAndSortedNotes {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = _notes.where((n) {
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

  Future<void> _init() async {
    // Load persisted notes
    final loaded = await _noteRepo.loadNotes();
    _notes
      ..clear()
      ..addAll(loaded)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Load math preference
    final prefs = await SharedPreferences.getInstance();
    _mathEnabled = prefs.getBool(kPrefKeyMathEnabled) ?? true;

    notifyListeners();
  }

  // Public methods to modify state
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortBy({required bool byDate}) {
    _sortByDateDesc = byDate;
    notifyListeners();
  }

  void selectNote(String? noteId) {
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

    // Persist notes
    await _noteRepo.saveNotes(_notes);
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((note) => note.id == id);
    if (_selectedNoteId == id) {
      _selectedNoteId = null;
    }
    notifyListeners();
    await _noteRepo.saveNotes(_notes);
  }

  // Demo and Walkthrough logic
  Future<void> ensureDemoNote(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final demoSeen = prefs.getBool('demo_shown_v1') ?? false;
    if (!demoSeen) {
      // Demo note creation logic would go here
      // This is simplified for the refactored version
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
}
