import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _defaultTimeout = Duration(minutes: 8);

// Fichiers produits par le mode `full`, à la racine du projet.
const _failuresLogPath = 'test_failures.log';
const _failuresJsonPath = 'test_failures.json';
const _coverageLogPath = 'coverage_report.log';
const _coverageJsonPath = 'coverage_report.json';
const _lcovPath = 'coverage/lcov.info';

/// Resolves the `flutter` executable path from the running Dart SDK.
/// When invoked via `dart run` from a Flutter-managed SDK, Flutter is not on
/// the PATH but lives in the Flutter SDK `bin/` directory. `dartBin` points at
/// `flutter/bin/cache/dart-sdk/bin`, so the Flutter `bin/` directory is 3
/// levels above it.
String get _flutterPath {
  final dartBin = File(Platform.resolvedExecutable).parent.path;
  final flutterSdkBin = Directory(dartBin).parent.parent.parent.path;
  final name = Platform.isWindows ? 'flutter.bat' : 'flutter';
  return '$flutterSdkBin${Platform.pathSeparator}$name';
}

// ---------------------------------------------------------------------------
// Exécution simple (tous les modes sauf `full`)
// ---------------------------------------------------------------------------

Future<int> runFlutterTest(
  List<String> arguments, {
  Duration timeout = _defaultTimeout,
}) async {
  stdout.writeln('> flutter test ${arguments.join(' ')}');
  final process = await Process.start(
    _flutterPath,
    ['test', ...arguments],
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  return _waitOrKill(process, timeout, arguments);
}

Future<int> _waitOrKill(
  Process process,
  Duration timeout,
  List<String> arguments,
) async {
  try {
    return await process.exitCode.timeout(timeout);
  } on TimeoutException {
    stderr.writeln(
      'TIMEOUT after $timeout: flutter test ${arguments.join(' ')}',
    );
    process.kill(ProcessSignal.sigterm);
    await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () => -1,
    );
    return 124;
  }
}

// ---------------------------------------------------------------------------
// Rapport d'échecs (mode `full`)
// ---------------------------------------------------------------------------

class FailedTest {
  FailedTest({
    required this.suiteLabel,
    required this.name,
    required this.file,
    required this.location,
    required this.result,
    required this.durationMs,
    required this.prints,
    required this.errors,
  });

  final String suiteLabel; // unit_widget_tests / integration_tests
  final String name;
  final String? file; // fichier de test (relatif)
  final String? location; // fichier:ligne:colonne de déclaration
  final String result; // failure | error
  final int? durationMs;
  final List<String> prints;
  final List<({String error, String stackTrace, bool isFailure})> errors;

  Map<String, Object?> toJson() => {
    'suite': suiteLabel,
    'name': name,
    'file': file,
    'location': location,
    'result': result,
    'durationMs': durationMs,
    'prints': prints,
    'errors': [
      for (final e in errors)
        {
          'error': e.error,
          'stackTrace': e.stackTrace,
          'isFailure': e.isFailure,
        },
    ],
  };
}

class SuiteRunReport {
  SuiteRunReport({
    required this.label,
    required this.args,
    required this.exitCode,
    required this.total,
    required this.passed,
    required this.skipped,
    required this.failures,
    required this.reportFile,
  });

  final String label;
  final List<String> args;
  final int exitCode;
  final int total;
  final int passed;
  final int skipped;
  final List<FailedTest> failures;
  final String reportFile;

  bool get hasProblem => exitCode != 0 || failures.isNotEmpty;
}

String _relativePath(String uriOrPath) {
  try {
    final path = uriOrPath.startsWith('file:')
        ? Uri.parse(uriOrPath).toFilePath()
        : uriOrPath;
    final cwd = Directory.current.path;
    if (path.startsWith(cwd)) {
      return path.substring(cwd.length).replaceFirst(RegExp(r'^[\\/]+'), '');
    }
    return path;
  } catch (_) {
    return uriOrPath;
  }
}

/// Lance `flutter test` avec la sortie console NORMALE et écrit en plus un
/// rapport JSON via `--file-reporter`, analysé ensuite pour extraire les échecs.
Future<SuiteRunReport> runSuiteWithReport(
  String label,
  List<String> args, {
  Duration timeout = _defaultTimeout,
}) async {
  final reportFile = 'coverage/partials/$label.json';
  final f = File(reportFile);
  if (f.existsSync()) f.deleteSync();

  final fullArgs = ['--file-reporter', 'json:$reportFile', ...args];
  stdout.writeln('> flutter test ${fullArgs.join(' ')}');
  final process = await Process.start(
    _flutterPath,
    ['test', ...fullArgs],
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await _waitOrKill(process, timeout, args);

  return _parseJsonReport(label, args, code, reportFile);
}

SuiteRunReport _parseJsonReport(
  String label,
  List<String> args,
  int exitCode,
  String reportFile,
) {
  final suitePaths = <int, String>{};
  final names = <int, String>{};
  final suiteOfTest = <int, int>{};
  final locations = <int, String>{};
  final startTimes = <int, int>{};
  final prints = <int, List<String>>{};
  final errors =
      <int, List<({String error, String stackTrace, bool isFailure})>>{};
  final failed = <int, ({String result, int? durationMs})>{};
  var total = 0, passed = 0, skipped = 0;

  final file = File(reportFile);
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      Map<String, dynamic>? e;
      try {
        final d = jsonDecode(line);
        if (d is Map<String, dynamic>) e = d;
      } catch (_) {
        continue; // ligne tronquée (timeout / crash)
      }
      if (e == null) continue;

      switch (e['type']) {
        case 'suite':
          final s = e['suite'] as Map<String, dynamic>;
          suitePaths[s['id'] as int] = s['path'] as String? ?? '';
        case 'testStart':
          final t = e['test'] as Map<String, dynamic>;
          final id = t['id'] as int;
          names[id] = t['name'] as String;
          suiteOfTest[id] = t['suiteID'] as int;
          startTimes[id] = (e['time'] as int?) ?? 0;
          final url = (t['root_url'] ?? t['url']) as String?;
          final ln = t['root_line'] ?? t['line'];
          final col = t['root_column'] ?? t['column'];
          if (url != null) {
            locations[id] =
                '${_relativePath(url)}${ln != null ? ':$ln' : ''}${col != null ? ':$col' : ''}';
          }
        case 'print':
          prints
              .putIfAbsent(e['testID'] as int, () => [])
              .add('${e['message']}');
        case 'error':
          errors.putIfAbsent(e['testID'] as int, () => []).add((
            error: '${e['error']}'.trimRight(),
            stackTrace: '${e['stackTrace']}'.trimRight(),
            isFailure: e['isFailure'] == true,
          ));
        case 'testDone':
          final id = e['testID'] as int;
          final result = e['result'] as String? ?? 'success';
          final hidden = e['hidden'] == true;
          final start = startTimes[id];
          final time = e['time'] as int?;
          final dur = (start != null && time != null) ? time - start : null;
          if (result != 'success') {
            // Les erreurs de chargement ("loading ...") sont hidden mais
            // doivent être remontées.
            failed[id] = (result: result, durationMs: dur);
          }
          if (!hidden) {
            total++;
            if (e['skipped'] == true) {
              skipped++;
            } else if (result == 'success') {
              passed++;
            }
          }
      }
    }
  }

  final failures = <FailedTest>[
    for (final entry in failed.entries)
      FailedTest(
        suiteLabel: label,
        name: names[entry.key] ?? 'test #${entry.key}',
        file: suitePaths[suiteOfTest[entry.key]] == null
            ? null
            : _relativePath(suitePaths[suiteOfTest[entry.key]]!),
        location: locations[entry.key],
        result: entry.value.result,
        durationMs: entry.value.durationMs,
        prints: prints[entry.key] ?? const [],
        errors: errors[entry.key] ?? const [],
      ),
  ];

  return SuiteRunReport(
    label: label,
    args: args,
    exitCode: exitCode,
    total: total,
    passed: passed,
    skipped: skipped,
    failures: failures,
    reportFile: reportFile,
  );
}

String _indent(String text, [String prefix = '    ']) =>
    text.split('\n').map((l) => '$prefix$l').join('\n');

/// Écrit `test_failures.log` (lisible) et `test_failures.json` (structuré).
void writeFailureReports(List<SuiteRunReport> reports) {
  final failures = [for (final r in reports) ...r.failures];
  final b = StringBuffer();
  const sep =
      '================================================================';

  b.writeln(sep);
  b.writeln('TEST FAILURES REPORT — ${DateTime.now().toIso8601String()}');
  b.writeln(sep);
  b.writeln();
  b.writeln('Suites :');
  for (final r in reports) {
    b.writeln(
      '  - ${r.label} (flutter test ${r.args.join(' ')}) : '
      'exit=${r.exitCode}, ${r.total} tests, ${r.passed} passed, '
      '${r.skipped} skipped, ${r.failures.length} failed',
    );
  }
  b.writeln();

  // Crash / timeout / erreur de build sans test identifié
  for (final r in reports) {
    if (r.exitCode != 0 && r.failures.isEmpty) {
      b.writeln(
        '⚠ Suite "${r.label}" terminée avec exit=${r.exitCode} sans test en '
        'échec identifié (${r.exitCode == 124 ? 'TIMEOUT' : 'crash ou erreur de build'}). '
        'Voir la sortie console et ${r.reportFile}.',
      );
      b.writeln();
    }
  }

  if (failures.isNotEmpty) {
    b.writeln('Résumé (${failures.length} échec(s)) :');
    for (var i = 0; i < failures.length; i++) {
      final f = failures[i];
      b.writeln('  ${i + 1}. ${f.name}');
      b.writeln('       ${f.location ?? f.file ?? '?'}');
    }
    b.writeln();
    b.writeln(sep);
    b.writeln('DÉTAILS');
    b.writeln(sep);

    for (var i = 0; i < failures.length; i++) {
      final f = failures[i];
      b.writeln();
      b.writeln('[${i + 1}/${failures.length}] ✗ ${f.name}');
      b.writeln('  Suite    : ${f.suiteLabel}');
      if (f.file != null) b.writeln('  Fichier  : ${f.file}');
      if (f.location != null) b.writeln('  Déclaré  : ${f.location}');
      b.writeln('  Résultat : ${f.result}');
      if (f.durationMs != null) b.writeln('  Durée    : ${f.durationMs} ms');
      if (f.prints.isNotEmpty) {
        b.writeln('  Sortie (print) :');
        for (final p in f.prints) {
          b.writeln(_indent(p));
        }
      }
      for (var j = 0; j < f.errors.length; j++) {
        final e = f.errors[j];
        b.writeln(
          '  ${e.isFailure ? 'Assertion échouée' : 'Exception'}'
          '${f.errors.length > 1 ? ' (${j + 1}/${f.errors.length})' : ''} :',
        );
        b.writeln(_indent(e.error));
        if (e.stackTrace.isNotEmpty) {
          b.writeln('  Stack trace :');
          b.writeln(_indent(e.stackTrace));
        }
      }
      b.writeln('  ${'-' * 60}');
    }
  }

  File(_failuresLogPath).writeAsStringSync(b.toString());
  File(_failuresJsonPath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'generatedAt': DateTime.now().toIso8601String(),
      'suites': [
        for (final r in reports) {'label': r.label, 'args': r.args, 'exitCode': r.exitCode, 'total': r.total, 'passed': r.passed, 'skipped': r.skipped, 'failed': r.failures.length},
      ],
      'failures': [for (final f in failures) f.toJson()],
    })}\n',
  );
}

// ---------------------------------------------------------------------------
// LCOV
// ---------------------------------------------------------------------------

class LcovFileEntry {
  LcovFileEntry(this.path, this.linesCovered, this.linesTotal)
    : percentage = linesTotal == 0 ? 0 : linesCovered * 100 / linesTotal;

  final String path;
  final int linesCovered;
  final int linesTotal;
  final double percentage;

  Map<String, Object> toJson() => {
    'path': path,
    'linesCovered': linesCovered,
    'linesTotal': linesTotal,
    'percentage': double.parse(percentage.toStringAsFixed(1)),
  };
}

class LcovResult {
  LcovResult(this.buffer, this.files)
    : linesCovered = files.fold(0, (sum, f) => sum + f.linesCovered),
      linesTotal = files.fold(0, (sum, f) => sum + f.linesTotal);

  final String buffer;
  final List<LcovFileEntry> files;
  final int linesCovered;
  final int linesTotal;
  double get percentage =>
      linesTotal == 0 ? 0 : linesCovered * 100 / linesTotal;

  Map<String, Object> toJson() => {
    'linesCovered': linesCovered,
    'linesTotal': linesTotal,
    'percentage': double.parse(percentage.toStringAsFixed(1)),
    'files': [for (final f in files) f.toJson()],
  };
}

/// Generated localization getters (one per translated string, per locale)
/// are never meaningfully "tested" one by one — the widget tests that
/// exercise them only ever run against a single default locale. Counting
/// every unused-locale getter as an uncovered line makes the global
/// percentage look worse without reflecting any real risk, so they are
/// excluded from the report.
bool _isGeneratedLocalizationFile(String sourcePath) =>
    sourcePath.contains('lib/l10n/') || sourcePath.contains('lib\\l10n\\');

/// Merges multiple LCOV files by summing the hit counts (DA) per source file
/// and line. Flutter writes coverage per `--coverage` run to a single
/// `coverage/lcov.info`, so partial files are consolidated here.
LcovResult mergeLcov(List<String> files) {
  // source path -> (line -> count)
  final data = <String, Map<int, int>>{};

  for (final path in files) {
    final lines = File(path).readAsLinesSync();
    String? currentSource;
    for (final line in lines) {
      if (line.startsWith('SF:')) {
        final source = line.substring(3);
        currentSource = _isGeneratedLocalizationFile(source) ? null : source;
        if (currentSource != null) {
          data.putIfAbsent(currentSource, () => <int, int>{});
        }
      } else if (currentSource != null && line.startsWith('DA:')) {
        final parts = line.substring(3).split(',');
        final ln = int.parse(parts[0]);
        final count = int.parse(parts[1]);
        data[currentSource]![ln] = (data[currentSource]![ln] ?? 0) + count;
      }
    }
  }

  final buffer = StringBuffer();
  final fileEntries = <LcovFileEntry>[];
  for (final entry in data.entries) {
    var fileCovered = 0;
    buffer.writeln('SF:${entry.key}');
    for (final ln in entry.value.keys.toList()..sort()) {
      final count = entry.value[ln]!;
      buffer.writeln('DA:$ln,$count');
      if (count > 0) fileCovered++;
    }
    buffer.writeln('LF:${entry.value.length}');
    buffer.writeln('LH:$fileCovered');
    fileEntries.add(LcovFileEntry(entry.key, fileCovered, entry.value.length));
  }

  return LcovResult(buffer.toString(), fileEntries);
}

/// Renders the coverage summary as a fixed-width per-file table, sorted by
/// ascending coverage so the least-covered files appear first.
String printCoverageTable(LcovResult merged) {
  final rows = <(String, int, int, double)>[
    for (final f in merged.files)
      (f.path, f.linesCovered, f.linesTotal, f.percentage),
  ]..sort((a, b) => a.$4.compareTo(b.$4));

  String pad(String s, int width) =>
      s.length >= width ? s : s + ' ' * (width - s.length);

  const fileW = 70;
  const coveredW = 12;
  const totalW = 10;
  const pctW = 8;

  final buffer = StringBuffer();
  buffer.writeln(
    '${pad('File', fileW)}\t${pad('Covered', coveredW)}\t${pad('Total', totalW)}\t${pad('Pct', pctW)}',
  );
  buffer.writeln(
    '${'-' * fileW}\t${'-' * coveredW}\t${'-' * totalW}\t${'-' * pctW}',
  );

  for (final (path, coveredLines, totalLines, pct) in rows) {
    buffer.writeln(
      '${pad(path, fileW)}\t${pad('$coveredLines', coveredW)}\t${pad('$totalLines', totalW)}\t${pad('${pct.toStringAsFixed(1)}%', pctW)}',
    );
  }

  buffer.writeln(
    '${'-' * fileW}\t${'-' * coveredW}\t${'-' * totalW}\t${'-' * pctW}',
  );
  buffer.writeln(
    '${pad('TOTAL', fileW)}\t${pad('${merged.linesCovered}', coveredW)}\t${pad('${merged.linesTotal}', totalW)}\t${pad('${merged.percentage.toStringAsFixed(1)}%', pctW)}',
  );
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Mode FULL
// ---------------------------------------------------------------------------

/// Copie `coverage/lcov.info` vers `coverage/partials/<label>.info`.
String? _savePartialLcov(String label) {
  final produced = File(_lcovPath);
  if (!produced.existsSync()) return null;
  final copy = File('coverage/partials/$label.info');
  produced.copySync(copy.path);
  return copy.path;
}

void _deleteIfExists(String path) {
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
}

/// FULL : lance test/ puis integration_test/ avec coverage, sortie console
/// normale. Les échecs sont extraits dans `test_failures.log/json`. S'il n'y
/// en a aucun, le tableau de coverage est écrit dans `coverage_report.log`.
Future<void> _runFull() async {
  final reports = <SuiteRunReport>[];
  final partialFiles = <String>[];

  final suites = <(String, List<String>, Duration)>[
    ('unit_widget_tests', ['--coverage', 'test'], _defaultTimeout),
    (
      'integration_tests',
      ['--coverage', 'integration_test'],
      const Duration(minutes: 18),
    ),
  ];

  for (final (label, args, timeout) in suites) {
    final report = await runSuiteWithReport(label, args, timeout: timeout);
    reports.add(report);
    if (report.exitCode == 0) {
      final partial = _savePartialLcov(label);
      if (partial != null) partialFiles.add(partial);
    }
  }

  final failedCount = reports.fold<int>(0, (s, r) => s + r.failures.length);
  final hasProblem = reports.any((r) => r.hasProblem);

  if (hasProblem) {
    writeFailureReports(reports);
    // Pas de coverage fiable si des tests échouent : on évite un rapport périmé.
    _deleteIfExists(_coverageLogPath);
    _deleteIfExists(_coverageJsonPath);
    exitCode = reports
        .firstWhere((r) => r.exitCode != 0, orElse: () => reports.first)
        .exitCode;
    if (exitCode == 0) exitCode = 1;
    stdout.writeln(
      '\n✗ $failedCount test(s) en échec — détails dans '
      '$_failuresLogPath (et $_failuresJsonPath)',
    );
    return;
  }

  // Aucun échec : on nettoie les anciens rapports d'échecs et on écrit le coverage.
  _deleteIfExists(_failuresLogPath);
  _deleteIfExists(_failuresJsonPath);

  if (partialFiles.isEmpty) return;
  final merged = mergeLcov(partialFiles);
  File(_lcovPath).writeAsStringSync('${merged.buffer}\n');
  File(_coverageJsonPath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(merged.toJson())}\n',
  );
  File(_coverageLogPath).writeAsStringSync(
    '--- Coverage Report (${DateTime.now().toIso8601String()}) ---\n'
    '${printCoverageTable(merged)}',
  );
  stdout.writeln(
    '\n✔ Tous les tests passent — ${merged.percentage.toStringAsFixed(1)}% de '
    'coverage (tableau dans $_coverageLogPath)',
  );
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  final mode = args.isEmpty ? 'all' : args.first;

  if (mode == 'integration') {
    exitCode = await runFlutterTest([
      'integration_test',
    ], timeout: const Duration(minutes: 12));
    return;
  }

  // Ensure partials directory exists
  Directory('coverage/partials').createSync(recursive: true);

  if (mode == 'full') {
    await _runFull();
    return;
  }

  // Suites are intentionally disjoint. This runner is a test-pyramid tool,
  // not a collection of overlapping coverage jobs: every test file belongs to
  // one responsibility group and `all` delegates to Flutter once.
  final suites = switch (mode) {
    'all' => [
      ['test'],
    ],
    'fast' || 'domain' => [
      ['test/core', 'test/models', 'test/unit', 'test/shared/domain'],
    ],
    'services' => [
      ['test/services'],
    ],
    'state' => [
      ['test/state'],
    ],
    'features' => [
      ['test/pages'],
    ],
    'regression' => [
      ['test/regression'],
    ],
    'widgets' => [
      ['test/widget', 'test/golden'],
    ],
    _ => throw ArgumentError(
      'Unknown mode "$mode". Use fast, domain, services, state, features, widgets, regression, integration, full, or all.',
    ),
  };

  // Run unit/widget suites without coverage first for speed, then one coverage run
  for (final suite in suites) {
    final code = await runFlutterTest(suite);
    if (code != 0) {
      exitCode = code;
      return;
    }
  }
  // Single coverage collection for the entire test/ directory
  final code = await runFlutterTest(['--coverage', 'test']);
  if (code != 0) {
    exitCode = code;
    return;
  }
  final partial = _savePartialLcov('all_tests');
  if (partial != null) {
    stdout.writeln('  - saved $partial');
    final merged = mergeLcov([partial]);
    stdout.writeln('\n--- Coverage Report ---');
    stdout.writeln(printCoverageTable(merged));
    File(_lcovPath).writeAsStringSync('${merged.buffer}\n');
    File('coverage/coverage_report.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(merged.toJson())}\n',
    );
    stdout.writeln('LCOV report written to $_lcovPath.');
    stdout.writeln('JSON report written to coverage/coverage_report.json.');
  }
}
