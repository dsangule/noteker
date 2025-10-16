import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:noteker/providers/theme_provider.dart';
import 'package:noteker/providers/gamification_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, tp, _) {
          final isDark = tp.currentTheme.brightness == Brightness.dark;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: const Text('Dark mode'),
                trailing: Switch(
                  value: isDark,
                  onChanged: (_) => tp.toggleDark(),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Use dynamic color'),
                subtitle: const Text('Adopt system accent colors when available'),
                trailing: Switch(
                  value: tp.useDynamicColor,
                  onChanged: (v) => tp.setUseDynamicColor(v),
                ),
              ),
              const SizedBox(height: 8),
              Text('Font size', style: theme.textTheme.titleMedium),
              Slider(
                value: tp.fontScale,
                min: 0.8,
                max: 1.6,
                divisions: 8,
                label: tp.fontScale.toStringAsFixed(1),
                onChanged: (v) => tp.setFontScale(v),
              ),
              const Divider(height: 32),
              Consumer<GamificationProvider>(
                builder: (context, gp, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Achievements', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ...gp.allAchievements.map((a) {
                        final unlocked = gp.unlocked.contains(a.id);
                        return ListTile(
                          leading: Icon(
                            unlocked ? Icons.emoji_events : Icons.lock_outline,
                            color: unlocked ? theme.colorScheme.primary : theme.disabledColor,
                          ),
                          title: Text(a.title),
                          subtitle: Text(a.description),
                          trailing: unlocked ? const Text('Unlocked') : const Text('Locked'),
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
