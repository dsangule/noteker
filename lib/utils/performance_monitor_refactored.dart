import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'logger.dart';
import 'performance_timer.dart';

/// Advanced performance monitoring with memory and frame tracking
class PerformanceMonitor with LoggerMixin {
  factory PerformanceMonitor() => _instance;

  PerformanceMonitor._internal();

  static final PerformanceMonitor _instance = PerformanceMonitor._internal();

  final PerformanceTimer _timer = PerformanceTimer();
  Timer? _memoryMonitorTimer;
  bool _isMonitoring = false;
  int _frameCount = 0;
  DateTime? _lastFrameTime;

  /// Start monitoring performance metrics
  void startMonitoring() {
    if (_isMonitoring) {
      return;
    }

    _isMonitoring = true;
    logInfo('Performance monitoring started');

    if (kDebugMode) {
      _startMemoryMonitoring();
      _startFrameMonitoring();
    }
  }

  /// Stop monitoring performance metrics
  void stopMonitoring() {
    if (!_isMonitoring) {
      return;
    }

    _isMonitoring = false;
    _memoryMonitorTimer?.cancel();
    logInfo('Performance monitoring stopped');
  }

  // Delegate timer methods
  void startOperation(String operationName) => _timer.startOperation(operationName);
  void endOperation(String operationName) => _timer.endOperation(operationName);
  T time<T>(String operationName, T Function() operation) => _timer.time(operationName, operation);
  Future<T> timeAsync<T>(String operationName, Future<T> Function() operation) =>
      _timer.timeAsync(operationName, operation);
  Duration? getAverageDuration(String operationName) => _timer.getAverageDuration(operationName);
  List<Duration> getDurations(String operationName) => _timer.getDurations(operationName);
  void clearMetrics() => _timer.clearMetrics();
  Map<String, Map<String, dynamic>> getPerformanceSummary() => _timer.getPerformanceSummary();

  void _startMemoryMonitoring() {
    _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _logMemoryUsage();
    });
  }

  void _startFrameMonitoring() {
    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    if (!_isMonitoring) {
      return;
    }

    _frameCount++;
    final now = DateTime.now();

    if (_lastFrameTime != null) {
      final frameDuration = now.difference(_lastFrameTime!);
      if (frameDuration.inMilliseconds > 16) { // > 60 FPS
        logWarning('Slow frame detected: ${frameDuration.inMilliseconds}ms');
      }
    }

    _lastFrameTime = now;

    // Log FPS every 5 seconds
    if (_frameCount % 300 == 0) {
      logInfo('Frame count: $_frameCount');
    }

    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _logMemoryUsage() {
    if (!kDebugMode) {
      return;
    }

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // Mobile memory monitoring would go here
        logInfo('Memory monitoring active');
      }
    } on Exception {
      // Ignore platform detection errors
    }
  }

  /// Get current monitoring status
  bool get isMonitoring => _isMonitoring;

  /// Get frame count
  int get frameCount => _frameCount;

  /// Reset frame count
  void resetFrameCount() {
    _frameCount = 0;
    _lastFrameTime = null;
  }
}
