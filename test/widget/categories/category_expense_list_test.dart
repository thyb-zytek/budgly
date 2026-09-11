import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_expense_list.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';
import '../../helpers/pump_app.dart';

void main() {
  setUp(Fixtures.resetSeq);

  group('CategoryExpenseList', () {
    testWidgets('renders one row per summary', (tester) async {
      final summaries = [
        CategoryExpenseSummary(
          category: Fixtures.category(accountId: 'acc-1', name: 'Courses'),
          total: 50,
          debited: 50,
          undebited: 0,
          undebitedCount: 0,
        ),
        CategoryExpenseSummary(
          category: Fixtures.category(accountId: 'acc-1', name: 'Loisirs'),
          total: 30,
          debited: 20,
          undebited: 10,
          undebitedCount: 1,
        ),
      ];

      await pumpApp(
        tester,
        CategoryExpenseList(
          summaries: summaries,
          currencyCode: 'EUR',
          localeName: 'fr',
        ),
      );

      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('Loisirs'), findsOneWidget);
    });

    testWidgets('tapping a row calls onTapCategory with the matching summary', (tester) async {
      final courses = CategoryExpenseSummary(
        category: Fixtures.category(accountId: 'acc-1', name: 'Courses'),
        total: 50,
        debited: 50,
        undebited: 0,
        undebitedCount: 0,
      );
      final loisirs = CategoryExpenseSummary(
        category: Fixtures.category(accountId: 'acc-1', name: 'Loisirs'),
        total: 30,
        debited: 30,
        undebited: 0,
        undebitedCount: 0,
      );

      CategoryExpenseSummary? tapped;

      await pumpApp(
        tester,
        CategoryExpenseList(
          summaries: [courses, loisirs],
          currencyCode: 'EUR',
          localeName: 'fr',
          onTapCategory: (summary) => tapped = summary,
        ),
      );

      await tester.tap(find.text('Loisirs'));
      await tester.pump();

      expect(tapped, loisirs);
    });

    testWidgets('renders nothing for an empty list', (tester) async {
      await pumpApp(
        tester,
        const CategoryExpenseList(
          summaries: [],
          currencyCode: 'EUR',
          localeName: 'fr',
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
