import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:noteker/models/note.dart';
import 'package:noteker/widgets/sync_icon.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onInfo;
  final SyncStatus? status;

  const NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
    this.onInfo,
    this.status,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              note.content,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat.yMMMd().format(note.date),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: status != null
                            ? SyncIcon(status: status!)
                            : const SizedBox(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'Sync info',
                        icon: Icon(Icons.info_outline, size: 16),
                        onPressed: onInfo,
                        splashRadius: 18,
                      ),
                    ),
                    SizedBox(
                      height: 28,
                      width: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.delete_outline, size: 18),
                        onPressed: onDelete,
                        splashRadius: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
