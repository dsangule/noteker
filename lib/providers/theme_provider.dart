import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

const String _kThemePrefKey = 'pref_theme_brightness_v1';
const String _kFontScalePrefKey = 'pref_font_scale_v1';
const String _kUseDynamicPrefKey = 'pref_use_dynamic_color_v1';

ThemeData _buildTheme({
  required Brightness brightness,
  ColorScheme? dynamicScheme,
  double fontScale = 1.0,
}) {
  final ColorScheme scheme = dynamicScheme ?? ColorScheme.fromSeed(
    seedColor: Colors.teal,
    brightness: brightness,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(fontSizeFactor: fontScale);
  return base.copyWith(textTheme: textTheme);
}

class ThemeProvider extends ChangeNotifier {
  ThemeData _current;
  ColorScheme? _dynamicLight;
  ColorScheme? _dynamicDark;
  double _fontScale = 1.0;
  bool _useDynamic = true;

  ThemeProvider({ThemeData? initial}) : _current = initial ?? _buildTheme(brightness: Brightness.light);

  ThemeData get currentTheme => _current;
  double get fontScale => _fontScale;
  bool get useDynamicColor => _useDynamic;

  Future<void> setTheme(ThemeData t) async {
    _current = t;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kThemePrefKey,
      t.brightness == Brightness.dark ? 'dark' : 'light',
    );
  }

  Future<void> toggleDark() async {
    final Brightness next = _current.brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    final ColorScheme? dynamicForNext = (_useDynamic) ? (next == Brightness.dark ? _dynamicDark : _dynamicLight) : null;
    await setTheme(_buildTheme(brightness: next, dynamicScheme: dynamicForNext, fontScale: _fontScale));
  }

  static Future<ThemeData> loadInitialTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemePrefKey);
    final brightness = stored == 'dark' ? Brightness.dark : Brightness.light;
    final font = prefs.getDouble(_kFontScalePrefKey) ?? 1.0;
    // Dynamic schemes are applied later when available; return base theme for now
    return _buildTheme(brightness: brightness, fontScale: font);
  }

  Future<void> applyDynamicSchemes({ColorScheme? light, ColorScheme? dark}) async {
    _dynamicLight = light;
    _dynamicDark = dark;
    // Rebuild current theme to reflect dynamic colors while preserving brightness
    final Brightness currentBrightness = _current.brightness;
    final ColorScheme? scheme = _useDynamic
        ? (currentBrightness == Brightness.dark ? _dynamicDark : _dynamicLight)
        : null;
    await setTheme(_buildTheme(brightness: currentBrightness, dynamicScheme: scheme, fontScale: _fontScale));
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale.clamp(0.8, 1.6);
    final Brightness b = _current.brightness;
    final ColorScheme? scheme = _useDynamic ? (b == Brightness.dark ? _dynamicDark : _dynamicLight) : null;
    await setTheme(_buildTheme(brightness: b, dynamicScheme: scheme, fontScale: _fontScale));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontScalePrefKey, _fontScale);
  }

  Future<void> setUseDynamicColor(bool value) async {
    _useDynamic = value;
    final Brightness b = _current.brightness;
    final ColorScheme? scheme = _useDynamic ? (b == Brightness.dark ? _dynamicDark : _dynamicLight) : null;
    await setTheme(_buildTheme(brightness: b, dynamicScheme: scheme, fontScale: _fontScale));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseDynamicPrefKey, _useDynamic);
  }
}
