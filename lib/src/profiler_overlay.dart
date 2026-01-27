import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'profiler_logic.dart';

class ProfilerOverlay extends StatefulWidget {
  final Widget child;
  const ProfilerOverlay({super.key, required this.child});

  @override
  State<ProfilerOverlay> createState() => _ProfilerOverlayState();
}

class _ProfilerOverlayState extends State<ProfilerOverlay> {
  Timer? _refreshTimer;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    // Intervall für UI-Updates (500ms ist Ressourcen-schonend)
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rendert das Overlay NUR im Debug-Modus
    if (!kDebugMode) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 10,
          child: Material(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            elevation: 8,
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "PROFILER LIVE",
                          style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        Icon(
                          _isExpanded ? Icons.keyboard_arrow_up : Icons.insights,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                  if (_isExpanded) ...[
                    const Divider(color: Colors.white24, height: 15),
                    ...FlutterProfiler.getReport().entries.map((e) {
                      final slow = FlutterProfiler.isSlow(e.key);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          "${e.key}: ${e.value}",
                          style: TextStyle(
                            color: slow ? Colors.orangeAccent : Colors.greenAccent,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: slow ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        final json = FlutterProfiler.exportTimelineJson();
                        dev.log(json, name: 'PROFILER_EXPORT');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 28),
                        textStyle: const TextStyle(fontSize: 10),
                      ),
                      child: const Text("EXPORT JSON (Log)"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}