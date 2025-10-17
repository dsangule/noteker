import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'providers/gamification_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'utils/dev_utils.dart';
import 'utils/error_handler.dart';
import 'utils/logger.dart';
import 'utils/performance_monitor.dart';
import 'widgets/optimized_consumer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    Logger.info('Starting Noteker app');
    
    // Log startup information and enable debug features
    DevUtils.logStartupInfo();
    if (kDebugMode) {
      DevUtils.enableDebugFeatures();
    }
    
    final initialTheme = await PerformanceMonitor().timeAsync(
      'load_initial_theme',
      ThemeProvider.loadInitialTheme,
    );
    
    // Initialize gamification provider properly
    final gamificationProvider = GamificationProvider();
    await gamificationProvider.load();
    
    runApp(
      ErrorBoundary(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider(initial: initialTheme)),
            ChangeNotifierProvider.value(value: gamificationProvider),
          ],
          child: const NotesApp(),
        ),
      ),
    );
  } catch (error, stackTrace) {
    Logger.critical(
      'Failed to start app',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

class NotesApp extends StatefulWidget {
  const NotesApp({super.key});

  @override
  State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> {
  bool _dynamicSchemesApplied = false;

  @override
  Widget build(BuildContext context) => DynamicColorBuilder(
    builder: (dynamicLight, dynamicDark) {
      // Apply dynamic schemes only once and safely
      if (!_dynamicSchemesApplied && (dynamicLight != null || dynamicDark != null)) {
        _dynamicSchemesApplied = true;
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        
        // Use Future.microtask to defer the call safely
        Future.microtask(() {
          if (mounted) {
            themeProvider.applyDynamicSchemes(light: dynamicLight, dark: dynamicDark);
          }
        });
      }

      return OptimizedThemeConsumer(
        builder: (context, theme) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Noteker - Smart Notes',
          theme: theme,
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
          home: const HomeScreen(),
        ),
      );
    },
  );
}
