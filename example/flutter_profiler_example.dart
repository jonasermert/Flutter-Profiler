import 'package:flutter/material.dart';
import 'package:flutter_profiler/flutter_profiler.dart';

void main() => runApp(const ProfilerExample());

/// Demonstrates concurrent requests, error recording and the live overlay.
class ProfilerExample extends StatelessWidget {
  const ProfilerExample({super.key});

  Future<void> _runRequests() async {
    await Future.wait([
      FlutterProfiler.traceFuture('Anfrage', () async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }),
      FlutterProfiler.traceFuture('Anfrage', () async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Flutter Profiler Beispiel',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        builder: (context, child) => ProfilerOverlay(child: child!),
        home: Scaffold(
          appBar: AppBar(title: const Text('Profiler Beispiel')),
          body: Center(
            child: FilledButton(
              onPressed: _runRequests,
              child: const Text('Zwei parallele Anfragen messen'),
            ),
          ),
        ),
      );
}
