# Changelog

## 1.1.0

Die Profiler-Implementierungen wurden zusammengeführt. Unabhängige TimelineTask-Messungen unterstützen parallele und verschachtelte Aufgaben mit identischen Namen. trace ergänzt synchrones Profiling, begin liefert unabhängig abschließbare Handles, und traceFuture bewahrt Rückgabewerte sowie ursprüngliche Fehler und Stacktraces. Fehlgeschlagene Aufgaben werden im Export gekennzeichnet.

Die Messdaten behalten Mikrosekundenpräzision. entries und getTimeline liefern unveränderliche Snapshots. Eine konfigurierbare, standardmäßig auf 1000 Abschlüsse begrenzte Historie ersetzt unbegrenzt wachsende Statistiklisten. Berichte beziehen sich auf diese Historie und zeigen drei Nachkommastellen. clear und configure verwerfen laufende Aufgaben zuverlässig. Release-Aufzeichnung ist standardmäßig deaktiviert.

Das Live-Overlay aktualisiert sich ereignisgesteuert, unterstützt Tastaturbedienung, große Schrift und kleine Ansichten, zeigt einen Leerzustand und erlaubt Reset sowie Zwischenablage-Export mit Rückmeldung und Fehlerbehandlung. Es ist auch im Profile-Modus verfügbar und lässt sich ausdrücklich ausblenden.

Die defekten Platzhaltertests und Beispiele wurden durch Regressionstests und eine startbare Web-Demo ersetzt. Flutter-Lints, korrekte Repository-Metadaten, deutsche API-Dokumentation und GitHub Actions für Analyse, Tests, Formatierung und Demo-Build wurden ergänzt. Die unterstützte Untergrenze ist Flutter 3.16 mit Dart 3.2.

## 1.0.0

Erste Version.
