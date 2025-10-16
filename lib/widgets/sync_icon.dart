import 'package:flutter/material.dart';
import 'package:noteker/models/note.dart';

class SyncIcon extends StatelessWidget {
  final SyncStatus status;
  const SyncIcon({required this.status, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: SizedBox(
        key: ValueKey<SyncStatus>(status),
        width: 22,
        height: 22,
        child: Center(
          child: Builder(
            builder: (context) {
              switch (status) {
                case SyncStatus.syncing:
                  return SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color?>(
                        Theme.of(context).iconTheme.color,
                      ),
                    ),
                  );
                case SyncStatus.synced:
                  return Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Theme.of(context).colorScheme.secondary,
                  );
                case SyncStatus.error:
                  return Icon(
                    Icons.error_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  );
                case SyncStatus.idle:
                  return const SizedBox(width: 18, height: 18);
              }
            },
          ),
        ),
      ),
    );
  }
}
