import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import 'profile_entry.dart';

/// Measures tasks independently and retains a bounded completion history.
///
/// State is local to the current isolate. Profiling is disabled in release
/// builds by default. Reports describe the retained history, not all-time data.
class FlutterProfiler {
  FlutterProfiler._();

  static final _manual = <String, ProfileMeasurement>{};
  static final _active = <ProfileMeasurement>{};
  static final _entries = Queue<ProfileEntry>();
  static final _changes = StreamController<void>.broadcast();
  static bool _enabled = !kReleaseMode;
  static int _maxEntries = 1000;
  static Duration _slowThreshold = const Duration(milliseconds: 16);

  /// Legacy 60 Hz heuristic; task duration is not a frame-jank measurement.
  static const int kPerformanceThreshold = 16;

  /// Asynchronous notifications after history or configuration changes.
  static Stream<void> get changes => _changes.stream;

  /// Whether new measurements are recorded.
  static bool get enabled => _enabled;

  /// The maximum number of retained completed measurements.
  static int get maxEntries => _maxEntries;

  /// The task-duration threshold used by [isSlow].
  static Duration get slowThreshold => _slowThreshold;

  /// The number of measurements awaiting completion in this isolate.
  static int get activeCount => _active.length;

  /// Configures profiling and clears history and running measurements.
  ///
  /// Throws [ArgumentError] for a nonpositive capacity or negative threshold.
  /// Omitted settings keep their current values.
  static void configure({
    bool? enabled,
    int? maxEntries,
    Duration? slowThreshold,
  }) {
    if (maxEntries != null && maxEntries <= 0) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be positive');
    }
    if (slowThreshold != null && slowThreshold.isNegative) {
      throw ArgumentError.value(slowThreshold, 'slowThreshold');
    }
    clear();
    _enabled = enabled ?? _enabled;
    _maxEntries = maxEntries ?? _maxEntries;
    _slowThreshold = slowThreshold ?? _slowThreshold;
    _changes.add(null);
  }

  /// Starts a legacy named task; duplicate starts leave the original running.
  static void start(String key) {
    _validateKey(key);
    if (!_enabled || _manual.containsKey(key)) return;
    _manual[key] = begin(key);
  }

  /// Completes a named task; unknown names are harmless no-ops.
  static void stop(String key) => _manual.remove(key)?.stop();

  /// Starts an independent task, including concurrent tasks with the same key.
  ///
  /// Prefer [trace] and [traceFuture] to ensure completion on exceptions.
  static ProfileMeasurement begin(String key) {
    _validateKey(key);
    final measurement = ProfileMeasurement._(key, _enabled);
    if (_enabled) _active.add(measurement);
    return measurement;
  }

  /// Measures synchronous work, preserving its return value and exceptions.
  static T trace<T>(String key, T Function() action) {
    final measurement = begin(key);
    var failed = true;
    try {
      final result = action();
      failed = false;
      return result;
    } finally {
      measurement.stop(failed: failed);
    }
  }

  /// Measures asynchronous work without collisions between concurrent calls.
  ///
  /// The original error and stack trace propagate unchanged.
  static Future<T> traceFuture<T>(
      String key, Future<T> Function() action) async {
    final measurement = begin(key);
    var failed = true;
    try {
      final result = await action();
      failed = false;
      return result;
    } finally {
      measurement.stop(failed: failed);
    }
  }

  /// An immutable snapshot of completed measurements in completion order.
  static List<ProfileEntry> get entries => List.unmodifiable(_entries);

  /// An immutable legacy timeline snapshot, including immutable maps.
  static List<Map<String, dynamic>> getTimeline() => List.unmodifiable(
        _entries
            .map((entry) => Map<String, dynamic>.unmodifiable(entry.toJson())),
      );

  /// Average milliseconds and sample counts in the retained history.
  static Map<String, String> getReport() {
    final totals = <String, int>{};
    final counts = <String, int>{};
    for (final entry in _entries) {
      totals.update(entry.key, (value) => value + entry.elapsed.inMicroseconds,
          ifAbsent: () => entry.elapsed.inMicroseconds);
      counts.update(entry.key, (value) => value + 1, ifAbsent: () => 1);
    }
    return Map.unmodifiable({
      for (final key in totals.keys)
        key: '${(totals[key]! / counts[key]! / 1000).toStringAsFixed(3)}ms '
            '(x${counts[key]})',
    });
  }

  /// Whether the latest retained sample strictly exceeds [slowThreshold].
  static bool isSlow(String key) {
    for (final entry in _entries.toList().reversed) {
      if (entry.key == key) return entry.elapsed > _slowThreshold;
    }
    return false;
  }

  /// Exports legacy fields together with precision and retention metadata.
  static String exportTimelineJson() => jsonEncode({
        'schema_version': 2,
        'export_date': DateTime.now().toUtc().toIso8601String(),
        'max_entries': _maxEntries,
        'slow_threshold_us': _slowThreshold.inMicroseconds,
        'statistics': getReport(),
        'raw_timeline': _entries.map((entry) => entry.toJson()).toList(),
      });

  /// Discards history and cancels active measurements without late results.
  static void clear() {
    for (final measurement in _active.toList()) {
      measurement._cancel();
    }
    _active.clear();
    _manual.clear();
    _entries.clear();
    _changes.add(null);
  }

  static void _validateKey(String key) {
    if (key.trim().isEmpty) {
      throw ArgumentError.value(key, 'key', 'Must not be blank');
    }
  }

  static void _complete(ProfileMeasurement measurement, bool failed) {
    if (!_active.remove(measurement)) return;
    _entries.add(ProfileEntry(
      key: measurement.key,
      elapsed: measurement._watch.elapsed,
      timestamp: DateTime.now().toUtc(),
      failed: failed,
    ));
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    _changes.add(null);
  }
}

/// An independent measurement handle; [stop] is idempotent.
final class ProfileMeasurement {
  ProfileMeasurement._(this.key, bool enabled) {
    if (enabled) {
      _timeline = dev.TimelineTask()..start(key);
      _watch.start();
    }
  }

  /// The task name assigned when this handle was created.
  final String key;
  final Stopwatch _watch = Stopwatch();
  dev.TimelineTask? _timeline;
  bool _finished = false;

  /// Finishes this task once, optionally marking an application failure.
  void stop({bool failed = false}) {
    if (_finished) return;
    _cancel();
    FlutterProfiler._complete(this, failed);
  }

  void _cancel() {
    _finished = true;
    _watch.stop();
    _timeline?.finish();
    _timeline = null;
  }
}
