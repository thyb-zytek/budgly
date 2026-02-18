import 'dart:async';
import 'dart:math';

import 'package:app/src/models/account/account.dart';
import 'package:app/src/models/category/category.dart';
import 'package:app/src/models/category/category_icon.dart';
import 'package:app/src/services/categories.dart';
import 'package:app/src/services/category_icons.dart';
import 'package:app/src/shared/widgets/categories/constants.dart';
import 'package:flutter/material.dart';

class CategoriesViewModel extends ChangeNotifier {
  final CategoriesService _categoriesService = CategoriesService.instance;
  final CategoryIconsService _categoryIconsService =
      CategoryIconsService.instance;

  final List<Category> _categories = [];
  final List<CategoryIcon> _availableIcons = [];
  Account? _selectedAccount;
  Category? _editingCategory;

  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  bool _hasCategoriesLoaded = false;

  late Color _selectedColor;
  late CategoryIcon _selectedIcon;

  // Getters
  bool get isLoading => _isLoading;
  bool get hasCategoriesLoaded => _hasCategoriesLoaded;
  List<Category> get categories => List.unmodifiable(_categories);
  List<CategoryIcon> get availableIcons => List.unmodifiable(_availableIcons);
  Account? get selectedAccount => _selectedAccount;
  Category? get editingCategory => _editingCategory;

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
        _availableIcons.firstWhere((i) => i.iconCode == 0xf624);

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
    _editingCategory = null;
    super.dispose();
  }

  // Account operations
  Future<void> selectAccount(Account account) async {
    if (_selectedAccount?.id != account.id) {
      _selectedAccount = account;
      _hasCategoriesLoaded = false;
      _categories.clear();
      await loadCategories(account);
    }
  }

  // Icon operations
  Future<void> loadAvailableIcons() async {
    _availableIcons.clear();
    _availableIcons.addAll(await _categoryIconsService.getIcons());
    notifyListeners();
  }

  // Category operations
  Future<void> loadCategories(Account account) async {
    if (account.id == null) return;

    _isLoading = true;
    notifyListeners();

    final loadedCategories = await _categoriesService.listCategoriesByAccount(
      account.id!,
    );

    if (loadedCategories.isNotEmpty) {
      _categories.clear();
      _categories.addAll(
        loadedCategories
            .map(
              (c) => c.copyWith(
                icon: _availableIcons.firstWhere(
                  (i) => i.iconCode == int.parse(c.iconCode!),
                ),
              ),
            )
            .toList(),
      );
    }

    _hasCategoriesLoaded = true;
    _isLoading = false;
    notifyListeners();
  }

  void addCategory() {
    if (_selectedAccount?.id == null) return;
    final newCategory = Category(
      accountId: _selectedAccount!.id!,
      name: '',
      color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
      icon: _availableIcons.firstWhere(
        (i) => i.iconCode == 0xf624,
      ), // Default icon -> category_rounded
    );

    _nameController.text = '';
    _selectedColor = newCategory.color!;
    _selectedIcon = _availableIcons.firstWhere((i) => i.iconCode == 0xf624);

    _categories.add(newCategory);
    notifyListeners();
  }

  Future<void> createCategory(Category category) async {
    if (_selectedAccount?.id == null || category.id != null) return;

    _isLoading = true;
    notifyListeners();

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
        icon: _availableIcons.firstWhere(
          (i) => i.iconCode == int.parse(createdCategory.iconCode!),
        ),
      );
      final index = _categories.indexWhere((c) => c.id == null);
      if (index != -1) {
        _categories[index] = updatedCategory;
      } else {
        _categories.insert(0, updatedCategory);
      }
      _editingCategory = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCategory(Category category) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updatedCategory = await _categoriesService.updateCategory(category);
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories[index] = updatedCategory;
      }
      _editingCategory = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeCategory(Category category) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _categoriesService.deleteCategory(category.id!);
      _categories.removeWhere((c) => c.id == category.id);
      _editingCategory = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
