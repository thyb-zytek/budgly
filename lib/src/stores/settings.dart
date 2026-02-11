import 'package:app/src/pages/settings/widgets/accounts/view_model.dart';
import 'package:app/src/pages/settings/widgets/categories/view_model.dart';
import 'package:flutter/material.dart';

class SettingsStore extends InheritedWidget {
  final AccountsViewModel accountsViewModel;
  final CategoriesViewModel categoriesViewModel;

  SettingsStore({
    super.key,
    required this.accountsViewModel,
    required this.categoriesViewModel,
    required super.child,
  }); 

  static SettingsStore? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsStore>();
  }

  @override
  bool updateShouldNotify(SettingsStore oldWidget) {
    return false;
  }
}
