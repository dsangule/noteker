import 'dart:async';
import 'package:flutter/foundation.dart';

import 'logger.dart';

/// Simple performance timer for measuring operation durations
class PerformanceTimer with LoggerMixin {
  factory PerformanceTimer() => _instance;

  PerformanceTimer._internal();

  static final PerformanceTimer _instance = PerformanceTimer._internal();

  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, List<Duration>> _operationDurations = {};

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

    if (kDebugMode) {
      logInfo('Operation "$operationName" took ${duration.inMilliseconds}ms');
    }
  }

  /// Time a synchronous operation
  T time<T>(String operationName, T Function() operation) {
    startOperation(operationName);
    try {
      return operation();
    } finally {
      endOperation(operationName);
    }
  }

  /// Time an asynchronous operation
  Future<T> timeAsync<T>(String operationName, Future<T> Function() operation) async {
    startOperation(operationName);
    try {
      return await operation();
    } finally {
      endOperation(operationName);
    }
  }

  /// Get average duration for an operation
  Duration? getAverageDuration(String operationName) {
    final durations = _operationDurations[operationName];
    if (durations == null || durations.isEmpty) {
      return null;
    }

    final totalMs = durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ durations.length);
  }

  /// Get all recorded durations for an operation
  List<Duration> getDurations(String operationName) =>
    List.unmodifiable(_operationDurations[operationName] ?? []);

  /// Clear all recorded metrics
  void clearMetrics() {
    _operationStartTimes.clear();
    _operationDurations.clear();
    logInfo('Performance metrics cleared');
  }

  /// Get performance summary
  Map<String, Map<String, dynamic>> getPerformanceSummary() {
    final summary = <String, Map<String, dynamic>>{};

    for (final entry in _operationDurations.entries) {
      final operationName = entry.key;
      final durations = entry.value;

      if (durations.isNotEmpty) {
        final totalMs = durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
        final avgMs = totalMs / durations.length;
        final minMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
        final maxMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);

        summary[operationName] = {
          'count': durations.length,
          'totalMs': totalMs,
          'averageMs': avgMs.round(),
          'minMs': minMs,
          'maxMs': maxMs,
        };
      }
    }

    return summary;
  }
}
