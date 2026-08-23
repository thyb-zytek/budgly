import 'dart:math';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/loading/progressive_loader.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_editing_data.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/shared/domain/view_models/category_form_view_model.dart';
import 'package:flutter/material.dart';

class CategoriesViewModel extends BaseViewModel implements CategoryFormViewModel {
  final CategoriesService _categoriesService = CategoriesService.instance;

  Account? _account;
  final List<Category> _localCategories = [];
  Category? _editingCategory;
  final TextEditingController _nameController = TextEditingController();

  late final CategoryEditingData _editingData = CategoryEditingData(
    nameController: _nameController,
    color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
    icon: AppConstants.defaultCategoryIcon,
    availableIcons: [],
  );

  CategoriesViewModel() {
    _categoriesService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (!isDisposed) notifyListeners();
  }

  Account? get account => _account;
  set account(Account? value) {
    if (_account == value) return;
    _account = value;
    notifyListeners();
    if (value?.id != null) {
      // Icon metadata has its own cache/lifecycle and must not depend on
      // whether the category list is already cached. During onboarding the
      // category may already have been loaded, which previously prevented
      // loadCategories() from running here and left availableIcons empty.
      _ensureCategoryIcons();
      if (!hasCategoriesLoaded) {
        loadCategories();
      }
    }
  }

  List<Category> get categories {
    if (_account?.id == null) return [];
    return [
      ..._categoriesService.getCategoriesForAccount(_account!.id!),
      ..._localCategories,
    ];
  }

  bool get hasCategoriesLoaded =>
      _account?.id != null && _categoriesService.hasLoadedAccount(_account!.id!);

  bool get isCreatingCategory => _localCategories.isNotEmpty;

  Category? get editingCategory => _editingCategory;
  @override
  CategoryEditingData get categoryEditingData => _editingData;

  set editingCategory(Category? category) {
    _editingCategory = category;
    _nameController.text = category?.name ?? '';
    _editingData.color =
        category?.color ??
        Colors.primaries[Random().nextInt(Colors.primaries.length)];

    if (category?.icon != null) {
      _editingData.icon = category!.icon!;
    }

    if (!isDisposed) notifyListeners();
  }

  @override
  void cancelEdit() {
    _editingCategory = null;
    _nameController.clear();
    if (!isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _categoriesService.removeListener(_onServiceChanged);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _ensureCategoryIcons() async {
    try {
      await _categoriesService.loadAvailableIcons();
      _editingData.availableIcons = _categoriesService.availableIcons;
    } catch (e, st) {
      AppLogger.error('Failed to load category icons', e, st);
    } finally {
      if (!isDisposed) notifyListeners();
    }
  }

  Future<void> loadCategories({bool needLoading = true}) async {
    if (_account?.id == null) return;
    if (needLoading) setLoading(true);
    try {
      await ProgressiveLoader.loadEssentialOnly(
        essentialData: () async {
          // Loaded first and independently of the category list below: if
          // that later call throws (e.g. a network error), the icon picker
          // still ends up with data instead of staying empty for the rest
          // of the session. Failures here are logged rather than left to
          // propagate silently.
          try {
            await _categoriesService.loadAvailableIcons();
          } catch (e, st) {
            AppLogger.error('Failed to load category icons', e, st);
          }
          _editingData.availableIcons = _categoriesService.availableIcons;

          await _categoriesService.listCategoriesByAccount(_account!.id!);
        },
        secondaryData: () async {},
        onProgress: (progress) {},
      );
    } catch (e, st) {
      AppLogger.error('Failed to load categories', e, st);
    } finally {
      if (needLoading) setLoading(false);
      if (!isDisposed) notifyListeners();
    }
  }

  Future<void> addCategory() async {
    if (_account?.id == null || _localCategories.isNotEmpty) return;

    setLoading(true);

    await _categoriesService.loadAvailableIcons();
    _editingData.availableIcons = _categoriesService.availableIcons;

    final defaultIcon = _editingData.availableIcons.firstWhere(
      (i) => i.iconName == AppConstants.defaultCategoryIcon.iconName,
      orElse: () => AppConstants.defaultCategoryIcon,
    );

    final category = Category(
      id: null,
      accountId: _account!.id!,
      name: '',
      color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
      icon: defaultIcon,
    );

    _editingData.color = category.color!;
    _nameController.text = '';
    _editingData.icon = category.icon!;

    _localCategories.add(category);

    setLoading(false);
    if (!isDisposed) notifyListeners();
  }

  @override
  Future<void> removeCategory(Category category) async {
    if (category.id != null) {
      await ExpensesService.instance.deleteByCategoryId(category.id!);
      await _categoriesService.deleteCategory(category.id!);
    } else {
      _localCategories.removeWhere((c) => identical(c, category));
    }
    if (!isDisposed) notifyListeners();
  }

  @override
  Future<void> createCategory(Category category) async {
    if (_account?.id == null) return;
    setLoading(true);
    try {
      final newCategory = category.copyWith(
        account: _account,
        name: _nameController.text,
        color: _editingData.color,
        icon: _editingData.icon,
      );

      await _categoriesService.createCategory(newCategory);

      _localCategories.removeWhere((c) => identical(c, category));
      _editingCategory = null;
    } finally {
      setLoading(false);
    }
  }

  @override
  Future<void> updateCategory(Category category) async {
    if (_account?.id == null) return;
    setLoading(true);
    try {
      final updatedCategoryData = category.copyWith(
        name: _nameController.text,
        color: _editingData.color,
        icon: _editingData.icon,
      );

      await _categoriesService.updateCategory(updatedCategoryData);
      _editingCategory = null;
    } finally {
      setLoading(false);
    }
  }
}