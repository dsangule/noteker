import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GamificationProvider extends ChangeNotifier {
  static const _kXpKey = 'gamify_xp_v1';
  static const _kLastActiveKey = 'gamify_last_active_v1';
  static const _kStreakKey = 'gamify_streak_v1';
  static const _kUnlockedKey = 'gamify_unlocked_v1';

  int _xp = 0;
  int _streak = 0;
  DateTime? _lastActive;
  final Set<String> _unlocked = <String>{};
  final List<String> _recentUnlocks = <String>[];

  int get xp => _xp;
  int get level => 1 + (_xp ~/ 1000);
  int get nextLevelXp => (level * 1000);
  double get progressToNext => (_xp - ((level - 1) * 1000)) / 1000.0;
  int get streak => _streak;
  Set<String> get unlocked => _unlocked;

  // Basic achievements based on XP and streak
  List<Achievement> get allAchievements => [
        Achievement(
          id: 'first_steps',
          title: 'First Steps',
          description: 'Earn your first 100 XP',
          predicate: AchievementPredicate.xpAtLeast(100),
        ),
        Achievement(
          id: 'note_master',
          title: 'Note Master',
          description: 'Reach Level 3 (2000 XP)',
          predicate: AchievementPredicate.xpAtLeast(2000),
        ),
        Achievement(
          id: 'on_fire',
          title: 'On Fire',
          description: 'Maintain a 7-day streak',
          predicate: AchievementPredicate.streakAtLeast(7),
        ),
        Achievement(
          id: 'unstoppable',
          title: 'Unstoppable',
          description: 'Maintain a 30-day streak',
          predicate: AchievementPredicate.streakAtLeast(30),
        ),
      ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _xp = prefs.getInt(_kXpKey) ?? 0;
    _streak = prefs.getInt(_kStreakKey) ?? 0;
    final last = prefs.getString(_kLastActiveKey);
    if (last != null) _lastActive = DateTime.tryParse(last);
    final list = prefs.getStringList(_kUnlockedKey) ?? <String>[];
    _unlocked
      ..clear()
      ..addAll(list);
    _updateStreakIfNeeded();
    _evaluateAchievements();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kXpKey, _xp);
    await prefs.setInt(_kStreakKey, _streak);
    await prefs.setString(_kLastActiveKey, DateTime.now().toIso8601String());
    await prefs.setStringList(_kUnlockedKey, _unlocked.toList());
  }

  void _updateStreakIfNeeded() {
    final now = DateTime.now();
    if (_lastActive == null) {
      _streak = 1;
      _lastActive = now;
      return;
    }
    final last = DateTime(_lastActive!.year, _lastActive!.month, _lastActive!.day);
    final today = DateTime(now.year, now.month, now.day);
    final diffDays = today.difference(last).inDays;
    if (diffDays == 0) return; // already counted today
    if (diffDays == 1) {
      _streak += 1;
    } else if (diffDays > 1) {
      _streak = 1; // reset streak
    }
    _lastActive = now;
  }

  Future<void> addXp(int amount) async {
    _xp += amount;
    _updateStreakIfNeeded();
    _evaluateAchievements();
    await _persist();
    notifyListeners();
  }

  void _evaluateAchievements() {
    for (final a in allAchievements) {
      if (_unlocked.contains(a.id)) continue;
      if (a.predicate.isSatisfied(xp: _xp, streak: _streak)) {
        _unlocked.add(a.id);
        _recentUnlocks.add(a.id);
      }
    }
  }

  Achievement? takeNextUnlock() {
    if (_recentUnlocks.isEmpty) return null;
    final id = _recentUnlocks.removeAt(0);
    return allAchievements.firstWhere((a) => a.id == id, orElse: () => Achievement(id: id, title: 'Achievement', description: '', predicate: AchievementPredicate.xpAtLeast(0)));
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementPredicate predicate;
  const Achievement({required this.id, required this.title, required this.description, required this.predicate});
}

class AchievementPredicate {
  final int? xpAtLeastValue;
  final int? streakAtLeastValue;
  const AchievementPredicate._({this.xpAtLeastValue, this.streakAtLeastValue});

  factory AchievementPredicate.xpAtLeast(int v) => AchievementPredicate._(xpAtLeastValue: v);
  factory AchievementPredicate.streakAtLeast(int v) => AchievementPredicate._(streakAtLeastValue: v);

  bool isSatisfied({required int xp, required int streak}) {
    if (xpAtLeastValue != null && xp < xpAtLeastValue!) return false;
    if (streakAtLeastValue != null && streak < streakAtLeastValue!) return false;
    return true;
  }
}


