import 'package:flutter/foundation.dart';
import 'logger.dart';
import 'performance_monitor.dart';

/// Development utilities for debugging and testing
class DevUtils {
  static bool get isDebugMode => kDebugMode;
  static bool get isReleaseMode => kReleaseMode;
  static bool get isProfileMode => kProfileMode;

  /// Enable debug features
  static void enableDebugFeatures() {
    if (!kDebugMode) {
      return;
    }
    
    Logger.info('Debug features enabled');
    PerformanceMonitor().startMonitoring();
    
    // Add any other debug-specific initialization here
  }

  /// Disable debug features
  static void disableDebugFeatures() {
    if (!kDebugMode) {
      return;
    }
    
    Logger.info('Debug features disabled');
    PerformanceMonitor().stopMonitoring();
  }

  /// Log app startup information
  static void logStartupInfo() {
    Logger.info('=== App Startup Info ===');
    Logger.info('Build mode: ${_getBuildMode()}');
    Logger.info('Platform: ${defaultTargetPlatform.name}');
    Logger.info('Debug mode: $kDebugMode');
    Logger.info('Profile mode: $kProfileMode');
    Logger.info('Release mode: $kReleaseMode');
  }

  /// Print performance summary (debug only)
  static void printPerformanceSummary() {
    if (!kDebugMode) {
      return;
    }
    PerformanceMonitor().logPerformanceSummary();
  }

  /// Clear all debug data
  static void clearDebugData() {
    if (!kDebugMode) {
      return;
    }
    
    PerformanceMonitor().clearStats();
    Logger.info('Debug data cleared');
  }

  static String _getBuildMode() {
    if (kDebugMode) {
      return 'Debug';
    }
    if (kProfileMode) {
      return 'Profile';
    }
    if (kReleaseMode) {
      return 'Release';
    }
    return 'Unknown';
  }
}

/// Debug-only assertions and checks
class DebugAssertions {
  /// Assert that a condition is true in debug mode only
  static void debugAssert({required bool condition, required String message}) {
    if (kDebugMode && !condition) {
      Logger.error('Debug assertion failed: $message');
      throw AssertionError(message);
    }
  }

  /// Check for null values in debug mode
  static T checkNotNull<T>(T? value, String parameterName) {
    if (kDebugMode && value == null) {
      final message = 'Parameter $parameterName cannot be null';
      Logger.error(message);
      throw ArgumentError.notNull(parameterName);
    }
    return value!;
  }

  /// Validate state in debug mode
  static void validateState({required bool condition, required String message}) {
    if (kDebugMode && !condition) {
      Logger.error('State validation failed: $message');
      throw StateError(message);
    }
  }
}

/// Mixin for classes that need development utilities
mixin DevUtilsMixin {
  void debugLog(String message) {
    if (kDebugMode) {
      Logger.debug(message, tag: runtimeType.toString());
    }
  }

  void debugAssert({required bool condition, required String message}) {
    DebugAssertions.debugAssert(condition: condition, message: message);
  }

  T debugCheckNotNull<T>(T? value, String parameterName) =>
      DebugAssertions.checkNotNull(value, parameterName);
}
