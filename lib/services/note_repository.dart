import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';

abstract class NoteRepository {
  Future<List<Note>> loadNotes();
  Future<void> saveNotes(List<Note> notes);
}

class SharedPrefsNoteRepository implements NoteRepository {
  static const _kNotesKey = 'notes_v1';

  @override
  Future<List<Note>> loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kNotesKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        return [];
      }
      final decoded = json.decode(jsonStr) as List<dynamic>;
      return decoded.map((e) {
        final map = e as Map<String, dynamic>;
        return Note(
          id: map['id'] as String,
          title: map['title'] as String,
          content: map['content'] as String,
          date: DateTime.parse(map['date'] as String),
        );
      }).toList();
    } on Exception catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = notes.map((n) => {
          'id': n.id,
          'title': n.title,
          'content': n.content,
          'date': n.date.toIso8601String(),
        }).toList();
    await prefs.setString(_kNotesKey, json.encode(encoded));
  }
}
