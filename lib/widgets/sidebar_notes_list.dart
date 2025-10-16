import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:noteker/models/note.dart';
import 'package:noteker/widgets/sync_icon.dart';

class SidebarNotesList extends StatelessWidget {
  final List<Note> notes;
  final String? selectedId;
  final void Function(Note) onSelect;
  final void Function(String noteId) onDelete;
  final void Function(String noteId) onShowSync;
  final Map<String, dynamic> syncStatus; // expects SyncStatus values

  const SidebarNotesList({
    required this.notes,
    required this.selectedId,
    required this.onSelect,
    required this.onDelete,
    required this.onShowSync,
    required this.syncStatus,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_add_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('Create your first note', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Tap the + button to start writing', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final note = notes[index];
        final isSelected = note.id == selectedId;
        return ListTile(
          selected: isSelected,
          title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(DateFormat.yMMMd().format(note.date), style: Theme.of(context).textTheme.labelSmall),
          onTap: () => onSelect(note),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: SyncIcon(status: syncStatus[note.id] ?? SyncStatus.idle),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Sync info',
                icon: const Icon(Icons.info_outline, size: 18),
                onPressed: () => onShowSync(note.id),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(note.id),
              ),
            ],
          ),
        );
      },
    );
  }
}


