import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error, critical }

class Logger {
  static const String _name = 'Noteker';
  
  static void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  static void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  static void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  static void critical(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.critical, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  static void _log(
    LogLevel level, 
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode || level.index >= LogLevel.warning.index) {
      final timestamp = DateTime.now().toIso8601String();
      final tagStr = tag != null ? '[$tag] ' : '';
      final levelStr = level.name.toUpperCase().padRight(8);
      final logMessage = '$timestamp $levelStr $tagStr$message';
      
      // Use developer.log for better debugging experience
      developer.log(
        logMessage,
        name: _name,
        level: _getLevelValue(level),
        error: error,
        stackTrace: stackTrace,
      );
      
      // In release mode, you might want to send critical errors to a crash reporting service
      if (!kDebugMode && level == LogLevel.critical) {
        _reportCriticalError(message, error, stackTrace);
      }
    }
  }
  
  static int _getLevelValue(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
      case LogLevel.critical:
        return 1200;
    }
  }
  
  static void _reportCriticalError(String message, Object? error, StackTrace? stackTrace) {
    // Fallback logging for debug
    debugPrint('CRITICAL ERROR: $message');
    if (error != null) {
      debugPrint('Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    }
  }
}

/// Mixin to add logging capabilities to any class
mixin LoggerMixin {
  String get loggerTag => runtimeType.toString();
  
  void logDebug(String message, {Object? error, StackTrace? stackTrace}) {
    Logger.debug(message, tag: loggerTag, error: error, stackTrace: stackTrace);
  }
  
  void logInfo(String message, {Object? error, StackTrace? stackTrace}) {
    Logger.info(message, tag: loggerTag, error: error, stackTrace: stackTrace);
  }
  
  void logWarning(String message, {Object? error, StackTrace? stackTrace}) {
    Logger.warning(message, tag: loggerTag, error: error, stackTrace: stackTrace);
  }
  
  void logError(String message, {Object? error, StackTrace? stackTrace}) {
    Logger.error(message, tag: loggerTag, error: error, stackTrace: stackTrace);
  }
  
  void logCritical(String message, {Object? error, StackTrace? stackTrace}) {
    Logger.critical(message, tag: loggerTag, error: error, stackTrace: stackTrace);
  }
}
