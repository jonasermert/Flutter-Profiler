import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_profiler/flutter_profiler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfilerOverlay', () {
    setUp(() => FlutterProfiler.configure(enabled: true, maxEntries: 1000));
    tearDown(FlutterProfiler.clear);

    Widget app({bool enabled = true, ValueChanged<String>? onExport}) =>
        MaterialApp(
          home: ProfilerOverlay(
            enabled: enabled,
            onExport: onExport,
            child: const Scaffold(body: Center(child: Text('Application'))),
          ),
        );

    testWidgets('should update after measurements and reset history',
        (tester) async {
      await tester.pumpWidget(app());
      expect(
          find.text('Noch keine abgeschlossenen Messungen.'), findsOneWidget);
      FlutterProfiler.trace('request', () => 1);
      await tester.pumpAndSettle();
      expect(find.textContaining('request:'), findsOneWidget);
      await tester.tap(find.text('Zurücksetzen'));
      await tester.pumpAndSettle();
      expect(FlutterProfiler.entries, isEmpty);
      expect(
          find.text('Noch keine abgeschlossenen Messungen.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      FlutterProfiler.trace('after-dispose', () => 1);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('should collapse and expand using an accessible button',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('Profiler'));
      await tester.pumpAndSettle();
      expect(find.text('JSON exportieren'), findsNothing);
      await tester.tap(find.text('Profiler'));
      await tester.pumpAndSettle();
      expect(find.text('JSON exportieren'), findsOneWidget);
    });

    testWidgets('should allow keyboard users to toggle the panel',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('JSON exportieren'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('JSON exportieren'), findsOneWidget);
    });

    testWidgets('should explain disabled recording while showing the panel',
        (tester) async {
      FlutterProfiler.configure(enabled: false);
      await tester.pumpWidget(app());
      expect(find.text('Messungen sind deaktiviert.'), findsOneWidget);
    });

    testWidgets('should keep the application interactive outside the panel',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: ProfilerOverlay(
          child: Scaffold(
              body: Align(
            alignment: Alignment.bottomLeft,
            child: TextButton(
                onPressed: () => taps++, child: const Text('App action')),
          )),
        ),
      ));
      await tester.tap(find.text('App action'));
      expect(taps, 1);
    });

    testWidgets('should export valid JSON through the callback',
        (tester) async {
      String? exported;
      FlutterProfiler.trace('export', () => 1);
      await tester.pumpWidget(app(onExport: (json) => exported = json));
      await tester.tap(find.text('JSON exportieren'));
      await tester.pumpAndSettle();
      expect((jsonDecode(exported!) as Map<String, dynamic>)['raw_timeline'],
          hasLength(1));
      expect(find.text('JSON exportiert.'), findsOneWidget);
    });

    testWidgets('should copy JSON to the clipboard by default', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<dynamic, dynamic>)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(app());
      await tester.tap(find.text('JSON exportieren'));
      await tester.pumpAndSettle();
      expect(jsonDecode(copied!), isA<Map<String, dynamic>>());
      expect(find.text('JSON in Zwischenablage kopiert.'), findsOneWidget);
    });

    testWidgets('should show export failures and permit retry', (tester) async {
      var failExport = true;
      await tester.pumpWidget(app(onExport: (_) {
        if (failExport) throw StateError('Export unavailable');
      }));
      await tester.tap(find.text('JSON exportieren'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isA<StateError>());
      expect(find.text('Export fehlgeschlagen. Erneut versuchen.'),
          findsOneWidget);
      failExport = false;
      await tester.tap(find.text('JSON exportieren'));
      await tester.pumpAndSettle();
      expect(find.text('JSON exportiert.'), findsOneWidget);
    });

    testWidgets('should hide the panel when disabled', (tester) async {
      await tester.pumpWidget(app(enabled: false));
      expect(find.text('Application'), findsOneWidget);
      expect(find.text('Profiler'), findsNothing);
    });

    testWidgets(
        'should scroll without overflow on small screens and large text',
        (tester) async {
      tester.view.physicalSize = const Size(260, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (var i = 0; i < 30; i++) {
        FlutterProfiler.trace('A very long task label $i', () => i);
      }
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const ProfilerOverlay(child: Scaffold()),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Zurücksetzen'), 300);
      await tester.tap(find.text('Zurücksetzen'));
      await tester.pumpAndSettle();
      expect(FlutterProfiler.entries, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
