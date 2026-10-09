# Flutter Profiler

Flutter Profiler misst die Dauer synchroner und asynchroner Aufgaben in Flutter-Anwendungen. Ein Live-Overlay zeigt Durchschnittswerte und erlaubt den JSON-Export. Das Package benötigt Flutter ab 3.16 und Dart ab 3.2; es ist wegen der Flutter-Abhängigkeit kein eigenständiges Dart-Package.

```dart
import 'package:flutter_profiler/flutter_profiler.dart';

final result = FlutterProfiler.trace('Berechnung', () => 6 * 7);
final data = await FlutterProfiler.traceFuture('API', () => loadData());
```

Die Messung nutzt eine monotone Stopwatch und speichert Mikrosekunden; die tatsächliche Timerauflösung hängt von der Plattform ab. Jede Aufgabe erhält eine unabhängige TimelineTask für Dart DevTools. Auch gleichnamige, parallele oder verschachtelte trace-Aufrufe werden getrennt erfasst. Rückgabewerte bleiben erhalten. Bei einem Fehler wird die Messung als fehlgeschlagen markiert, bevor der ursprüngliche Fehler samt Stacktrace weitergereicht wird.

## Installation aus GitHub

```yaml
dependencies:
  flutter_profiler:
    git:
      url: https://github.com/jonasermert/Flutter-Profiler.git
      ref: master
```

Für reproduzierbare Anwendungen sollte ref auf einen geprüften Commit zeigen. Eine Veröffentlichung auf pub.dev wird hier nicht vorausgesetzt.

## Manuelle und parallele Messungen

Die bisherige benannte API bleibt verfügbar. Ein wiederholtes start mit demselben Namen lässt die ursprüngliche Aufgabe weiterlaufen. stop für einen unbekannten oder bereits abgeschlossenen Namen tut nichts. Leere oder ausschließlich aus Leerzeichen bestehende Namen sind ungültig und lösen ArgumentError aus.

```dart
FlutterProfiler.start('Laden');
try {
  await loadData();
} finally {
  FlutterProfiler.stop('Laden');
}
```

Für automatische Fehlerkennzeichnung und gleichnamige Parallelität empfiehlt sich traceFuture. Ein synchroner Callback gehört in trace; asynchrone Arbeit gehört in traceFuture, damit die gesamte Wartezeit gemessen wird.

```dart
await Future.wait([
  FlutterProfiler.traceFuture('Anfrage', () => loadUser()),
  FlutterProfiler.traceFuture('Anfrage', () => loadSettings()),
]);
```

begin liefert für manuell gesteuerte parallele Aufgaben jeweils einen unabhängigen Handle. stop auf einem Handle ist idempotent. Der Aufrufer muss den Handle auch im Fehlerfall abschließen.

```dart
final measurement = FlutterProfiler.begin('Import');
try {
  await importData();
  measurement.stop();
} catch (_) {
  measurement.stop(failed: true);
  rethrow;
}
```

## Live-Overlay

Das Overlay wird innerhalb einer MaterialApp eingebunden und in Debug- und Profile-Builds standardmäßig angezeigt. In Release-Builds ist es standardmäßig verborgen. enabled am Overlay steuert ausschließlich dessen Sichtbarkeit; FlutterProfiler.configure steuert das Aufzeichnen.

```dart
MaterialApp(
  builder: (context, child) => ProfilerOverlay(child: child!),
  home: const MyHomePage(),
);
```

Das Panel aktualisiert sich nach Änderungen der Historie ohne periodischen Timer. Es kann über einen Standard-Button eingeklappt werden, ist bei wenig Platz scrollbar und berücksichtigt SafeArea sowie größere Systemschrift. Langsame Aufgaben werden zusätzlich zur Farbe mit „Langsam“ gekennzeichnet. „Zurücksetzen“ verwirft Historie und aktive Messungen. „JSON exportieren“ kopiert Daten in die Zwischenablage und zeigt Erfolg oder einen erneut versuchbaren Fehler an.

Für eigene Exportziele lässt sich ein synchroner Callback übergeben. Exportfehler werden über FlutterError gemeldet und im Panel angezeigt. Der Callback kann einen externen Speicher- oder Downloadprozess anstoßen; dessen spätere asynchrone Fehler muss die Anwendung selbst behandeln.

```dart
ProfilerOverlay(
  onExport: (json) => shareJson(json),
  child: const MyHomePage(),
);
```

## Konfiguration und Speichergrenzen

```dart
FlutterProfiler.configure(
  enabled: true,
  maxEntries: 500,
  slowThreshold: const Duration(milliseconds: 20),
);
```

Standardmäßig werden die letzten 1000 abgeschlossenen Aufgaben gespeichert. Ältere Einträge werden in Abschlussreihenfolge entfernt. Auch Berichte und die Langsam-Kennzeichnung beruhen ausschließlich auf dieser gespeicherten Historie; es gibt keine unbegrenzt wachsende zweite Statistikliste. Die Zahl gleichzeitig laufender Aufgaben wird nicht begrenzt: Manuelle Messungen müssen immer abgeschlossen werden. Der Zustand ist pro Isolate getrennt.

configure prüft zuerst die Eingaben und verwirft danach bisherige Messungen, einschließlich laufender Aufgaben. Nicht angegebene Einstellungen bleiben erhalten. maxEntries muss positiv sein; slowThreshold darf nicht negativ sein. clear verwirft ebenfalls alle laufenden Messungen. Später eintreffende Abschlüsse solcher Aufgaben verändern weder neue Messungen noch die geleerte Historie.

In Release-Builds ist die Aufzeichnung standardmäßig deaktiviert. Die Callback-Funktionen werden trotzdem ausgeführt und Fehler normal weitergegeben. Eine explizite Aktivierung in Release ist möglich, sollte jedoch wegen Messaufwand und möglicherweise sensibler Aufgabennamen bewusst erfolgen.

## Berichte und Exportformat

```dart
final report = FlutterProfiler.getReport();
final timeline = FlutterProfiler.getTimeline();
final measurements = FlutterProfiler.entries;
final json = FlutterProfiler.exportTimelineJson();
```

entries liefert unveränderliche ProfileEntry-Objekte mit elapsed, UTC-Zeitstempel, key und failed. getTimeline liefert eine unveränderliche Liste mit unveränderlichen Maps. getReport liefert unveränderliche Durchschnittswerte in Millisekunden mit drei Nachkommastellen und Stichprobenzahl, etwa „12.345ms (x3)“. Änderungen an zurückgegebenen Snapshots verändern die internen Daten nicht.

Das JSON behält die bisherigen Felder export_date, statistics und raw_timeline. duration bleibt eine ganzzahlige Millisekundenangabe. duration_us ergänzt die volle Messpräzision; failed kennzeichnet fehlgeschlagene Aufgaben. schema_version ist 2, max_entries beschreibt die Speichergrenze und slow_threshold_us den eingestellten Grenzwert.

```json
{
  "schema_version": 2,
  "export_date": "2026-10-09T10:00:00.000Z",
  "max_entries": 1000,
  "slow_threshold_us": 16000,
  "statistics": {"API": "20.125ms (x1)"},
  "raw_timeline": [
    {
      "key": "API",
      "duration": 20,
      "duration_us": 20125,
      "timestamp": "2026-10-09T09:59:59.000Z",
      "failed": false
    }
  ]
}
```

## Interpretation der Ergebnisse

Die Standardgrenze von 16 ms ist ein einfacher Hinweis auf lange Aufgaben, kein Nachweis verlorener Frames. Asynchrone Messungen schließen Wartezeiten ein. Das Package misst weder FPS noch Speicherverbrauch, Rasterisierung oder GPU-Zeit. Die Laufzeit von Widget-Konstruktionscode entspricht nicht der vollständigen Renderzeit. Für Frame-Analysen und die Zuordnung von UI- und Raster-Arbeit sind die Flutter DevTools im Profile-Modus das passende ergänzende Werkzeug. Ein aktives Overlay verursacht selbst Arbeit und sollte bei Vergleichsmessungen ausgeblendet werden.

## Beispiel starten und entwickeln

Die Web-Demo verwendet das Package über eine lokale Pfadabhängigkeit und benötigt wegen des aktuellen Web-Bootstraps Flutter ab 3.22 mit Dart ab 3.4. Nach dem Klonen lässt sie sich so starten:

```sh
cd example
flutter pub get
flutter run -d chrome --target flutter_profiler_example.dart
```

Der Demo-Button startet zwei gleichnamige Anfragen gleichzeitig. Der Bericht zeigt nach deren Abschluss zwei Stichproben. Ein Web-Build ist mit flutter build web --target flutter_profiler_example.dart möglich.

Im Repository-Hauptverzeichnis prüfen diese Befehle Formatierung, statische Analyse und Tests:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test example/flutter_profiler_example.dart
flutter analyze
flutter test --coverage
```

GitHub Actions führt diese Prüfungen für Pull Requests aus, archiviert den Coverage-Bericht und prüft zusätzlich Analyse und Web-Build der Demo. Unit-Tests decken Parallelität, Fehlerweitergabe, Speichergrenzen, Snapshots, Konfiguration und Reset ab. Widget-Tests prüfen Aktualisierung, Ein-/Ausklappen, Export, Fehlerbehandlung, Zurücksetzen und kleine Ansichten mit großer Schrift.

## Migration von 1.0.0

Die bestehenden öffentlichen Methoden bleiben erhalten. getTimeline ist wieder über dieselbe öffentliche Klasse verfügbar; der historische Import src/flutter_profiler_base.dart leitet auf diese Implementierung weiter. Für neue Anwendungen ist ausschließlich package:flutter_profiler/flutter_profiler.dart empfohlen.

Berichtswerte enthalten nun drei statt einer Nachkommastelle. Die Historie ist standardmäßig auf 1000 Einträge begrenzt. configure und clear verwerfen laufende Aufgaben. Debug und Profile zeichnen standardmäßig auf, Release nicht. Die SDK-Untergrenze wurde auf Flutter 3.16 und Dart 3.2 vereinheitlicht. Ein JSON-Parser sollte zusätzliche Felder tolerieren und für präzise Auswertung duration_us verwenden.

## Lizenz

Das Repository enthält derzeit keine LICENSE-Datei. Die frühere Aussage, es sei unter MIT lizenziert, wurde deshalb entfernt. Diese Überarbeitung legt keine neue Lizenz im Namen des Eigentümers fest.
