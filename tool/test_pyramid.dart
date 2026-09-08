import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _defaultTimeout = Duration(minutes: 8);

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

  try {
    return await process.exitCode.timeout(timeout);
  } on TimeoutException {
    stderr.writeln('TIMEOUT after $timeout: flutter test ${arguments.join(' ')}');
    process.kill(ProcessSignal.sigterm);
    await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () => -1,
    );
    return 124;
  }
}

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
  double get percentage => linesTotal == 0 ? 0 : linesCovered * 100 / linesTotal;

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
    fileEntries.add(
      LcovFileEntry(entry.key, fileCovered, entry.value.length),
    );
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
  buffer.writeln('${'-' * fileW}\t${'-' * coveredW}\t${'-' * totalW}\t${'-' * pctW}');

  for (final (path, coveredLines, totalLines, pct) in rows) {
    buffer.writeln(
      '${pad(path, fileW)}\t${pad('$coveredLines', coveredW)}\t${pad('$totalLines', totalW)}\t${pad('${pct.toStringAsFixed(1)}%', pctW)}',
    );
  }

  buffer.writeln('${'-' * fileW}\t${'-' * coveredW}\t${'-' * totalW}\t${'-' * pctW}');
  buffer.writeln(
    '${pad('TOTAL', fileW)}\t${pad('${merged.linesCovered}', coveredW)}\t${pad('${merged.linesTotal}', totalW)}\t${pad('${merged.percentage.toStringAsFixed(1)}%', pctW)}',
  );
  return buffer.toString();
}

Future<void> main(List<String> args) async {
  final mode = args.isEmpty ? 'all' : args.first;

  if (mode == 'integration') {
    exitCode = await runFlutterTest(
      ['integration_test'],
      timeout: const Duration(minutes: 12),
    );
    return;
  }

  if (mode == 'all') {
    final allSuites = [["test"], ["integration_test"]];
    final partialDir = Directory('coverage/partials');
    partialDir.createSync(recursive: true);
    final partialFiles = <String>[];
    for (var i = 0; i < allSuites.length; i++) {
      final code = await runFlutterTest(
        ['--coverage', ...allSuites[i]],
        timeout: allSuites[i].first == 'integration_test'
            ? const Duration(minutes: 18)
            : _defaultTimeout,
      );
      if (code != 0) {
        exitCode = code;
        return;
      }
      final produced = File('coverage/lcov.info');
      if (produced.existsSync()) {
        final copy = File('coverage/partials/cov_$i.info');
        produced.copySync(copy.path);
        partialFiles.add(copy.path);
        stdout.writeln('  - saved ${copy.path}');
      }
    }

    // 4. Merge the per-suite LCOV files and generate reports.
    if (exitCode == 0 && partialFiles.isNotEmpty) {
      stdout.writeln('\nMerging coverage data...');
      final merged = mergeLcov(partialFiles);
      final mergedFile = File('coverage/lcov.info');
      mergedFile.writeAsStringSync('${merged.buffer}\n');
      File('coverage/coverage_report.json')
          .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(merged.toJson())}\n');

      // 5. Print a per-file table and a global summary.
      stdout.writeln('\n--- Coverage Report ---');
      stdout.writeln(printCoverageTable(merged));
      stdout.writeln('LCOV report written to coverage/lcov.info.');
      stdout.writeln('JSON report written to coverage/coverage_report.json.');
    }
    return;
  }

  final suites = switch (mode) {
    'fast' => [
        ['test/core', 'test/models', 'test/unit'],
        ['test/services/calculators', 'test/services/categories', 'test/services/budget'],
      ],
    'services' => [
        ['test/services'],
      ],
    'domain' => [
        ['test/core', 'test/models', 'test/unit'],
      ],
    'features' => [
        ['test/pages', 'test/stores', 'test/shared'],
      ],
    'regression' => [
        ['test/regression'],
      ],
    'widgets' => [
        ['test/widget', 'test/golden'],
      ],
    _ => throw ArgumentError(
        'Unknown mode "$mode". Use fast, domain, services, features, regression, widgets, integration, coverage or all.',
      ),
  };

  for (final suite in suites) {
    final code = await runFlutterTest(suite);
    if (code != 0) {
      exitCode = code;
      return;
    }
  }
}
