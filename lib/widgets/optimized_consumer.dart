import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gamification_provider.dart';
import '../providers/theme_provider.dart';

/// Optimized consumer widgets that only rebuild when specific properties change
/// This reduces unnecessary widget rebuilds and improves performance

/// Selector for theme-related changes
class ThemeSelector<T> extends StatelessWidget {
  const ThemeSelector({
    required this.selector,
    required this.builder,
    super.key,
    this.child,
  });

  final T Function(ThemeProvider) selector;
  final Widget Function(BuildContext, T, Widget?) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Selector<ThemeProvider, T>(
    selector: (context, themeProvider) => selector(themeProvider),
    builder: builder,
    child: child,
  );
}

/// Selector for gamification-related changes
class GamificationSelector<T> extends StatelessWidget {
  const GamificationSelector({
    required this.selector,
    required this.builder,
    super.key,
    this.child,
  });

  final T Function(GamificationProvider) selector;
  final Widget Function(BuildContext, T, Widget?) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Selector<GamificationProvider, T>(
    selector: (context, gamificationProvider) => selector(gamificationProvider),
    builder: builder,
    child: child,
  );
}

/// Optimized theme consumer that only rebuilds when theme changes
class OptimizedThemeConsumer extends StatelessWidget {
  const OptimizedThemeConsumer({
    required this.builder,
    super.key,
    this.child,
  });

  final Widget Function(BuildContext, ThemeData) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ThemeSelector<ThemeData>(
    selector: (themeProvider) => themeProvider.currentTheme,
    builder: (context, theme, child) => builder(context, theme),
    child: child,
  );
}

/// Optimized XP display that only rebuilds when XP changes
class OptimizedXpDisplay extends StatelessWidget {
  const OptimizedXpDisplay({
    required this.builder,
    super.key,
  });

  final Widget Function(BuildContext, int, int) builder;

  @override
  Widget build(BuildContext context) => GamificationSelector<({int xp, int level})>(
    selector: (gamificationProvider) => (
      xp: gamificationProvider.xp,
      level: gamificationProvider.level,
    ),
    builder: (context, data, child) => builder(context, data.xp, data.level),
  );
}

/// Optimized achievement display that only rebuilds when achievements change
class OptimizedAchievementDisplay extends StatelessWidget {
  const OptimizedAchievementDisplay({
    required this.builder,
    super.key,
  });

  final Widget Function(BuildContext, Set<String>) builder;

  @override
  Widget build(BuildContext context) => GamificationSelector<Set<String>>(
    selector: (gamificationProvider) => gamificationProvider.unlocked,
    builder: (context, unlocked, child) => builder(context, unlocked),
  );
}

/// Multi-selector for complex state dependencies
class MultiProviderSelector<T1, T2, R> extends StatelessWidget {
  const MultiProviderSelector({
    required this.selector1,
    required this.selector2,
    required this.combiner,
    required this.builder,
    super.key,
    this.child,
  });

  final T1 Function(BuildContext) selector1;
  final T2 Function(BuildContext) selector2;
  final R Function(T1, T2) combiner;
  final Widget Function(BuildContext, R, Widget?) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Consumer2<ThemeProvider, GamificationProvider>(
    builder: (context, themeProvider, gamificationProvider, child) {
      final value1 = selector1(context);
      final value2 = selector2(context);
      final combined = combiner(value1, value2);
      return builder(context, combined, child);
    },
    child: child,
  );
}

/// Mixin to add optimized provider access to widgets
mixin OptimizedProviderMixin<T extends StatefulWidget> on State<T> {
  /// Watch only specific properties of a provider
  R select<P extends ChangeNotifier, R>(R Function(P) selector) => context.select<P, R>(selector);

  /// Read provider without listening to changes
  P read<P extends ChangeNotifier>() => context.read<P>();

  /// Watch provider for all changes (use sparingly)
  P watch<P extends ChangeNotifier>() => context.watch<P>();
}

/// Performance monitoring widget to track rebuild frequency
class RebuildTracker extends StatefulWidget {
  const RebuildTracker({
    required this.child,
    required this.name,
    super.key,
    this.enabled = false, // Only enable in debug mode when needed
  });

  final Widget child;
  final String name;
  final bool enabled;

  @override
  State<RebuildTracker> createState() => _RebuildTrackerState();
}

class _RebuildTrackerState extends State<RebuildTracker> {
  int _buildCount = 0;
  DateTime? _lastBuild;

  @override
  Widget build(BuildContext context) {
    if (widget.enabled) {
      _buildCount++;
      final now = DateTime.now();
      final timeSinceLastBuild = _lastBuild != null 
          ? now.difference(_lastBuild!).inMilliseconds 
          : 0;
      _lastBuild = now;
      
      debugPrint(
        'RebuildTracker[${widget.name}]: Build #$_buildCount '
        '(${timeSinceLastBuild}ms since last)',
      );
    }
    
    return widget.child;
  }
}
