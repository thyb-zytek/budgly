import 'dart:ui';

import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/models/user/user_profile.dart';

/// Deterministic factories for every domain entity.
///
/// All IDs are stable, dates are derived from the given [Period] so tests
/// remain deterministic regardless of `DateTime.now()`.
class Fixtures {
  Fixtures._();

  static int _seq = 0;
  static String _nextId(String prefix) => '$prefix-${++_seq}';
  static void resetSeq() => _seq = 0;

  static Account account({
    String? id,
    String name = 'Compte courant',
    Color color = const Color(0xFF42A5F5),
    String? picture,
    String? pictureUrl,
  }) => Account(
        id: id ?? _nextId('acc'),
        name: name,
        color: color,
        picture: picture,
        pictureUrl: pictureUrl,
      );

  static CategoryIcon categoryIcon({
    String iconName = 'groceries',
    int iconCode = 0xe800,
    String iconPack = 'BudglyIcons',
    Map<String, String> labels = const {'en': 'Groceries', 'fr': 'Courses'},
  }) => CategoryIcon(
        iconName: iconName,
        iconCode: iconCode,
        iconPack: iconPack,
        labels: labels,
      );

  static Category category({
    String? id,
    required String accountId,
    String name = 'Courses',
    Color color = const Color(0xFF66BB6A),
    CategoryIcon? icon,
  }) => Category(
        id: id ?? _nextId('cat'),
        accountId: accountId,
        name: name,
        color: color,
        icon: icon ?? categoryIcon(),
      );

  static Expense expense({
    String? id,
    required String accountId,
    required String categoryId,
    String name = 'Dépense',
    double amount = 42.0,
    DateTime? debitDate,
    DateTime? endDate,
    RecurrenceType recurrence = RecurrenceType.none,
    int? recurrenceAnchorDay,
    bool isDebited = false,
    List<String> debitedOccurrences = const [],
  }) => Expense(
        id: id ?? _nextId('exp'),
        accountId: accountId,
        categoryId: categoryId,
        name: name,
        amount: amount,
        debitDate: debitDate ?? DateTime(2026, 3, 15),
        endDate: endDate,
        recurrence: recurrence,
        recurrenceAnchorDay: recurrenceAnchorDay,
        isDebited: isDebited,
        debitedOccurrences: debitedOccurrences,
      );

  static AccountBudget budget({
    String? id,
    required String accountId,
    required Period period,
    double revenue = 2000,
  }) => AccountBudget(
        id: id ?? '${accountId}_${period.year}_${period.month}',
        accountId: accountId,
        year: period.year,
        month: period.month,
        revenue: revenue,
      );

  static UserProfile profile({
    String id = 'user-1',
    String email = 'test@budgly.app',
    String fullName = 'Test User',
    String currency = 'EUR',
    String language = 'fr',
    int amountDecimalPlaces = 2,
    bool onboardingCompleted = true,
  }) => UserProfile(
        id: id,
        email: email,
        fullName: fullName,
        currency: currency,
        language: language,
        amountDecimalPlaces: amountDecimalPlaces,
        onboardingCompleted: onboardingCompleted,
      );

  static Period period(int year, int month) => Period(year: year, month: month);

  static DateTime date(int year, int month, int day) => DateTime(year, month, day);
}
