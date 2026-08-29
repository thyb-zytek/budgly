import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';


class AppLogger {
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    }
    _recordError(error ?? message, stackTrace, reason: message);
  }

  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('[WARN] $message');
    }
    _log('[WARN] $message');
  }

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
    _log('[INFO] $message');
  }

  static void _recordError(
    Object error,
    StackTrace? stackTrace, {
    required String reason,
  }) {
    try {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: reason,
          fatal: false,
        ),
      );
    } catch (_) {
    }
  }

  static void _log(String message) {
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {
    }
  }
}
