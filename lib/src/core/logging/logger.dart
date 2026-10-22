import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Application logs are written to Android's log stream in every build so
/// release APK diagnostics can be collected with `adb logcat`.
class AppLogger {
  static const _name = 'Budgly';

  static void debug(String message) => _write('DEBUG', message, level: 500);

  static void info(String message) {
    _write('INFO', message, level: 800);
    _log(_safe(message));
  }

  static void warning(String message) {
    _write('WARN', message, level: 900);
    _log('[WARN] ${_safe(message)}');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    logOnlyError(message, error, stackTrace);
    _recordError(error ?? message, stackTrace, reason: _safe(message));
  }

  /// Writes an error to Logcat without creating a second Crashlytics report.
  static void logOnlyError(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final safeMessage = _safe(message);
    final details = error == null
        ? safeMessage
        : '$safeMessage (errorType=${error.runtimeType}, '
              'error=${_safe(error.toString())})';
    _write('ERROR', details, level: 1000, stackTrace: stackTrace);
  }

  static String _safe(String value) {
    return value
        .replaceAll(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'), '<email>')
        .replaceAll(
          RegExp(r'(bearer\s+)[A-Za-z0-9._~+/-]+=*', caseSensitive: false),
          r'$1<redacted>',
        )
        .replaceAll(
          RegExp(
            r'(password|passwd|token|secret|authorization|api[_-]?key|'
            r'client[_-]?secret|id[_-]?token|access[_-]?token|'
            r'refresh[_-]?token)(\s*[=:]\s*)[^\s,;]+',
            caseSensitive: false,
          ),
          r'$1$2<redacted>',
        );
  }

  static void _write(
    String levelName,
    String message, {
    required int level,
    StackTrace? stackTrace,
  }) {
    developer.log(
      '[$levelName] ${_safe(message)}',
      name: _name,
      level: level,
      stackTrace: stackTrace,
    );
  }

  static void _recordError(
    Object error,
    StackTrace? stackTrace, {
    required String reason,
  }) {
    try {
      unawaited(
        FirebaseCrashlytics.instance
            .recordError(error, stackTrace, reason: reason, fatal: false)
            .catchError((_) {}),
      );
    } catch (_) {}
  }

  static void _log(String message) {
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }
}
