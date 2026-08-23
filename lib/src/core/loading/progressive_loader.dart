import 'package:budgly/src/core/logging/logger.dart';

class ProgressiveLoader {

  static Future<void> loadEssentialOnly({
    required Future<void> Function() essentialData,
    required Future<void> Function() secondaryData,
    required Function(double) onProgress,
  }) async {
    try {
      await essentialData();
      onProgress(0.5);

      try {
        await secondaryData();
      } catch (e) {
        AppLogger.warning('Secondary data loading failed, continuing anyway: $e');
      }

      onProgress(1.0);
    } catch (e) {
      AppLogger.error('Essential data loading failed', e);
      rethrow;
    }
  }
}
