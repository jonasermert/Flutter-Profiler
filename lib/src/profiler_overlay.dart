import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'profiler_logic.dart';

/// A scrollable development panel above [child], hidden in release by default.
///
/// Place inside a MaterialApp, for example in its builder. [enabled] can
/// explicitly show the panel in profile mode or hide it in development.
class ProfilerOverlay extends StatefulWidget {
  const ProfilerOverlay({
    super.key,
    required this.child,
    this.enabled = !kReleaseMode,
    this.onExport,
  });

  /// The application content beneath the panel.
  final Widget child;

  /// Whether the panel is visible, independently of profiler recording.
  final bool enabled;

  /// Receives JSON instead of copying it to the system clipboard when supplied.
  final ValueChanged<String>? onExport;

  @override
  State<ProfilerOverlay> createState() => _ProfilerOverlayState();
}

class _ProfilerOverlayState extends State<ProfilerOverlay> {
  bool _expanded = true;
  bool _exporting = false;
  String? _feedback;

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _feedback = null;
    });
    try {
      final json = FlutterProfiler.exportTimelineJson();
      if (widget.onExport case final callback?) {
        callback(json);
      } else {
        await Clipboard.setData(ClipboardData(text: json));
      }
      if (mounted) {
        setState(() => _feedback = widget.onExport == null
            ? 'JSON in Zwischenablage kopiert.'
            : 'JSON exportiert.');
      }
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() => _feedback = 'Export fehlgeschlagen. Erneut versuchen.');
      }
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'flutter_profiler',
        context: ErrorDescription('while exporting profiler history'),
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: SafeArea(
            minimum: const EdgeInsets.all(8),
            child: LayoutBuilder(builder: (context, constraints) {
              return Align(
                alignment: Alignment.topRight,
                child: SizedBox(
                  width: math.min(320, constraints.maxWidth),
                  child: Material(
                    color: const Color(0xF2222222),
                    borderRadius: BorderRadius.circular(12),
                    elevation: 8,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: StreamBuilder<void>(
                          stream: FlutterProfiler.changes,
                          builder: (context, snapshot) => _buildPanel(),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    final report = FlutterProfiler.getReport();
    return DefaultTextStyle(
      style: const TextStyle(color: Colors.white, fontSize: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tooltip(
            message: _expanded ? 'Profiler einklappen' : 'Profiler ausklappen',
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
              child: Row(children: [
                const Expanded(child: Text('Profiler')),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ]),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Colors.white38),
            if (!FlutterProfiler.enabled)
              const Text('Messungen sind deaktiviert.')
            else if (report.isEmpty)
              const Text('Noch keine abgeschlossenen Messungen.'),
            for (final entry in report.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '${entry.key}: ${entry.value}'
                  '${FlutterProfiler.isSlow(entry.key) ? ' · Langsam' : ''}',
                  style: TextStyle(
                    color: FlutterProfiler.isSlow(entry.key)
                        ? Colors.orangeAccent
                        : Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Aufgabendauer, keine FPS-Messung. '
              'Durchschnitte gelten für die gespeicherte Historie.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _exporting ? null : _export,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
              child: Text(_exporting ? 'Export läuft …' : 'JSON exportieren'),
            ),
            TextButton(
              onPressed: () {
                FlutterProfiler.clear();
                setState(() => _feedback = 'Messungen zurückgesetzt.');
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
              child: const Text('Zurücksetzen'),
            ),
            if (_feedback case final feedback?)
              Semantics(liveRegion: true, child: Text(feedback)),
          ],
        ],
      ),
    );
  }
}
