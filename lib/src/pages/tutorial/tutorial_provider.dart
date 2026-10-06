import 'dart:async';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/state/account_budgets_provider.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/pages/tutorial/onboarding_resume.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/image/account_image_helper.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'tutorial_provider.g.dart';

class TutorialState {
  const TutorialState({
    this.currentStep = 0,
    this.isInitializing = true,
    this.createdAccount,
    this.createdCategories = const [],
    this.accountColor = Colors.blue,
    this.accountPicture,
    this.categoryColor = Colors.blue,
    this.categoryIcon,
    this.isAddingCategory = false,
    this.hasRevenue = false,
    this.availableIcons = const [],
  });

  final int currentStep;
  final bool isInitializing;
  final Account? createdAccount;
  final List<Category> createdCategories;
  final Color accountColor;
  final String? accountPicture;
  final Color categoryColor;
  final CategoryIcon? categoryIcon;
  final bool isAddingCategory;
  final bool hasRevenue;
  final List<CategoryIcon> availableIcons;

  int get totalSteps => 4;
  bool get canGoBack => currentStep > 0;

  TutorialState copyWith({
    int? currentStep,
    bool? isInitializing,
    Object? createdAccount = _unset,
    List<Category>? createdCategories,
    Color? accountColor,
    Object? accountPicture = _unset,
    Color? categoryColor,
    Object? categoryIcon = _unset,
    bool? isAddingCategory,
    bool? hasRevenue,
    List<CategoryIcon>? availableIcons,
  }) => TutorialState(
    currentStep: currentStep ?? this.currentStep,
    isInitializing: isInitializing ?? this.isInitializing,
    createdAccount: identical(createdAccount, _unset)
        ? this.createdAccount
        : createdAccount as Account?,
    createdCategories: createdCategories ?? this.createdCategories,
    accountColor: accountColor ?? this.accountColor,
    accountPicture: identical(accountPicture, _unset)
        ? this.accountPicture
        : accountPicture as String?,
    categoryColor: categoryColor ?? this.categoryColor,
    categoryIcon: identical(categoryIcon, _unset)
        ? this.categoryIcon
        : categoryIcon as CategoryIcon?,
    isAddingCategory: isAddingCategory ?? this.isAddingCategory,
    hasRevenue: hasRevenue ?? this.hasRevenue,
    availableIcons: availableIcons ?? this.availableIcons,
  );
}

const _unset = Object();

@riverpod
class Tutorial extends _$Tutorial {
  SharedPreferences? _prefs;

  String get _stepStorageKey => AppConstants.tutorialStepKey(
    ref.read(authServiceProvider).currentUser?.id ?? 'anonymous',
  );

  @override
  TutorialState build() {
    ref.onDispose(() => _prefs = null);
    unawaited(_loadInitialData());
    ref.read(analyticsServiceProvider).track('onboarding_started');
    ref.read(analyticsServiceProvider).track('onboarding_step_started', {
      'step': 0,
    });
    return const TutorialState();
  }

  Future<void> _loadInitialData() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final accountsFuture = ref.read(accountsSessionProvider.notifier).load();
      final iconsFuture = ref
          .read(categoriesSessionProvider.notifier)
          .loadIcons();
      var hasExistingAccount = false;

      try {
        await accountsFuture;
        if (!ref.mounted) return;
        if (ref.read(accountsSessionProvider).accounts.isNotEmpty) {
          hasExistingAccount = true;
          await _adoptExistingAccount(
            ref.read(accountsSessionProvider).accounts.first,
          );
        }
      } catch (e, stackTrace) {
        AppLogger.error(
          'Failed to adopt existing account in tutorial',
          e,
          stackTrace,
        );
      }

      await iconsFuture;
      if (!ref.mounted) return;
      final icons = ref.read(categoriesSessionProvider).availableIcons;
      final defaultIcon = icons.firstWhere(
        (icon) => icon.iconName == AppConstants.defaultCategoryIcon.iconName,
        orElse: () => AppConstants.defaultCategoryIcon,
      );
      final savedStep = _prefs?.getInt(_stepStorageKey);
      state = state.copyWith(
        categoryIcon: defaultIcon,
        availableIcons: icons,
        currentStep: resolveOnboardingStartStep(
          savedStep: savedStep,
          hasAccount: hasExistingAccount,
          totalSteps: state.totalSteps,
        ),
        isInitializing: false,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize tutorial', e, stackTrace);
      if (ref.mounted) state = state.copyWith(isInitializing: false);
    }
  }

  Future<void> _adoptExistingAccount(Account account) async {
    final accountId = account.id;
    state = state.copyWith(
      createdAccount: account,
      accountColor: account.color ?? Colors.primaries.first,
      accountPicture: account.pictureUrl ?? account.picture,
    );
    if (accountId == null) return;

    final now = DateTime.now();
    try {
      final results = await Future.wait([
        ref.read(categoriesSessionProvider.notifier).load(accountId),
        ref
            .read(accountBudgetsSessionProvider.notifier)
            .loadRevenue(accountId, now.year, now.month),
      ]);
      if (!ref.mounted) return;
      final categories = results.first as List<Category>;
      final revenue = ref
          .read(accountBudgetsSessionProvider.notifier)
          .getRevenue(accountId, now.year, now.month);
      state = state.copyWith(
        createdCategories: categories,
        hasRevenue: revenue > 0,
      );
      _cycleCategoryDefaults();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to prefill tutorial from existing account',
        e,
        stackTrace,
      );
    }
  }

  void nextStep() {
    if (state.currentStep >= state.totalSteps - 1) return;
    final previousStep = state.currentStep;
    state = state.copyWith(currentStep: previousStep + 1);
    ref.read(analyticsServiceProvider).track('onboarding_step_completed', {
      'step': previousStep,
    });
    ref.read(analyticsServiceProvider).track('onboarding_step_started', {
      'step': state.currentStep,
    });
    unawaited(_persistStep());
  }

  void previousStep() {
    if (!state.canGoBack) return;
    state = state.copyWith(currentStep: state.currentStep - 1);
    ref.read(analyticsServiceProvider).track('onboarding_step_started', {
      'step': state.currentStep,
    });
    unawaited(_persistStep());
  }

  Future<void> _persistStep() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_stepStorageKey, state.currentStep);
  }

  /// Marks the onboarding as completed (RL-01 §2.2 and §3.4).
  ///
  /// `ProfileSession.completeOnboarding` follows the same optimistic-mutation
  /// contract as every other offline mutation: it writes `onboardingCompleted`
  /// to the local profile cache and enqueues the remote update *before*
  /// returning. That local write is what this method relies on — a remote
  /// failure at this point is not a completion failure, it is an ordinary
  /// pending `SyncQueue` entry that keeps retrying silently in the
  /// background (surfaced only via the global sync-issue banner, never by
  /// blocking onboarding). The persisted onboarding step is cleared as soon
  /// as that local write has happened; only a genuine local failure (e.g. the
  /// profile was never loaded) keeps the step around so the tutorial resumes.
  Future<void> completeTutorial() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final uid = ref.read(authServiceProvider).currentUser?.id ?? 'anonymous';
      await ref.read(profileSessionProvider.notifier).completeOnboarding();
      await _prefs!.remove(AppConstants.tutorialStepKey(uid));
      await _prefs!.setBool(AppConstants.tutorialCompletedKey(uid), true);
      ref.read(analyticsServiceProvider).track('onboarding_completed');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to finalize onboarding completion',
        e,
        stackTrace,
      );
    }
  }

  void setAccountCustomization({Color? color, String? picture}) {
    state = state.copyWith(
      accountColor: color ?? state.accountColor,
      accountPicture: picture,
    );
  }

  Future<void> saveAccount({
    required String name,
    required bool isUpdate,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final accountsService = ref.read(accountsServiceProvider);
    try {
      final current = state.createdAccount;
      if (isUpdate && current?.id != null) {
        final updated = await _updateAccount(
          accountsService,
          current!,
          name: trimmedName,
          color: state.accountColor,
          picture: state.accountPicture,
        );
        state = state.copyWith(createdAccount: updated);
      } else {
        final image = await AccountImageHelper.prepareImage(
          state.accountPicture,
          isLocal:
              state.accountPicture != null &&
              !state.accountPicture!.startsWith('http'),
        );
        var created = await ref
            .read(accountsSessionProvider.notifier)
            .create(
              Account(
                name: trimmedName,
                color: state.accountColor,
                picture: image?.fileName,
              ),
            );
        if (image != null) {
          created = await AccountImageHelper.uploadAndLinkImage(
            accountsService,
            created,
            image,
          );
          ref.read(accountsSessionProvider.notifier).updateLocal(created);
        }
        state = state.copyWith(
          createdAccount: created,
          accountPicture: created.pictureUrl ?? state.accountPicture,
        );
        ref.read(analyticsServiceProvider).track('tutorial_account_created');
        await _persistStep();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save account in tutorial', e, stackTrace);
      rethrow;
    }
  }

  Future<Account> _updateAccount(
    dynamic accountsService,
    Account account, {
    required String name,
    required Color color,
    required String? picture,
  }) async {
    var currentFileName = account.picture;
    ImageProcessResult? imageToUpload;
    final pictureChanged = picture != account.pictureUrl;
    if (pictureChanged) {
      if (account.picture != null) {
        await accountsService.deletePicture(account.picture!, account.id!);
        currentFileName = null;
      }
      imageToUpload = await AccountImageHelper.prepareImage(
        picture,
        isLocal: picture != null && !picture.startsWith('http'),
      );
      if (imageToUpload != null) currentFileName = imageToUpload.fileName;
    }
    var updated = await ref
        .read(accountsSessionProvider.notifier)
        .update(
          account.copyWith(name: name, color: color, picture: currentFileName),
        );
    if (imageToUpload != null) {
      updated = await AccountImageHelper.uploadAndLinkImage(
        accountsService,
        updated,
        imageToUpload,
      );
      ref.read(accountsSessionProvider.notifier).updateLocal(updated);
    } else if (picture != null && !picture.startsWith('http')) {
      ref.read(accountsSessionProvider.notifier).updateLocal(updated);
    }
    return updated;
  }

  void setCategoryCustomization({Color? color, CategoryIcon? icon}) {
    state = state.copyWith(
      categoryColor: color ?? state.categoryColor,
      categoryIcon: icon ?? state.categoryIcon,
    );
  }

  Future<bool> addCategory(String name) async {
    if (name.trim().isEmpty || state.createdAccount?.id == null) return false;
    state = state.copyWith(isAddingCategory: true);
    try {
      final category = await ref
          .read(categoriesSessionProvider.notifier)
          .create(
            Category(
              name: name.trim(),
              color: state.categoryColor,
              icon: state.categoryIcon,
              accountId: state.createdAccount!.id!,
            ),
          );
      if (!ref.mounted) return false;
      state = state.copyWith(
        createdCategories: [...state.createdCategories, category],
      );
      ref.read(analyticsServiceProvider).track('tutorial_category_created');
      _cycleCategoryDefaults();
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create category in tutorial', e, stackTrace);
      return false;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isAddingCategory: false);
      }
    }
  }

  Future<void> removeCategory(Category category) async {
    if (category.id == null) return;
    final index = state.createdCategories.indexWhere(
      (c) => c.id == category.id,
    );
    if (index == -1) return;
    final next = [...state.createdCategories]..removeAt(index);
    state = state.copyWith(createdCategories: next);
    try {
      await ref.read(categoriesSessionProvider.notifier).delete(category.id!);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete category in tutorial', e, stackTrace);
      final restored = [...state.createdCategories]..insert(index, category);
      state = state.copyWith(createdCategories: restored);
    }
  }

  void _cycleCategoryDefaults() {
    final colorIndex = state.createdCategories.length % Colors.primaries.length;
    state = state.copyWith(
      categoryColor: Colors.primaries[colorIndex],
      categoryIcon: AppConstants.defaultCategoryIcon,
    );
  }

  Future<void> saveRevenue(String valueText) async {
    if (state.createdAccount?.id == null) return;
    final value = parseAmount(valueText);
    if (value == null || value <= 0) return;
    final now = DateTime.now();
    await ref
        .read(accountBudgetsSessionProvider.notifier)
        .setRevenue(state.createdAccount!.id!, now.year, now.month, value);
    state = state.copyWith(hasRevenue: true);
    ref.read(analyticsServiceProvider).track('tutorial_budget_created');
  }

  Future<void> signOut() => ref.read(profileSessionProvider.notifier).signOut();
}
