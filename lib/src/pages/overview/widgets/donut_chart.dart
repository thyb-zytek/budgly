import 'dart:math' as math;
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:flutter/material.dart';

/// Donut chart showing the split of expenses per category.
///
/// The arcs animate in whenever the data changes, which makes the
/// chart feel alive when switching accounts or periods instead of
/// popping instantly.
class CategoryDonutChart extends StatefulWidget {
  final List<CategoryExpenseSummary> summaries;
  final double size;
  final Widget? centerChild;

  /// Reference total the slices are measured against — pass the
  /// period's revenue here. When it's greater than the sum of the
  /// category totals, the leftover arc stays visible in [emptyColor],
  /// representing budget that hasn't been spent yet. Falls back to
  /// the sum of category totals (old behaviour, full ring) when null,
  /// zero, or lower than that sum — e.g. no revenue set yet, or the
  /// account is over budget.
  final double? referenceTotal;

  /// Color of the unallocated portion of the ring. Defaults to
  /// [ColorScheme.outlineVariant] so it reads as "empty" rather than
  /// as a colored category.
  final Color? emptyColor;

  const CategoryDonutChart({
    super.key,
    required this.summaries,
    required this.size,
    this.centerChild,
    this.referenceTotal,
    this.emptyColor,
  });

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  // Bump every time the data changes so TweenAnimationBuilder replays
  // the sweep-in animation instead of jumping straight to the new state.
  Key _animationKey = UniqueKey();

  @override
  void didUpdateWidget(covariant CategoryDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameData(oldWidget)) {
      _animationKey = UniqueKey();
    }
  }

  bool _sameData(CategoryDonutChart oldWidget) {
    if (oldWidget.referenceTotal != widget.referenceTotal) return false;
    final a = oldWidget.summaries;
    final b = widget.summaries;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].category.id != b[i].category.id || a[i].total != b[i].total) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            key: _animationKey,
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _DonutPainter(
                  summaries: widget.summaries,
                  referenceTotal: widget.referenceTotal,
                  emptyColor: widget.emptyColor ?? theme.colorScheme.outline,
                  progress: progress,
                ),
              );
            },
          ),
          if (widget.centerChild != null)
            Padding(
              padding: const EdgeInsets.all(28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: widget.centerChild,
              ),
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<CategoryExpenseSummary> summaries;
  final double? referenceTotal;
  final Color emptyColor;
  final double progress;

  _DonutPainter({
    required this.summaries,
    required this.referenceTotal,
    required this.emptyColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.11;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final emptyPaint = Paint()
      ..color = emptyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, emptyPaint);

    final categoriesTotal = summaries.fold<double>(0, (sum, s) => sum + s.total);
    if (categoriesTotal <= 0) return;

    final total = (referenceTotal != null && referenceTotal! > categoriesTotal)
        ? referenceTotal!
        : categoriesTotal;

    final gap = summaries.length > 1 ? 0.035 : 0.0;
    double startAngle = -math.pi / 2;

    for (final summary in summaries) {
      final fullSweep = (summary.total / total) * 2 * math.pi;
      final sweep = fullSweep * progress;
      final paint = Paint()
        ..color = summary.category.color ?? emptyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final drawnSweep = (sweep - gap).clamp(0.0, sweep);
      if (drawnSweep > 0) {
        canvas.drawArc(rect, startAngle + gap / 2, drawnSweep, false, paint);
      }
      startAngle += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.summaries != summaries ||
      oldDelegate.referenceTotal != referenceTotal;
}