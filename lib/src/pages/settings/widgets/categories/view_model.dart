import 'dart:math';
import 'package:budgly/src/core/loading/progressive_loader.dart';
import 'package:budgly/src/core/stores/categories.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart' as cim;
import 'package:budgly/src/models/category/editing_data.dart';
import 'package:budgly/src/services/categories.dart';
import 'package:flutter/material.dart';

class CategoriesViewModel extends BaseViewModel {
  static const cim.CategoryIcon _defaultIcon = cim.CategoryIcon(
    iconName: 'category',
    iconPack: 'material',
    iconCode: 0xf624,
    labels: {"en": "Category", "fr": "Catégorie"},
  );

  final CategoriesStore _categoriesStore = CategoriesStore.instance;
  final CategoriesService _categoriesService = CategoriesService.instance;

  Account? _account;
  final List<Category> _localCategories = [];
  Category? _editingCategory;
  final TextEditingController _nameController = TextEditingController();

  late final CategoryEditingData _editingData = CategoryEditingData(
    nameController: _nameController,
    color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
    icon: _defaultIcon,
    availableIcons: [],
  );

  CategoriesViewModel() {
    // Relaie les notifications du store (chargements en arrière-plan,
    // création/mise à jour/suppression) vers les listeners du ViewModel,
    // qui est ce que le widget écoute réellement.
    _categoriesStore.addListener(_onStoreChanged);
  }

  void _onStoreChanged() {
    if (!isDisposed) notifyListeners();
  }

  Account? get account => _account;
  set account(Account value) {
    if (_account == value) return;
    _account = value;
    notifyListeners();
    // Le changement de compte doit déclencher le chargement de ses
    // catégories si ce n'est pas déjà fait, sinon la liste reste vide.
    if (!hasCategoriesLoaded) {
      loadCategories();
    }
  }

  List<Category> get categories {
    if (_account?.id == null) return [];
    return [
      ..._categoriesStore.getCategoriesForAccount(_account!.id!),
      ..._localCategories,
    ];
  }

  bool get hasCategoriesLoaded =>
      _account?.id != null &&
      _categoriesStore.categoriesByAccount[_account!.id!] != null;

  bool get isCreatingCategory => _localCategories.isNotEmpty;

  Category? get editingCategory => _editingCategory;
  CategoryEditingData get editingData => _editingData;

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

  void cancelEdit() {
    _editingCategory = null;
    _nameController.clear();
    if (!isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _categoriesStore.removeListener(_onStoreChanged);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> loadCategories({bool needLoading = true}) async {
    if (_account?.id == null) return;
    if (needLoading) setLoading(true);

    await ProgressiveLoader.loadEssentialOnly(
      essentialData: () async {
        await _categoriesStore.loadCategoriesForAccount(_account!.id!);
        await _categoriesStore.loadAvailableIcons();
        _editingData.availableIcons = _categoriesStore.availableIcons;
      },
      secondaryData: () async {},
      onProgress: (progress) {},
    );

    setLoading(false);
    if (!isDisposed) notifyListeners();
  }

  Future<void> addCategory() async {
    if (_account?.id == null || _localCategories.isNotEmpty) return;

    setLoading(true);

    await _categoriesStore.loadAvailableIcons();
    _editingData.availableIcons = _categoriesStore.availableIcons;

    final defaultIcon = _editingData.availableIcons.isNotEmpty
        ? _editingData.availableIcons.first
        : _defaultIcon;

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

  Future<void> removeCategory(Category category) async {
    if (category.id != null) {
      await _categoriesService.deleteCategory(category.id!);
      _categoriesStore.removeCategory(category.id!);
      if (_account?.id != null) {
        await _categoriesStore.invalidateAccountCache(_account!.id!);
      }
    } else {
      _localCategories.removeWhere((c) => identical(c, category));
    }
    if (!isDisposed) notifyListeners();
  }

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

      final createdCategory = await _categoriesService.createCategory(
        newCategory,
      );

      _localCategories.removeWhere((c) => identical(c, category));
      _categoriesStore.addCategory(createdCategory);
      _editingCategory = null;
    } finally {
      setLoading(false);
      await _categoriesStore.loadCategoriesForAccount(
        _account!.id!,
        forceRefresh: true,
      );
    }
  }

  Future<void> updateCategory(Category category) async {
    if (_account?.id == null) return;
    setLoading(true);
    try {
      final updatedCategoryData = category.copyWith(
        name: _nameController.text,
        color: _editingData.color,
        icon: _editingData.icon,
      );

      final updatedCategory = await _categoriesService.updateCategory(
        updatedCategoryData,
      );

      _categoriesStore.updateCategory(updatedCategory);
      _editingCategory = null;
    } finally {
      setLoading(false);
      await _categoriesStore.invalidateAccountCache(_account!.id!);
    }
  }
}