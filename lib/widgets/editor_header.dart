import 'package:flutter/material.dart';
import 'package:noteker/models/note.dart';

class EditorHeader extends StatelessWidget {
  final Note note;
  final String? syncText;
  final void Function() onTogglePreview;
  final bool isPreview;
  final void Function() onToggleMath;
  final bool mathEnabled;

  const EditorHeader({
    required this.note,
    required this.syncText,
    required this.onTogglePreview,
    required this.isPreview,
    required this.onToggleMath,
    required this.mathEnabled,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${note.date.year}-${note.date.month}-${note.date.day}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        Row(
          children: [
            if (syncText != null && syncText!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(syncText!, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 12),
            ],
            IconButton(
              icon: Icon(isPreview ? Icons.edit : Icons.remove_red_eye),
              tooltip: isPreview ? 'Edit' : 'Preview',
              onPressed: onTogglePreview,
            ),
            IconButton(
              icon: Icon(mathEnabled ? Icons.functions : Icons.functions_outlined),
              tooltip: 'Math',
              onPressed: onToggleMath,
            ),
          ],
        )
      ],
    );
  }
}


