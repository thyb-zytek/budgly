import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/models/category/category.dart';
import 'package:app/src/pages/settings/widgets/accounts/view_model.dart';
import 'package:app/src/pages/settings/widgets/add_fab.dart';
import 'package:app/src/pages/settings/widgets/categories/view_model.dart';
import 'package:app/src/pages/settings/widgets/confirm_dialog.dart';
import 'package:app/src/shared/widgets/accounts/selector.dart';
import 'package:app/src/shared/widgets/categories/form_card.dart';
import 'package:app/src/shared/widgets/categories/view_card.dart';
import 'package:flutter/material.dart';

class CategoriesTab extends StatefulWidget {
  final AccountsViewModel accountsViewModel;
  final CategoriesViewModel categoriesViewModel;

  const CategoriesTab({
    super.key,
    required this.accountsViewModel,
    required this.categoriesViewModel,
  });

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab>
    with AutomaticKeepAliveClientMixin<CategoriesTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    widget.categoriesViewModel.loadAvailableIcons();

    if (!widget.accountsViewModel.hasAccountsLoaded) {
      widget.accountsViewModel.loadAccounts().then((_) {
        if (widget.accountsViewModel.accounts.isNotEmpty &&
            !widget.categoriesViewModel.hasCategoriesLoaded) {
          widget.categoriesViewModel.selectAccount(
            widget.accountsViewModel.accounts.first,
          );
        }
      });
    } else if (widget.accountsViewModel.accounts.isNotEmpty &&
        !widget.categoriesViewModel.hasCategoriesLoaded) {
      widget.categoriesViewModel.selectAccount(
        widget.accountsViewModel.accounts.first,
      );
    }
  }

  @override
  void didUpdateWidget(covariant CategoriesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.categoriesViewModel.loadAvailableIcons();

    if (!widget.accountsViewModel.hasAccountsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.accountsViewModel.loadAccounts(needLoading: false).then((_) {
          if (widget.accountsViewModel.accounts.isNotEmpty &&
              !widget.categoriesViewModel.hasCategoriesLoaded) {
            widget.categoriesViewModel.selectAccount(
              widget.accountsViewModel.accounts.first,
            );
          }
        });
      });
    }

    if (widget.accountsViewModel.accounts.isNotEmpty &&
        !widget.categoriesViewModel.hasCategoriesLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.categoriesViewModel.selectAccount(
          widget.accountsViewModel.accounts.first,
        );
      });
    }

    if (oldWidget.categoriesViewModel.selectedAccount !=
        widget.categoriesViewModel.selectedAccount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.categoriesViewModel.selectedAccount != null) {
          widget.categoriesViewModel.selectAccount(
            widget.categoriesViewModel.selectedAccount!,
          );
        }
      });
    }
  }

  void _confirmDelete(Category category) {
    showDialog(
      context: context,
      builder:
          (context) => ConfirmDialog(
            title: AppLocalizations.of(
              context,
            )!.confirmDeleteCategory(category.name!),
            content: AppLocalizations.of(context)!.confirmDeleteCategoryMessage(
              category.name!,
              widget.categoriesViewModel.selectedAccount!.name,
            ),
            onConfirm:
                () => widget.categoriesViewModel.removeCategory(category),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    AppLocalizations tr = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.categoriesViewModel,
      builder: (context, child) {
        if (widget.categoriesViewModel.isLoading &&
            widget.accountsViewModel.accounts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      tr.accountCategory,
                      style: theme.textTheme.headlineLarge,
                    ),
                  ),
                  widget.accountsViewModel.accounts.isNotEmpty
                      ? AccountSelector(
                        accounts: widget.accountsViewModel.accounts,
                        selectedAccount:
                            widget.categoriesViewModel.selectedAccount,
                        onSelect: widget.categoriesViewModel.selectAccount,
                      )
                      : Text(
                        tr.noAccountFound,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 80),
                    child: Divider(
                      color: theme.colorScheme.outlineVariant,
                      thickness: 2,
                    ),
                  ),
                  Expanded(
                    child:
                        widget.categoriesViewModel.categories.isNotEmpty
                            ? ListView.builder(
                              itemCount:
                                  widget.categoriesViewModel.categories.length,
                              itemBuilder: (context, index) {
                                final category =
                                    widget
                                        .categoriesViewModel
                                        .categories[index];
                                if (category.id != null &&
                                    category.id !=
                                        widget
                                            .categoriesViewModel
                                            .editingCategory
                                            ?.id) {
                                  return CategoryViewCard(
                                    category: category,
                                    onEdit:
                                        () =>
                                            widget
                                                .categoriesViewModel
                                                .editingCategory = category,
                                    onDelete: () => _confirmDelete(category),
                                  );
                                }

                                return CategoryFormCard(
                                  formKey: _formKey,
                                  availableIcons:
                                      widget.categoriesViewModel.availableIcons,
                                  onChangeColor:
                                      (color) =>
                                          widget.categoriesViewModel.color =
                                              color,
                                  onChangeIcon:
                                      (icon) => widget.categoriesViewModel
                                          .setIcon(icon),
                                  editingData:
                                      widget.categoriesViewModel.editingData,
                                  onSubmit:
                                      () =>
                                          category.id == null
                                              ? widget.categoriesViewModel
                                                  .createCategory(category)
                                              : widget.categoriesViewModel
                                                  .updateCategory(category),
                                  onCancel:
                                      () =>
                                          category.id == null
                                              ? widget.categoriesViewModel
                                                  .removeCategory(category)
                                              : widget
                                                  .categoriesViewModel
                                                  .editingCategory = null,
                                );
                              },
                            )
                            : Padding(
                              padding: const EdgeInsets.all(
                                16,
                              ).copyWith(top: 40),
                              child: Text(
                                tr.noCategoryFound,
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                  ),
                ],
              ),
            ),
            if (widget.categoriesViewModel.selectedAccount != null)
              Positioned(
                bottom: 24,
                right: 24,
                child: AddFab(
                  heroTag: 'add_category',
                  onPressed: widget.categoriesViewModel.addCategory,
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
