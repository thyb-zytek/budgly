import 'package:budgly/src/core/navigation/navigation_helper.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NavigationHelper exposes stable top-level paths', () {
    expect(NavigationHelper.loginPath, '/login');
    expect(NavigationHelper.tutorialPath, '/tutorial');
    expect(NavigationHelper.overviewPath, '/overview');
    expect(NavigationHelper.settingsPath, '/settings');
    expect(NavigationHelper.categoryExpensesPath, contains('category'));
  });

  test('NavigationHelper builds category detail path with and without period', () {
    expect(
      NavigationHelper.buildCategoryExpensesPath('a1', 'c1', const Period(year: 2026, month: 8)),
      contains('2026'),
    );
    expect(
      NavigationHelper.buildCategoryExpensesPath('a1', 'c1', null),
      isNot(contains('2026')),
    );
  });

  test('design tokens expose coherent spacing, radius and button dimensions', () {
    expect(BudglySpacing.xs, lessThan(BudglySpacing.sm));
    expect(BudglySpacing.sm, lessThan(BudglySpacing.md));
    expect(BudglySpacing.md, lessThan(BudglySpacing.lg));
    expect(BudglySpacing.lg, lessThan(BudglySpacing.xl));
    expect(BudglySpacing.xl, lessThan(BudglySpacing.xxl));
    expect(BudglyRadius.small, isNotNull);
    expect(BudglyRadius.extraLarge, isNotNull);
    expect(BudglyButtonDimensions.normalPadding.horizontal, greaterThan(BudglyButtonDimensions.densePadding.horizontal));
    expect(BudglyComponentStyles.fabSize, greaterThan(BudglyComponentStyles.fabIconSize));
  });
}
