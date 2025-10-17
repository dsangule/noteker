import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'logger.dart';

/// Performance monitoring utility for tracking app performance metrics
class PerformanceMonitor with LoggerMixin {
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();

  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, List<Duration>> _operationDurations = {};
  Timer? _memoryMonitorTimer;
  bool _isMonitoring = false;

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

  /// Start timing an operation
  void startOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
  }

  /// End timing an operation and log the duration
  void endOperation(String operationName) {
    final startTime = _operationStartTimes.remove(operationName);
    if (startTime == null) {
      logWarning('Attempted to end operation "$operationName" that was not started');
      return;
    }

    final duration = DateTime.now().difference(startTime);
    _operationDurations.putIfAbsent(operationName, () => []).add(duration);
    
    logDebug('Operation "$operationName" completed in ${duration.inMilliseconds}ms');
    
    // Log slow operations
    if (duration.inMilliseconds > 100) {
      logWarning('Slow operation detected: "$operationName" took ${duration.inMilliseconds}ms');
    }
  }

  /// Time an async operation
  Future<T> timeAsync<T>(String operationName, Future<T> Function() operation) async {
    startOperation(operationName);
    try {
      final result = await operation();
      endOperation(operationName);
      return result;
    } catch (error) {
      endOperation(operationName);
      rethrow;
    }
  }

  /// Time a synchronous operation
  T timeSync<T>(String operationName, T Function() operation) {
    startOperation(operationName);
    try {
      final result = operation();
      endOperation(operationName);
      return result;
    } catch (error) {
      endOperation(operationName);
      rethrow;
    }
  }

  /// Get performance statistics for an operation
  OperationStats? getOperationStats(String operationName) {
    final durations = _operationDurations[operationName];
    if (durations == null || durations.isEmpty) {
      return null;
    }

    final totalMs = durations.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
    final avgMs = totalMs.toDouble() / durations.length;
    final minMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
    final maxMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);

    return OperationStats(
      operationName: operationName,
      count: durations.length,
      averageMs: avgMs,
      minMs: minMs,
      maxMs: maxMs,
      totalMs: totalMs,
    );
  }

  /// Get all operation statistics
  Map<String, OperationStats> getAllStats() {
    final stats = <String, OperationStats>{};
    for (final operationName in _operationDurations.keys) {
      final operationStats = getOperationStats(operationName);
      if (operationStats != null) {
        stats[operationName] = operationStats;
      }
    }
    return stats;
  }

  /// Log performance summary
  void logPerformanceSummary() {
    if (!kDebugMode) {
      return;
    }
    
    final stats = getAllStats();
    if (stats.isEmpty) {
      logInfo('No performance data available');
      return;
    }

    logInfo('=== Performance Summary ===');
    for (final stat in stats.values) {
      logInfo(
        '${stat.operationName}: ${stat.count} calls, '
        'avg: ${stat.averageMs.toStringAsFixed(1)}ms, '
        'min: ${stat.minMs}ms, max: ${stat.maxMs}ms'
      );
    }
  }

  /// Clear all performance data
  void clearStats() {
    _operationStartTimes.clear();
    _operationDurations.clear();
    logInfo('Performance statistics cleared');
  }

  void _startMemoryMonitoring() {
    _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // Note: Actual memory monitoring would require platform-specific implementation
      // This is a placeholder for memory monitoring logic
      logDebug('Memory monitoring tick (implement platform-specific logic)');
    });
  }

  void _startFrameMonitoring() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _monitorFrameRate();
    });
  }

  void _monitorFrameRate() {
    if (!_isMonitoring) {
      return;
    }
    
    // Monitor frame rendering performance
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      // Only continue monitoring if still active
      if (_isMonitoring) {
        // Frame rate monitoring logic would go here
        // Schedule next frame monitoring
        Future.delayed(const Duration(milliseconds: 16), () {
          if (_isMonitoring) {
            _monitorFrameRate();
          }
        });
      }
    });
  }
}

/// Statistics for a specific operation
class OperationStats {
  const OperationStats({
    required this.operationName,
    required this.count,
    required this.averageMs,
    required this.minMs,
    required this.maxMs,
    required this.totalMs,
  });

  final String operationName;
  final int count;
  final double averageMs;
  final int minMs;
  final int maxMs;
  final int totalMs;

  @override
  String toString() =>
      'OperationStats($operationName: $count calls, avg: ${averageMs.toStringAsFixed(1)}ms)';
}

/// Mixin to add performance monitoring to any class
mixin PerformanceMonitorMixin {
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  void startTiming(String operationName) {
    _performanceMonitor.startOperation(operationName);
  }

  void endTiming(String operationName) {
    _performanceMonitor.endOperation(operationName);
  }

  Future<T> timeAsyncOperation<T>(String operationName, Future<T> Function() operation) =>
      _performanceMonitor.timeAsync(operationName, operation);

  T timeSyncOperation<T>(String operationName, T Function() operation) =>
      _performanceMonitor.timeSync(operationName, operation);
}

/// Widget to measure build performance
class PerformanceMeasuredWidget extends StatelessWidget {
  const PerformanceMeasuredWidget({
    required this.child,
    required this.measurementName,
    super.key,
  });

  final Widget child;
  final String measurementName;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      PerformanceMonitor().startOperation('widget_build_$measurementName');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PerformanceMonitor().endOperation('widget_build_$measurementName');
      });
    }
    
    return child;
  }
}
