import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../providers/gamification_provider.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor({required this.onChanged, this.note, super.key});

  final void Function(Note) onChanged; // autosave callback
  final Note? note;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _noteId;

  @override
  void initState() {
    super.initState();
    _noteId = widget.note?.id ?? Random().nextInt(100000).toString();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );

    // Autosave on change
    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onChanged);
    _contentController.removeListener(_onChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If a different note was provided, update controllers and id so the
    // editor reflects the newly selected note immediately.
    if (widget.note?.id != oldWidget.note?.id) {
      _noteId = widget.note?.id ?? Random().nextInt(100000).toString();
      // Update controllers without triggering the autosave listener
      _titleController.removeListener(_onChanged);
      _contentController.removeListener(_onChanged);
      _titleController.text = widget.note?.title ?? '';
      _contentController.text = widget.note?.content ?? '';
      _titleController.addListener(_onChanged);
      _contentController.addListener(_onChanged);
    }
  }

  void _onChanged() {
    final newNote = Note(
      id: _noteId,
      title: _titleController.text.isEmpty
          ? 'Untitled Note'
          : _titleController.text,
      content: _contentController.text,
      date: DateTime.now(),
    );
    widget.onChanged(newNote);
    // Reward small XP for edits; throttle by simple heuristic (length changes)
    if (mounted && (_titleController.text.length + _contentController.text.length) % 100 == 0) {
      context.read<GamificationProvider>().addXp(5);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
    child: Column(
      children: [
        TextField(
          controller: _titleController,
          autofocus: widget.note == null,
          style: Theme.of(context).textTheme.headlineMedium,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Title',
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _contentController,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: const InputDecoration(
            hintText: 'Start writing...',
            border: InputBorder.none,
          ),
          maxLines: null,
          keyboardType: TextInputType.multiline,
        ),
      ],
    ),
  );
}

class NoteEditorScreen extends StatelessWidget {
  const NoteEditorScreen({required this.onChanged, this.note, super.key});

  final void Function(Note) onChanged;
  final Note? note;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    body: NoteEditor(note: note, onChanged: onChanged),
  );
}
