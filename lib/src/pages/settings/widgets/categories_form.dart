import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/models/category/category.dart';
import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:flutter/material.dart';

class CategoriesForm extends StatelessWidget {
  final List<Category> categories;
  final Function(Category account) onAdd;
  final Function(String id, Category Function(Category) account, String Function(Category) idSelector) onEdit;
  final Function(String id, String Function(Category) idSelector) onDelete;

  const CategoriesForm({
    super.key,
    required this.categories,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    AppLocalizations tr = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 16,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 16, bottom: 24),
            child: Text(tr.categories, style: theme.textTheme.headlineLarge),
          ),

          BudglyButton(
            leadingIcon: Icons.add_rounded,
            text: tr.newCategory,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
