import 'dart:math' as math;
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:flutter/material.dart';

class CategoryDonutChart extends StatefulWidget {
  final List<CategoryExpenseSummary> summaries;
  final double size;
  final double strokeWidthFactor;
  final Widget? centerChild;

  final double? referenceTotal;

  final Color? emptyColor;

  final ValueChanged<CategoryExpenseSummary>? onCategoryTap;

  const CategoryDonutChart({
    super.key,
    required this.summaries,
    required this.size,
    this.strokeWidthFactor = 0.15,
    this.centerChild,
    this.referenceTotal,
    this.emptyColor,
    this.onCategoryTap,
  });

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {

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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final summary = _hitTest(details.localPosition);
        if (summary != null) widget.onCategoryTap?.call(summary);
      },
      child: SizedBox(
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
                    strokeWidthFactor: widget.strokeWidthFactor,
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
      ),
    );
  }

  CategoryExpenseSummary? _hitTest(Offset position) {
    if (widget.summaries.isEmpty) return null;
    final center = Offset(widget.size / 2, widget.size / 2);
    final distance = (position - center).distance;
    final stroke = widget.size * widget.strokeWidthFactor;
    final radius = (widget.size - stroke) / 2;
    if (distance < radius - stroke / 2 || distance > radius + stroke / 2) {
      return null;
    }

    final categoriesTotal = widget.summaries.fold<double>(
      0,
      (sum, s) => sum + s.total,
    );
    if (categoriesTotal <= 0) return null;
    final total =
        (widget.referenceTotal != null &&
            widget.referenceTotal! > categoriesTotal)
        ? widget.referenceTotal!
        : categoriesTotal;

    var angle =
        math.atan2(position.dy - center.dy, position.dx - center.dx) +
        math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    var cursor = 0.0;
    for (final summary in widget.summaries) {
      final sweep = (summary.total / total) * 2 * math.pi;
      if (angle >= cursor && angle < cursor + sweep) return summary;
      cursor += sweep;
    }
    return null;
  }
}

class _DonutPainter extends CustomPainter {
  final List<CategoryExpenseSummary> summaries;
  final double? referenceTotal;
  final Color emptyColor;
  final double progress;
  final double strokeWidthFactor;

  _DonutPainter({
    required this.summaries,
    required this.referenceTotal,
    required this.emptyColor,
    required this.progress,
    required this.strokeWidthFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * strokeWidthFactor;
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

    final categoriesTotal = summaries.fold<double>(
      0,
      (sum, s) => sum + s.total,
    );
    if (categoriesTotal <= 0) return;

    final total = (referenceTotal != null && referenceTotal! > categoriesTotal)
        ? referenceTotal!
        : categoriesTotal;

    double startAngle = -math.pi / 2;

    for (final summary in summaries) {
      final fullSweep = (summary.total / total) * 2 * math.pi;
      final sweep = fullSweep * progress;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color = summary.category.color ?? emptyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.summaries != summaries ||
      oldDelegate.referenceTotal != referenceTotal ||
      oldDelegate.strokeWidthFactor != strokeWidthFactor;
}
