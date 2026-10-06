import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/overview/revenue_provider.dart';
import 'package:budgly/src/pages/overview/widgets/collapsing_summary_header.dart';
import 'package:budgly/src/state/action_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/builders.dart';

void main() {
  final theme = ThemeData.light();
  final account = Fixtures.account(id: 'a1');

  CollapsingSummaryHeader header({
    int revision = 7,
    String currencyCode = 'EUR',
    String localeName = 'fr',
    int amountDecimalPlaces = 2,
  }) => CollapsingSummaryHeader(
    accounts: [account],
    account: account,
    period: const Period(year: 2026, month: 10),
    categorySummaries: const [],
    revenue: const RevenueState(
      revenue: 0,
      inheritedRevenue: null,
      isLoaded: true,
      showEditor: false,
      status: ActionStatus.idle(),
    ),
    currencyCode: currencyCode,
    localeName: localeName,
    amountDecimalPlaces: amountDecimalPlaces,
    onSelectAccount: (_) {},
    revision: revision,
    theme: theme,
  );

  test('the summary header is reused when nothing it renders changed', () {
    expect(header().shouldRebuild(header()), isFalse);
  });

  test('the summary header rebuilds when its content revision changes', () {
    expect(header().shouldRebuild(header(revision: 42)), isTrue);
  });

  test('the summary header rebuilds when only the formatting changes', () {
    // Regression: the raw amounts stay identical when the profile precision,
    // currency or locale changes, so a value-only revision comparison kept
    // the previously formatted strings on screen when returning to Overview.
    final before = header();
    expect(before.shouldRebuild(header(amountDecimalPlaces: 0)), isTrue);
    expect(before.shouldRebuild(header(currencyCode: 'USD')), isTrue);
    expect(before.shouldRebuild(header(localeName: 'en')), isTrue);
  });
}
