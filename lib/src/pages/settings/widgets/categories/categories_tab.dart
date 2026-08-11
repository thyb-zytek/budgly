import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/pages/settings/widgets/accounts/view_model.dart';
import 'package:budgly/src/pages/settings/widgets/add_entity.dart';
import 'package:budgly/src/pages/settings/widgets/categories/category_form.dart';
import 'package:budgly/src/pages/settings/widgets/categories/empty_categories.dart';
import 'package:budgly/src/pages/settings/widgets/categories/view_model.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/pages/settings/widgets/entity_title.dart';
import 'package:budgly/src/shared/widgets/accounts/selector.dart';
import 'package:budgly/src/shared/widgets/categories/default.dart';
import 'package:budgly/src/shared/widgets/common/card.dart';
import 'package:flutter/material.dart';

class CategoriesTab extends StatefulWidget {
  final AccountsViewModel accountsViewModel;

  const CategoriesTab({
    super.key,
    required this.accountsViewModel,
  });

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab>
    with AutomaticKeepAliveClientMixin<CategoriesTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late AccountsViewModel _accountsViewModel;
  late CategoriesViewModel _categoriesViewModel;

  @override
  void initState() {
    super.initState();
    _accountsViewModel = widget.accountsViewModel;
    _categoriesViewModel = CategoriesViewModel();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_accountsViewModel.hasAccountsLoaded) {
      await _accountsViewModel.loadAccounts();
    }
    // Le chargement des catégories est maintenant déclenché par le setter
    // `account` du ViewModel ; on n'a plus qu'à sélectionner le compte.
    if (_accountsViewModel.accounts.isNotEmpty &&
        _categoriesViewModel.account == null) {
      _categoriesViewModel.account = _accountsViewModel.accounts.first;
    }
  }

  void _confirmDelete(Category category, String accountName) {
    final tr = AppLocalizations.of(context)!;

    showConfirmDelete(
      context,
      title: tr.confirmDeleteCategory(category.name!),
      content: tr.confirmDeleteCategoryMessage(category.name!, accountName),
      onConfirm: () async {
        await _categoriesViewModel.removeCategory(category);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([_categoriesViewModel, _accountsViewModel]),
      builder: (context, child) {
        if (_categoriesViewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final accounts = _accountsViewModel.accounts;
        if (accounts.isEmpty) {
          return Center(
            child: Row(
              spacing: 16,
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                Expanded(
                  child: Text(
                    tr.noAccountFound,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final categories = _categoriesViewModel.categories;
        final selectedAccount = accounts.firstWhere(
          (a) => a.id == _categoriesViewModel.account!.id!,
          orElse: () => accounts.first,
        );
        final editingCategoryId = _categoriesViewModel.editingCategory?.id;

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  EntityTitle(
                    title: tr.categories,
                    subtitle: tr.selectAccountToManageCategories,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: AccountSelector(
                      accounts: accounts,
                      selectedAccount: selectedAccount,
                      onSelect: (account) {
                        _categoriesViewModel.account = account;
                      },
                    ),
                  ),
                  Expanded(
                    child: categories.isEmpty
                        ? EmptyCategories(
                            accountName: selectedAccount.name,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.only(bottom: 12),
                                child: BudglyCard(
                                  key: ValueKey(
                                    category.id ?? identityHashCode(category),
                                  ),
                                  child: category.id != null && category.id != editingCategoryId
                                      ? CategoryView(
                                          category: category,
                                          onEdit: () => _categoriesViewModel.editingCategory = category,
                                          onDelete: () => _confirmDelete(
                                            category,
                                            selectedAccount.name,
                                          ),
                                        )
                                      : CategoryForm(
                                          formKey: _formKey,
                                          viewModel: _categoriesViewModel,
                                          category: category,
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            AddEntity(
              heroTag: 'add_category',
              disabled: _categoriesViewModel.isCreatingCategory,
              onPressed: () {
                _categoriesViewModel.addCategory();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}