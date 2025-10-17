import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_handler.dart';
import '../utils/logger.dart';

const String _kThemePrefKey = 'pref_theme_brightness_v1';
const String _kFontScalePrefKey = 'pref_font_scale_v1';
const String _kUseDynamicPrefKey = 'pref_use_dynamic_color_v1';

/// Safely applies font scaling to a TextTheme, handling null fontSize values
TextTheme _applyFontScaleSafely(TextTheme textTheme, double fontScale) {
  try {
    return textTheme.apply(fontSizeFactor: fontScale);
  } on Object {
    // If apply fails due to null fontSize values, manually scale each style
    return TextTheme(
      displayLarge: _scaleTextStyle(textTheme.displayLarge, fontScale),
      displayMedium: _scaleTextStyle(textTheme.displayMedium, fontScale),
      displaySmall: _scaleTextStyle(textTheme.displaySmall, fontScale),
      headlineLarge: _scaleTextStyle(textTheme.headlineLarge, fontScale),
      headlineMedium: _scaleTextStyle(textTheme.headlineMedium, fontScale),
      headlineSmall: _scaleTextStyle(textTheme.headlineSmall, fontScale),
      titleLarge: _scaleTextStyle(textTheme.titleLarge, fontScale),
      titleMedium: _scaleTextStyle(textTheme.titleMedium, fontScale),
      titleSmall: _scaleTextStyle(textTheme.titleSmall, fontScale),
      bodyLarge: _scaleTextStyle(textTheme.bodyLarge, fontScale),
      bodyMedium: _scaleTextStyle(textTheme.bodyMedium, fontScale),
      bodySmall: _scaleTextStyle(textTheme.bodySmall, fontScale),
      labelLarge: _scaleTextStyle(textTheme.labelLarge, fontScale),
      labelMedium: _scaleTextStyle(textTheme.labelMedium, fontScale),
      labelSmall: _scaleTextStyle(textTheme.labelSmall, fontScale),
    );
  }
}

/// Safely scales an individual TextStyle, providing a default fontSize if null
TextStyle? _scaleTextStyle(TextStyle? style, double fontScale) {
  if (style == null) {
    return null;
  }
  
  // If fontSize is null, provide a reasonable default before scaling
  final fontSize = style.fontSize ?? 14.0;
  return style.copyWith(fontSize: fontSize * fontScale);
}

ThemeData _buildTheme({
  required Brightness brightness,
  ColorScheme? dynamicScheme,
  double fontScale = 1.0,
}) {
  final scheme = dynamicScheme ?? ColorScheme.fromSeed(
    seedColor: Colors.teal,
    brightness: brightness,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
  final baseTextTheme = GoogleFonts.interTextTheme(base.textTheme);
  final textTheme = fontScale == 1.0 
      ? baseTextTheme 
      : _applyFontScaleSafely(baseTextTheme, fontScale);
  return base.copyWith(textTheme: textTheme);
}

class ThemeProvider extends ChangeNotifier with LoggerMixin {
  ThemeProvider({ThemeData? initial}) : _current = initial ?? _buildTheme(brightness: Brightness.light);

  ThemeData _current;
  ColorScheme? _dynamicLight;
  ColorScheme? _dynamicDark;
  double _fontScale = 1.0;
  bool _useDynamic = true;

  ThemeData get currentTheme => _current;
  double get fontScale => _fontScale;
  bool get useDynamicColor => _useDynamic;

  Future<void> setTheme(ThemeData t) async {
    try {
      _current = t;
      logInfo('Theme changed to ${t.brightness.name}');
      
      // Only notify if there are still listeners (widgets mounted)
      if (hasListeners) {
        notifyListeners();
      } else {
        logWarning('Theme changed but no listeners remain');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kThemePrefKey,
        t.brightness == Brightness.dark ? 'dark' : 'light',
      );
    } catch (error, stackTrace) {
      logError('Failed to set theme', error: error, stackTrace: stackTrace);
      throw StorageException('Failed to save theme preference', originalError: error);
    }
  }

  Future<void> toggleDark() async {
    final next = _current.brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    final dynamicForNext = _useDynamic ? (next == Brightness.dark ? _dynamicDark : _dynamicLight) : null;
    await setTheme(_buildTheme(brightness: next, dynamicScheme: dynamicForNext, fontScale: _fontScale));
  }

  static Future<ThemeData> loadInitialTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_kThemePrefKey);
      final brightness = stored == 'dark' ? Brightness.dark : Brightness.light;
      final font = prefs.getDouble(_kFontScalePrefKey) ?? 1.0;
      final useDynamic = prefs.getBool(_kUseDynamicPrefKey) ?? true;
      
      Logger.info('Loaded initial theme: ${brightness.name}, font scale: $font, dynamic: $useDynamic');
      
      // Dynamic schemes are applied later when available; return base theme for now
      return _buildTheme(brightness: brightness, fontScale: font);
    } on Exception catch (error, stackTrace) {
      Logger.error('Failed to load initial theme, using default', error: error, stackTrace: stackTrace);
      return _buildTheme(brightness: Brightness.light);
    }
  }

  Future<void> applyDynamicSchemes({ColorScheme? light, ColorScheme? dark}) async {
    try {
      // Only update if schemes have actually changed
      if (_dynamicLight == light && _dynamicDark == dark) {
        return;
      }
      
      _dynamicLight = light;
      _dynamicDark = dark;
      logInfo('Applied dynamic color schemes');
      
      // Rebuild current theme to reflect dynamic colors while preserving brightness
      final currentBrightness = _current.brightness;
      final scheme = _useDynamic
          ? (currentBrightness == Brightness.dark ? _dynamicDark : _dynamicLight)
          : null;
      
      // Update theme directly without going through setTheme to avoid SharedPreferences call
      _current = _buildTheme(brightness: currentBrightness, dynamicScheme: scheme, fontScale: _fontScale);
      notifyListeners();
    } on Exception catch (error, stackTrace) {
      logError('Failed to apply dynamic schemes', error: error, stackTrace: stackTrace);
      // Continue with existing theme if dynamic scheme application fails
    }
  }

  Future<void> setFontScale(double scale) async {
    try {
      _fontScale = scale.clamp(0.8, 1.6);
      logInfo('Font scale changed to $_fontScale');
      
      final b = _current.brightness;
      final scheme = _useDynamic ? (b == Brightness.dark ? _dynamicDark : _dynamicLight) : null;
      await setTheme(_buildTheme(brightness: b, dynamicScheme: scheme, fontScale: _fontScale));
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kFontScalePrefKey, _fontScale);
    } catch (error, stackTrace) {
      logError('Failed to set font scale', error: error, stackTrace: stackTrace);
      throw StorageException('Failed to save font scale preference', originalError: error);
    }
  }

  Future<void> setUseDynamicColor({required bool value}) async {
    try {
      _useDynamic = value;
      logInfo('Dynamic color usage changed to $_useDynamic');
      
      final b = _current.brightness;
      final scheme = _useDynamic ? (b == Brightness.dark ? _dynamicDark : _dynamicLight) : null;
      await setTheme(_buildTheme(brightness: b, dynamicScheme: scheme, fontScale: _fontScale));
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kUseDynamicPrefKey, _useDynamic);
    } catch (error, stackTrace) {
      logError('Failed to set dynamic color preference', error: error, stackTrace: stackTrace);
      throw StorageException('Failed to save dynamic color preference', originalError: error);
    }
  }
}
