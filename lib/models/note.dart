class Note {
  final String id;
  String title;
  String content;
  final DateTime date;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
  });
}

enum SyncStatus { idle, syncing, synced, error }
