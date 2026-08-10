import 'package:budgly/src/core/logging/logger.dart';

class ProgressiveLoader {
  /// Load data progressively - essential data first, then secondary data
  static Future<void> loadProgressively({
    required Future<void> Function() essentialData,
    required Future<void> Function() secondaryData,
    required Function(double) onProgress,
    String? essentialTaskName,
    String? secondaryTaskName,
  }) async {
    try {
      if (essentialTaskName != null) {
        AppLogger.debug('Starting essential task: $essentialTaskName');
      }
      
      await essentialData();
      onProgress(0.5); // 50% after essential data
      
      if (essentialTaskName != null) {
        AppLogger.debug('Completed essential task: $essentialTaskName');
      }
      
      if (secondaryTaskName != null) {
        AppLogger.debug('Starting secondary task: $secondaryTaskName');
      }
      
      await secondaryData();
      onProgress(1.0); // 100% after secondary data
      
      if (secondaryTaskName != null) {
        AppLogger.debug('Completed secondary task: $secondaryTaskName');
      }
    } catch (e) {
      AppLogger.error('Progressive loading failed', e);
      rethrow;
    }
  }

  /// Load data with custom phases
  static Future<void> loadWithPhases({
    required List<Future<void> Function()> phases,
    required Function(double) onProgress,
    List<String>? phaseNames,
  }) async {
    try {
      for (int i = 0; i < phases.length; i++) {
        if (phaseNames != null && i < phaseNames.length) {
          AppLogger.debug('Starting phase ${i + 1}/${phases.length}: ${phaseNames[i]}');
        }
        
        await phases[i]();
        
        final progress = (i + 1) / phases.length;
        onProgress(progress);
        
        if (phaseNames != null && i < phaseNames.length) {
          AppLogger.debug('Completed phase ${i + 1}/${phases.length}: ${phaseNames[i]}');
        }
      }
    } catch (e) {
      AppLogger.error('Phase loading failed', e);
      rethrow;
    }
  }

  /// Load essential data only, skip secondary if essential fails
  static Future<void> loadEssentialOnly({
    required Future<void> Function() essentialData,
    required Future<void> Function() secondaryData,
    required Function(double) onProgress,
  }) async {
    try {
      await essentialData();
      onProgress(0.5);
      
      // Try secondary data but don't fail if it errors
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

  /// Parallel loading with progress tracking
  static Future<void> loadParallel({
    required List<Future<void> Function()> tasks,
    required Function(double) onProgress,
    List<String>? taskNames,
  }) async {
    try {
      if (taskNames != null) {
        AppLogger.debug('Starting ${tasks.length} parallel tasks');
      }
      
      await Future.wait(
        tasks.map((task) => task()),
      );
      
      onProgress(1.0);
      
      if (taskNames != null) {
        AppLogger.debug('Completed ${tasks.length} parallel tasks');
      }
    } catch (e) {
      AppLogger.error('Parallel loading failed', e);
      rethrow;
    }
  }
}