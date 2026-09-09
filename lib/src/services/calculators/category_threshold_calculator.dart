import 'dart:math' as math;

enum CategoryThresholdState { normal, warning, exceeded, disabled }

class CategoryThresholdProgress {
  final double total;
  final double threshold;
  final double rawProgress;
  final double progress;
  final double remaining;
  final double overshoot;
  final CategoryThresholdState state;

  const CategoryThresholdProgress({
    required this.total,
    required this.threshold,
    required this.rawProgress,
    required this.progress,
    required this.remaining,
    required this.overshoot,
    required this.state,
  });

  bool get isEnabled => state != CategoryThresholdState.disabled;
}

/// Pure monthly category-threshold calculation, reusable outside the UI.
class CategoryThresholdCalculator {
  static const double defaultWarningRatio = .8;

  const CategoryThresholdCalculator({this.warningRatio = defaultWarningRatio});

  final double warningRatio;

  CategoryThresholdProgress calculate({
    required double total,
    required double? threshold,
  }) {
    final safeTotal = math.max(0.0, total);
    if (threshold == null || threshold <= 0) {
      return CategoryThresholdProgress(
        total: safeTotal,
        threshold: threshold ?? 0.0,
        rawProgress: 0,
        progress: 0,
        remaining: 0,
        overshoot: 0,
        state: CategoryThresholdState.disabled,
      );
    }

    final rawProgress = safeTotal / threshold;
    final state = safeTotal >= threshold
        ? CategoryThresholdState.exceeded
        : safeTotal >= threshold * warningRatio
            ? CategoryThresholdState.warning
            : CategoryThresholdState.normal;
    return CategoryThresholdProgress(
      total: safeTotal,
      threshold: threshold,
      rawProgress: rawProgress,
      progress: rawProgress.clamp(0.0, 1.0),
      remaining: math.max(0, threshold - safeTotal),
      overshoot: math.max(0, safeTotal - threshold),
      state: state,
    );
  }
}
