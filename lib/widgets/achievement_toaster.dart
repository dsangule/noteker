import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:noteker/providers/gamification_provider.dart';

class AchievementToaster extends StatefulWidget {
  const AchievementToaster({super.key});

  @override
  State<AchievementToaster> createState() => _AchievementToasterState();
}

class _AchievementToasterState extends State<AchievementToaster>
    with SingleTickerProviderStateMixin {
  AchievementBanner? _current;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  Future<void> _pump() async {
    if (!mounted) return;
    final gp = context.read<GamificationProvider>();
    final next = gp.takeNextUnlock();
    if (next == null) return;
    setState(() {
      _current = AchievementBanner(
        title: next.title,
        description: next.description,
      );
    });
    await _controller.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await _controller.reverse();
    setState(() {
      _current = null;
    });
    await _pump();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_current == null) return const SizedBox.shrink();
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: _current!,
    );
  }
}

class AchievementBanner extends StatelessWidget {
  final String title;
  final String description;
  const AchievementBanner({required this.title, required this.description, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.emoji_events, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(description, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


