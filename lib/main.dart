import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'screens/home_screen.dart';
import 'l10n/app_localizations.dart';
import 'providers/theme_provider.dart';
import 'providers/gamification_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialTheme = await ThemeProvider.loadInitialTheme();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(initial: initialTheme)),
        ChangeNotifierProvider(create: (_) => GamificationProvider()..load()),
      ],
      child: const NotesApp(),
    ),
  );
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (dynamicLight, dynamicDark) {
        // Propagate dynamic schemes to ThemeProvider if available
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        // Fire-and-forget; ThemeProvider will notify listeners if it changes theme
        themeProvider.applyDynamicSchemes(light: dynamicLight, dark: dynamicDark);

        return Consumer<ThemeProvider>(
          child: const HomeScreen(),
          builder: (context, themeProvider, child) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Minimalist Notes',
          theme: themeProvider.currentTheme,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
            home: child,
          ),
        );
      },
    );
  }
}
