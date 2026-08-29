import 'package:flutter/material.dart';

abstract final class BudglySpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class BudglyRadius {
  static const sm = Radius.circular(8);
  static const md = Radius.circular(12);
  static const lg = Radius.circular(16);
  static const xl = Radius.circular(20);

  static const small = BorderRadius.all(sm);
  static const medium = BorderRadius.all(md);
  static const large = BorderRadius.all(lg);
  static const extraLarge = BorderRadius.all(xl);
}

abstract final class BudglyButtonDimensions {
  static const normalPadding = EdgeInsets.symmetric(
    horizontal: BudglySpacing.xl,
    vertical: BudglySpacing.lg,
  );
  static const densePadding = EdgeInsets.symmetric(
    horizontal: BudglySpacing.lg,
    vertical: BudglySpacing.sm,
  );
}

abstract final class BudglyComponentStyles {
  static const cardPadding = EdgeInsets.fromLTRB(
    BudglySpacing.lg,
    BudglySpacing.md,
    BudglySpacing.sm,
    BudglySpacing.md,
  );

  static const fabSize = 64.0;
  static const fabIconSize = 48.0;
}
