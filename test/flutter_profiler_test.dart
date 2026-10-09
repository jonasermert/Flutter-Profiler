import 'dart:async';
import 'dart:convert';

import 'package:flutter_profiler/flutter_profiler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlutterProfiler', () {
    setUp(() => FlutterProfiler.configure(
          enabled: true,
          maxEntries: 1000,
          slowThreshold: const Duration(milliseconds: 16),
        ));
    tearDown(FlutterProfiler.clear);

    test('should preserve legacy manual tasks and ignore duplicate starts', () {
      FlutterProfiler.start('task');
      FlutterProfiler.start('task');
      expect(FlutterProfiler.activeCount, 1);
      FlutterProfiler.stop('unknown');
      FlutterProfiler.stop('task');
      FlutterProfiler.stop('task');
      expect(FlutterProfiler.entries, hasLength(1));
      expect(FlutterProfiler.activeCount, 0);
      expect(FlutterProfiler.getTimeline().single['duration'], isA<int>());
    });

    test('should retain sync results and record original errors', () {
      expect(FlutterProfiler.trace('result', () => 42), 42);
      final error = StateError('original');
      expect(() => FlutterProfiler.trace('failure', () => throw error),
          throwsA(same(error)));
      expect(FlutterProfiler.entries.last.failed, isTrue);
      expect(FlutterProfiler.entries.first.failed, isFalse);
      expect(FlutterProfiler.activeCount, 0);
    });

    test('should measure concurrent identical keys independently', () async {
      final first = Completer<int>();
      final second = Completer<int>();
      final a = FlutterProfiler.traceFuture('same', () => first.future);
      final b = FlutterProfiler.traceFuture('same', () => second.future);
      expect(FlutterProfiler.activeCount, 2);
      second.complete(2);
      expect(await b, 2);
      expect(FlutterProfiler.activeCount, 1);
      expect(FlutterProfiler.entries, hasLength(1));
      first.complete(1);
      expect(await a, 1);
      expect(FlutterProfiler.getReport()['same'], endsWith('(x2)'));
      expect(FlutterProfiler.activeCount, 0);
    });

    test('should isolate nested traces from a manually running identical key',
        () {
      FlutterProfiler.start('same');
      expect(
          FlutterProfiler.trace(
              'same', () => FlutterProfiler.trace('same', () => 42)),
          42);
      expect(FlutterProfiler.activeCount, 1);
      expect(FlutterProfiler.entries, hasLength(2));
      FlutterProfiler.stop('same');
      expect(FlutterProfiler.entries, hasLength(3));
    });

    test('should preserve asynchronous and immediate callback failures',
        () async {
      final error = StateError('failure');
      final stack = StackTrace.current;
      try {
        await FlutterProfiler.traceFuture<int>(
            'async', () => Future<int>.error(error, stack));
        fail('Expected original failure');
      } catch (caught, caughtStack) {
        expect(caught, same(error));
        expect(caughtStack.toString(), stack.toString());
      }
      await expectLater(
          FlutterProfiler.traceFuture<int>('immediate', () => throw error),
          throwsA(same(error)));
      expect(FlutterProfiler.entries.every((entry) => entry.failed), isTrue);
      expect(FlutterProfiler.activeCount, 0);
    });

    test('should discard running measurements after clear', () async {
      final pending = Completer<int>();
      final old = FlutterProfiler.traceFuture('same', () => pending.future);
      FlutterProfiler.clear();
      FlutterProfiler.start('same');
      pending.complete(7);
      expect(await old, 7);
      expect(FlutterProfiler.entries, isEmpty);
      expect(FlutterProfiler.activeCount, 1);
      FlutterProfiler.stop('same');
      expect(FlutterProfiler.entries, hasLength(1));
    });

    test('should bound history and reports including unique task names', () {
      FlutterProfiler.configure(maxEntries: 2);
      FlutterProfiler.trace('old', () => 1);
      FlutterProfiler.trace('new', () => 2);
      FlutterProfiler.trace('new', () => 3);
      expect(FlutterProfiler.entries, hasLength(2));
      expect(FlutterProfiler.getReport().keys, ['new']);
      final data = jsonDecode(FlutterProfiler.exportTimelineJson())
          as Map<String, dynamic>;
      expect(data['schema_version'], 2);
      expect(data['max_entries'], 2);
      expect(data['raw_timeline'], hasLength(2));
      final entry = FlutterProfiler.entries.last;
      expect(entry.toJson()['duration_us'], entry.elapsed.inMicroseconds);
      expect(entry.timestamp.isUtc, isTrue);
      expect(FlutterProfiler.getReport()['new'],
          '${(FlutterProfiler.entries.fold<int>(0, (sum, e) => sum + e.elapsed.inMicroseconds) / 2 / 1000).toStringAsFixed(3)}ms (x2)');
    });

    test('should protect snapshots against caller mutation', () {
      FlutterProfiler.trace('task', () => null);
      final timeline = FlutterProfiler.getTimeline();
      expect(() => timeline.clear(), throwsUnsupportedError);
      expect(() => timeline.single['key'] = 'changed', throwsUnsupportedError);
      expect(() => FlutterProfiler.entries.clear(), throwsUnsupportedError);
      expect(() => FlutterProfiler.getReport().clear(), throwsUnsupportedError);
      expect(FlutterProfiler.entries.single.key, 'task');
    });

    test('should validate settings before discarding history', () {
      FlutterProfiler.trace('task', () => null);
      expect(
          () => FlutterProfiler.configure(maxEntries: 0), throwsArgumentError);
      expect(
          () => FlutterProfiler.configure(
              slowThreshold: const Duration(microseconds: -1)),
          throwsArgumentError);
      expect(() => FlutterProfiler.begin('  '), throwsArgumentError);
      expect(FlutterProfiler.entries, hasLength(1));
    });

    test('should execute actions without recording when disabled', () async {
      FlutterProfiler.configure(enabled: false);
      FlutterProfiler.start('manual');
      expect(FlutterProfiler.trace('sync', () => 4), 4);
      expect(await FlutterProfiler.traceFuture('async', () async => 5), 5);
      final error = StateError('disabled failure');
      expect(() => FlutterProfiler.trace('error', () => throw error),
          throwsA(same(error)));
      expect(FlutterProfiler.entries, isEmpty);
      expect(FlutterProfiler.activeCount, 0);
    });

    test('should stop handles once and classify the latest duration', () {
      FlutterProfiler.configure(slowThreshold: Duration.zero);
      final handle = FlutterProfiler.begin('slow');
      // Real stopwatch time advances without relying on sleep durations.
      final watch = Stopwatch()..start();
      while (watch.elapsedMicroseconds < 100) {}
      handle.stop();
      handle.stop(failed: true);
      expect(FlutterProfiler.entries, hasLength(1));
      expect(FlutterProfiler.entries.single.failed, isFalse);
      expect(FlutterProfiler.isSlow('slow'), isTrue);
      expect(FlutterProfiler.isSlow('missing'), isFalse);
    });

    test('should emit asynchronous history notifications', () async {
      // Flush configuration events before subscribing.
      await Future<void>.delayed(Duration.zero);
      final notification = FlutterProfiler.changes.first;
      FlutterProfiler.trace('event', () => null);
      await notification;
      expect(FlutterProfiler.entries.single.key, 'event');
    });
  });
}
