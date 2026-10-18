import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/overview/ui_state.dart';
import 'package:budgly/src/pages/overview/widgets/collapsing_summary_header.dart';
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
    Account? selectedAccount,
  }) => CollapsingSummaryHeader(
    accounts: [selectedAccount ?? account],
    account: selectedAccount ?? account,
    period: const Period(year: 2026, month: 10),
    categorySummaries: const [],
    revenue: const RevenueSummary(revenue: 0, inheritedRevenue: null),
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

  test('the summary header rebuilds when only the selected account changed', () {
    // Regression: a background revalidation resolves the account's signed
    // picture URL without changing anything else the header renders. `Account`
    // equality/hashCode are id-only, so `revision` — which hashes the account
    // object — stayed identical and the header kept the previous, picture-less
    // avatar until an unrelated change (e.g. pull-to-refresh) forced a rebuild.
    final before = header();
    expect(
      before.shouldRebuild(
        header(
          selectedAccount: account.copyWith(
            pictureUrl: 'https://example.test/pic.jpg',
          ),
        ),
      ),
      isTrue,
    );
    expect(
      before.shouldRebuild(
        header(selectedAccount: account.copyWith(name: 'X')),
      ),
      isTrue,
    );
    expect(
      before.shouldRebuild(
        header(
          selectedAccount: account.copyWith(color: const Color(0xFF000000)),
        ),
      ),
      isTrue,
    );
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
