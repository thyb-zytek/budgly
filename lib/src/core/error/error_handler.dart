import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/services/errors.dart';

class ErrorHandler {
  static void handleError(Object error, StackTrace? stackTrace) {
    AppLogger.error('Error occurred', error, stackTrace);
    ErrorService.instance.reportError();
  }

  static void handleAsyncError(Object error, StackTrace stackTrace) {
    handleError(error, stackTrace);
  }

  static void logWarning(String message) {
    AppLogger.warning(message);
  }

  static void logInfo(String message) {
    AppLogger.info(message);
  }

  static void logDebug(String message) {
    AppLogger.debug(message);
  }
}