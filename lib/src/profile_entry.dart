/// An immutable completed measurement with microsecond precision.
final class ProfileEntry {
  /// Creates a completed measurement snapshot.
  const ProfileEntry({
    required this.key,
    required this.elapsed,
    required this.timestamp,
    required this.failed,
  });

  /// The user-supplied task name.
  final String key;

  /// Monotonic elapsed time, at the precision supported by the runtime.
  final Duration elapsed;

  /// The completion time, recorded in UTC by the profiler.
  final DateTime timestamp;

  /// Whether the action threw or the handle was explicitly marked failed.
  final bool failed;

  /// A fresh JSON-compatible snapshot; duration retains the legacy ms unit.
  Map<String, Object> toJson() => {
        'key': key,
        'duration': elapsed.inMilliseconds,
        'duration_us': elapsed.inMicroseconds,
        'timestamp': timestamp.toIso8601String(),
        'failed': failed,
      };
}
