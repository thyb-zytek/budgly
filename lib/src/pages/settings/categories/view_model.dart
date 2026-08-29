import 'dart:async';
import 'dart:math';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/errors/app_user_message.dart';
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
    if (value?.id != null && !hasCategoriesLoaded) {
      unawaited(loadCategories());
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

  Future<void> loadCategories() async {
    if (_account?.id == null) return;
    setLoading(true);
    try {
      // Icons and categories are independent reads. Both services are
      // local-first, so neither needs to wait for the other.
      await Future.wait([
        _categoriesService.loadAvailableIcons(),
        _categoriesService.listCategoriesByAccount(_account!.id!),
      ]);
      _editingData.availableIcons = _categoriesService.availableIcons;
    } catch (e, st) {
      if (classifyError(e) == AppMessageKey.networkError) {
        AppLogger.error('Failed to load categories while offline', e, st);
      } else {
        setError(e, stackTrace: st);
      }
    } finally {
      setLoading(false);
    }
  }

  Future<void> addCategory() async {
    if (_account?.id == null || _localCategories.isNotEmpty) return;

    setLoading(true);
    try {
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
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
    } finally {
      setLoading(false);
    }
  }

  @override
  Future<void> removeCategory(Category category) async {
    if (category.id == null) {
      _localCategories.removeWhere((c) => identical(c, category));
      if (!isDisposed) notifyListeners();
      return;
    }

    setLoading(true);
    try {
      await ExpensesService.instance.deleteByCategoryId(category.id!);
      await _categoriesService.deleteCategory(category.id!);
      setSuccessMessage(const AppUserMessage.success(AppMessageKey.categoryDeleted));
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
    } finally {
      setLoading(false);
    }
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
      setSuccessMessage(const AppUserMessage.success(AppMessageKey.categorySaved));
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
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
      setSuccessMessage(const AppUserMessage.success(AppMessageKey.categorySaved));
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
    } finally {
      setLoading(false);
    }
  }
}
