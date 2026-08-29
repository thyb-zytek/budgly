import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/pages/settings/accounts/view_model.dart';
import 'package:budgly/src/pages/settings/categories/view_model.dart';
import 'package:budgly/src/pages/settings/widgets/add_entity.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_form.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/pages/settings/widgets/entity_title.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_view.dart';
import 'package:budgly/src/shared/ui/widgets/layout/empty_state.dart';
import 'package:budgly/src/shared/ui/widgets/layout/framed_container.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/view_model_feedback.dart';
import 'package:flutter/material.dart';

class CategoriesTab extends StatefulWidget {
  final AccountsViewModel accountsViewModel;

  const CategoriesTab({super.key, required this.accountsViewModel});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab>
    with AutomaticKeepAliveClientMixin<CategoriesTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  late AccountsViewModel _accountsViewModel;
  late CategoriesViewModel _categoriesViewModel;

  @override
  void initState() {
    super.initState();
    _accountsViewModel = widget.accountsViewModel;
    _categoriesViewModel = CategoriesViewModel();
    _accountsViewModel.addListener(_syncSelectedAccount);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_accountsViewModel.hasAccountsLoaded) {
      await _accountsViewModel.loadAccounts();
    }
    if (_accountsViewModel.accounts.isNotEmpty &&
        _categoriesViewModel.account == null) {
      _categoriesViewModel.account = _accountsViewModel.accounts.first;
    }
    _syncSelectedAccount();
  }

  void _syncSelectedAccount() {
    final accounts = _accountsViewModel.accounts;
    if (accounts.isEmpty) return;

    final currentId = _categoriesViewModel.account?.id;
    final stillExists =
        currentId != null && accounts.any((a) => a.id == currentId);

    if (!stillExists) {
      _categoriesViewModel.account = accounts.first;
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
  void dispose() {
    _scrollController.dispose();
    _accountsViewModel.removeListener(_syncSelectedAccount);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ViewModelFeedback(
      viewModel: _categoriesViewModel,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BudglySpacing.lg, vertical: BudglySpacing.sm),
          child: EntityTitle(
            title: tr.categories,
            subtitle: tr.selectAccountToManageCategories,
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              _categoriesViewModel,
              _accountsViewModel,
            ]),
            builder: (context, child) {
              if (_categoriesViewModel.isLoading) {
                return const AppLoadingIndicator();
              }

              final accounts = _accountsViewModel.accounts;
              if (accounts.isEmpty) {
                return EmptyState(
                  icon: Icons.info_outline,
                  title: tr.noAccountForCategories,
                );
              }

              final categories = _categoriesViewModel.categories;
              final currentAccount = _categoriesViewModel.account;
              final selectedAccount = currentAccount != null
                  ? accounts.firstWhere(
                      (a) => a.id == currentAccount.id,
                      orElse: () => accounts.first,
                    )
                  : accounts.first;
              final editingCategoryId =
                  _categoriesViewModel.editingCategory?.id;

              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: BudglySpacing.lg,
                      vertical: BudglySpacing.sm,
                    ),
                    child: Column(
                      spacing: 8,
                      children: [
                        FramedContainer(
                          child: AccountSelector(
                            accounts: accounts,
                            selectedAccount: selectedAccount,
                            backgroundColor: theme.colorScheme.surface,
                            onSelect: (account) =>
                                _categoriesViewModel.account = account,
                          ),
                        ),
                        Divider(
                          thickness: 2,
                          color: theme.colorScheme.outline,
                          indent: 40,
                          endIndent: 40,
                        ),
                        Expanded(
                          child: categories.isEmpty
                              ? EmptyState(
                                  icon: Icons.category_rounded,
                                  title: tr.noCategoryFound,
                                  subtitle: tr.addCategoriesToAccount(
                                    selectedAccount.name,
                                  ),
                                )
                               : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.only(bottom: 100),
                                  itemCount: categories.length,
                                  itemBuilder: (context, index) {
                                    final category = categories[index];
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: Card(
                                        key: ValueKey(
                                          category.id ??
                                              identityHashCode(category),
                                        ),
                                        child: Padding(
                                          padding:
                                              BudglyComponentStyles.cardPadding,
                                          child:
                                              category.id != null &&
                                                  category.id !=
                                                      editingCategoryId
                                              ? CategoryView(
                                                  category: category,
                                                  onEdit: () =>
                                                      _categoriesViewModel
                                                              .editingCategory =
                                                          category,
                                                  onDelete: () =>
                                                      _confirmDelete(
                                                        category,
                                                        selectedAccount.name,
                                                      ),
                                                )
                                              : CategoryForm(
                                                  formKey: _formKey,
                                                  viewModel:
                                                      _categoriesViewModel,
                                                  category: category,
                                                  withPulse: true,
                                                  withHint: true,
                                                ),
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
                    label: tr.fabNewCategory,
                    disabled: _categoriesViewModel.isCreatingCategory,
                    onPressed: () {
                      _categoriesViewModel.addCategory();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
