import 'dart:math';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/state/action_status.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'categories_settings_provider.g.dart';

class CategoriesSettingsState {
  const CategoriesSettingsState({
    required this.account,
    required this.localCategories,
    required this.editingCategory,
    required this.availableIcons,
    required this.status,
  });

  final Account? account;
  final List<Category> localCategories;
  final Category? editingCategory;
  final List<CategoryIcon> availableIcons;
  final ActionStatus status;

  bool get isCreatingCategory => localCategories.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoriesSettingsState &&
          other.account == account &&
          listEquals(other.localCategories, localCategories) &&
          other.editingCategory == editingCategory &&
          listEquals(other.availableIcons, availableIcons) &&
          other.status == status;

  @override
  int get hashCode => Object.hash(
    account,
    Object.hashAll(localCategories),
    editingCategory,
    Object.hashAll(availableIcons),
    status,
  );

  CategoriesSettingsState copyWith({
    Account? account,
    bool clearAccount = false,
    List<Category>? localCategories,
    Category? editingCategory,
    bool clearEditingCategory = false,
    List<CategoryIcon>? availableIcons,
    ActionStatus? status,
  }) {
    return CategoriesSettingsState(
      account: clearAccount ? null : account ?? this.account,
      localCategories: localCategories ?? this.localCategories,
      editingCategory: clearEditingCategory
          ? null
          : editingCategory ?? this.editingCategory,
      availableIcons: availableIcons ?? this.availableIcons,
      status: status ?? this.status,
    );
  }
}

@riverpod
class CategoriesSettings extends _$CategoriesSettings {
  @override
  CategoriesSettingsState build() => const CategoriesSettingsState(
    account: null,
    localCategories: [],
    editingCategory: null,
    availableIcons: [],
    status: ActionStatus.idle(),
  );

  List<Category> categoriesFor(Account? account) {
    final accountId = account?.id;
    if (accountId == null) return state.localCategories;
    return [
      ...ref.read(categoriesSessionProvider).categoriesByAccount[accountId] ??
          const [],
      ...state.localCategories,
    ];
  }

  bool hasCategoriesLoaded(Account? account) {
    final accountId = account?.id;
    return accountId != null &&
        ref.read(categoriesSessionProvider).loadedAccounts.contains(accountId);
  }

  void selectAccount(Account? account) {
    if (account?.id == state.account?.id) return;
    state = state.copyWith(
      account: account,
      localCategories: const [],
      clearEditingCategory: true,
    );
    if (account?.id != null && !hasCategoriesLoaded(account)) {
      loadCategories();
    }
  }

  void setEditingCategory(Category? category) {
    state = state.copyWith(
      editingCategory: category,
      clearEditingCategory: category == null,
    );
  }

  void cancelEdit() {
    state = state.copyWith(clearEditingCategory: true);
  }

  Future<void> loadCategories() async {
    final accountId = state.account?.id;
    if (accountId == null) return;

    state = state.copyWith(status: state.status.loading());
    try {
      await Future.wait([
        ref.read(categoriesSessionProvider.notifier).loadIcons(),
        ref.read(categoriesSessionProvider.notifier).load(accountId),
      ]);
      if (!ref.mounted) return;
      state = state.copyWith(
        availableIcons: ref.read(categoriesSessionProvider).availableIcons,
        status: state.status.doneLoading(),
      );
    } catch (e, stackTrace) {
      if (!ref.mounted) return;
      if (classifyError(e) == AppMessageKey.networkError) {
        AppLogger.error(
          'Failed to load categories while offline',
          e,
          stackTrace,
        );
        state = state.copyWith(status: state.status.doneLoading());
      } else {
        state = state.copyWith(status: state.status.failure(e));
      }
    }
  }

  Future<Category?> addCategory() async {
    final account = state.account;
    if (account?.id == null || state.localCategories.isNotEmpty) return null;

    state = state.copyWith(status: state.status.loading());
    try {
      await ref.read(categoriesSessionProvider.notifier).loadIcons();
      if (!ref.mounted) return null;
      final icons = ref.read(categoriesSessionProvider).availableIcons;
      final defaultIcon = icons.firstWhere(
        (icon) => icon.iconName == AppConstants.defaultCategoryIcon.iconName,
        orElse: () => AppConstants.defaultCategoryIcon,
      );
      final category = Category(
        id: null,
        accountId: account!.id!,
        name: '',
        color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
        icon: defaultIcon,
      );
      state = state.copyWith(
        localCategories: [category],
        availableIcons: icons,
        status: state.status.doneLoading(),
      );
      return category;
    } catch (e) {
      if (!ref.mounted) return null;
      state = state.copyWith(status: state.status.failure(e));
      return null;
    }
  }

  Future<void> removeCategory(Category category) async {
    if (category.id == null) {
      state = state.copyWith(
        localCategories: state.localCategories
            .where((item) => !identical(item, category))
            .toList(),
        clearEditingCategory: true,
      );
      return;
    }

    state = state.copyWith(status: state.status.loading());
    try {
      await ref.read(expensesServiceProvider).deleteByCategoryId(category.id!);
      if (!ref.mounted) return;
      // deleteByCategoryId only touches the backend: without this, expenses
      // that belonged to the deleted category linger in ExpensesSession
      // (and therefore in Overview/Undebited) until something else happens
      // to reload that account. Mirrors what account deletion already does.
      ref
          .read(expensesSessionProvider.notifier)
          .clearAccount(category.accountId);
      await ref
          .read(categoriesSessionProvider.notifier)
          .delete(category.id!, accountId: category.accountId);
      if (!ref.mounted) return;
      state = state.copyWith(
        clearEditingCategory: true,
        status: state.status.success(
          const AppUserMessage.success(AppMessageKey.categoryDeleted),
        ),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(status: state.status.failure(e));
    }
  }

  Future<void> createCategory({
    required Category draft,
    required String name,
    required Color color,
    required CategoryIcon icon,
    required String monthlyThreshold,
  }) async {
    final account = state.account;
    if (account?.id == null) return;

    state = state.copyWith(status: state.status.loading());
    try {
      final category = draft.copyWith(
        account: account,
        name: name.trim(),
        color: color,
        icon: icon,
        monthlyThreshold: parseAmount(monthlyThreshold),
        clearMonthlyThreshold: monthlyThreshold.trim().isEmpty,
      );
      await ref.read(categoriesSessionProvider.notifier).create(category);
      if (!ref.mounted) return;
      state = state.copyWith(
        localCategories: state.localCategories
            .where((item) => !identical(item, draft))
            .toList(),
        clearEditingCategory: true,
        status: state.status.success(
          const AppUserMessage.success(AppMessageKey.categorySaved),
        ),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(status: state.status.failure(e));
    }
  }

  Future<void> updateCategory({
    required Category category,
    required String name,
    required Color color,
    required CategoryIcon icon,
    required String monthlyThreshold,
  }) async {
    if (state.account?.id == null) return;

    state = state.copyWith(status: state.status.loading());
    try {
      final updated = category.copyWith(
        name: name.trim(),
        color: color,
        icon: icon,
        monthlyThreshold: parseAmount(monthlyThreshold),
        clearMonthlyThreshold: monthlyThreshold.trim().isEmpty,
      );
      await ref.read(categoriesSessionProvider.notifier).update(updated);
      if (!ref.mounted) return;
      state = state.copyWith(
        clearEditingCategory: true,
        status: state.status.success(
          const AppUserMessage.success(AppMessageKey.categorySaved),
        ),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(status: state.status.failure(e));
    }
  }

  void consumeMessage() {
    state = state.copyWith(status: state.status.consumeMessage());
  }
}
