import 'dart:math';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/loading/progressive_loader.dart';
import 'package:budgly/src/core/stores/categories_store.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/services/categories.dart';
import 'package:budgly/src/shared/widgets/categories/constants.dart';
import 'package:flutter/material.dart';

class CategoriesViewModel extends BaseViewModel {
  final CategoriesStore _categoriesStore = CategoriesStore.instance;
  final CategoriesService _categoriesService = CategoriesService.instance;

  final List<Category> _localCategories = []; // For temporary categories during editing
  Account? _selectedAccount;
  Category? _editingCategory;
  bool _hasCategoriesLoaded = false;

  final TextEditingController _nameController = TextEditingController();

  late Color _selectedColor;
  late CategoryIcon _selectedIcon;

  // Getters
  bool get hasCategoriesLoaded => _hasCategoriesLoaded;
  List<Category> get categories => _selectedAccount != null
      ? [..._categoriesStore.getCategoriesForAccount(_selectedAccount!.id!), ..._localCategories]
      : _localCategories;
  List<CategoryIcon> get availableIcons => _categoriesStore.availableIcons;
  Account? get selectedAccount => _selectedAccount;
  Category? get editingCategory => _editingCategory;
  bool get isCreatingCategory => _localCategories.isNotEmpty;

  CategoryEditingData get editingData => CategoryEditingData(
    nameController: _nameController,
    color: _selectedColor,
    icon: _selectedIcon,
  );

  // Setters
  set editingCategory(Category? category) {
    _editingCategory = category;
    _nameController.text = category?.name ?? '';
    _selectedColor =
        category?.color ??
        Colors.primaries[Random().nextInt(Colors.primaries.length)];
    _selectedIcon =
        category?.icon ??
        availableIcons.firstWhere((i) => i.iconCode == AppConstants.defaultIconCode);

    notifyListeners();
  }

  set color(Color color) {
    _selectedColor = color;
    notifyListeners();
  }

  void setIcon(CategoryIcon icon) {
    _selectedIcon = icon;
    notifyListeners();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Account operations
  Future<void> selectAccount(Account account) async {
    if (_selectedAccount?.id != account.id) {
      _selectedAccount = account;
      _localCategories.clear();
      await loadCategories(account);
      _hasCategoriesLoaded = true;
      notifyListeners();
    }
  }

  // Icon operations
  Future<void> loadAvailableIcons() async {
    await ProgressiveLoader.loadEssentialOnly(
      essentialData: () async {
        await _categoriesStore.loadAvailableIcons();
      },
      secondaryData: () async {
        // No secondary data for icons
      },
      onProgress: (progress) {
        // Optional progress tracking
      },
    );
    notifyListeners();
  }

  // Category operations
  Future<void> loadCategories(Account account) async {
    if (account.id == null) return;

    setLoading(true);
    
    await ProgressiveLoader.loadEssentialOnly(
      essentialData: () async {
        await _categoriesStore.loadCategoriesForAccount(account.id!);
      },
      secondaryData: () async {
        // Ensure icons are loaded
        await _categoriesStore.loadAvailableIcons();
      },
      onProgress: (progress) {
        // Optional progress tracking
      },
    );
    
    setLoading(false);
  }

  void addCategory() {
    if (_selectedAccount?.id == null) return;
    // Only one category can be created at a time.
    if (_localCategories.isNotEmpty) return;

    final newCategory = Category(
      accountId: _selectedAccount!.id!,
      name: '',
      color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
      icon: availableIcons.firstWhere(
        (i) => i.iconCode == AppConstants.defaultIconCode,
      ), // Default icon -> category_rounded
    );

    _nameController.text = '';
    _selectedColor = newCategory.color!;
    _selectedIcon = availableIcons.firstWhere((i) => i.iconCode == AppConstants.defaultIconCode);

    _localCategories.add(newCategory);
    notifyListeners();
  }

  Future<void> createCategory(Category category) async {
    if (_selectedAccount?.id == null || category.id != null) return;

    setLoading(true);

    try {
      final newCategory = category.copyWith(
        name: _nameController.text,
        color: _selectedColor,
        icon: _selectedIcon,
        account: _selectedAccount!,
      );
      final createdCategory = await _categoriesService.createCategory(
        newCategory,
      );
      final updatedCategory = createdCategory.copyWith(
        icon: availableIcons.firstWhere(
          (i) => i.iconCode == int.parse(createdCategory.iconCode!),
        ),
      );
      _localCategories.removeWhere((c) => identical(c, category));
      _categoriesStore.addCategory(updatedCategory);
      _editingCategory = null;
    } finally {
      setLoading(false);
    }
  }

  Future<void> updateCategory(Category category) async {
    setLoading(true);

    try {
      final updatedCategory = await _categoriesService.updateCategory(category);
      final categoryWithIcon = updatedCategory.copyWith(
        icon: availableIcons.firstWhere(
          (i) => i.iconCode == int.parse(updatedCategory.iconCode!),
        ),
      );
      _categoriesStore.updateCategory(categoryWithIcon);
      _editingCategory = null;
    } finally {
      setLoading(false);
    }
  }

  Future<void> removeCategory(Category category) async {
    setLoading(true);

    try {
      if (category.id != null) {
        // This is an existing category - actually delete it
        await _categoriesService.deleteCategory(category.id!);
        _categoriesStore.removeCategory(category.id!);
      } else {
        // This is a local temporary category - just remove from local
        // list. Use identity comparison: Category's == likely compares
        // by id, and every not-yet-saved category shares id == null, so
        // a value-based match would wipe out every local category
        // instead of just this one.
        _localCategories.removeWhere((c) => identical(c, category));
      }
      _editingCategory = null;
    } finally {
      setLoading(false);
    }
  }

  void cancelEdit() {
    // Cancel editing without deleting the category, and without
    // touching any other category currently being created locally.
    _editingCategory = null;
    _nameController.clear();
    notifyListeners();
  }
}