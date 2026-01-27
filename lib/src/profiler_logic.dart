import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

class FlutterProfiler {
  static final Map<String, Stopwatch> _stopwatches = {};
  static final Map<String, List<int>> _stats = {};
  static final List<Map<String, dynamic>> _timeline = [];

  // Schwellenwert für Warnungen (16ms = 60 FPS)
  static const int kPerformanceThreshold = 16;

  static void start(String key) {
    if (_stopwatches.containsKey(key)) return;

    // Sichtbarkeit in den Dart DevTools Performance Tab
    dev.Timeline.startSync(key);
    _stopwatches[key] = Stopwatch()..start();
  }

  static void stop(String key) {
    final stopwatch = _stopwatches.remove(key);
    if (stopwatch == null) return;

    stopwatch.stop();
    dev.Timeline.finishSync();

    final duration = stopwatch.elapsedMilliseconds;

    // Statistiken für Durchschnittswerte
    _stats.putIfAbsent(key, () => []).add(duration);

    // Timeline für den JSON-Export
    _timeline.add({
      'key': key,
      'duration': duration,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (kDebugMode) {
      dev.log('PROFILER: $key -> ${duration}ms', name: 'flutter_profiler');
    }
  }

  static Future<T> traceFuture<T>(String key, Future<T> Function() action) async {
    start(key);
    try {
      return await action();
    } finally {
      stop(key);
    }
  }

  static Map<String, String> getReport() {
    final report = <String, String>{};
    _stats.forEach((key, times) {
      final avg = times.reduce((a, b) => a + b) / times.length;
      report[key] = '${avg.toStringAsFixed(1)}ms (x${times.length})';
    });
    return report;
  }

  static bool isSlow(String key) {
    final times = _stats[key];
    return (times != null && times.isNotEmpty && times.last > kPerformanceThreshold);
  }

  static String exportTimelineJson() {
    return jsonEncode({
      'export_date': DateTime.now().toIso8601String(),
      'statistics': getReport(),
      'raw_timeline': _timeline,
    });
  }

  static void clear() {
    _stopwatches.clear();
    _stats.clear();
    _timeline.clear();
  }
}