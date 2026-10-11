import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/pages/settings/categories/categories_settings_provider.dart';
import 'package:budgly/src/pages/settings/widgets/add_entity.dart';
import 'package:budgly/src/pages/settings/widgets/entity_title.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_form.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_view.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/riverpod_feedback.dart';
import 'package:budgly/src/shared/ui/widgets/layout/empty_state.dart';
import 'package:budgly/src/shared/ui/widgets/layout/framed_container.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoriesTabContent extends ConsumerWidget {
  const CategoriesTabContent({
    super.key,
    required this.formKey,
    required this.scrollController,
    required this.nameController,
    required this.thresholdController,
    required this.formColor,
    required this.formIcon,
    required this.onColorChanged,
    required this.onIconChanged,
    required this.onConfirmDelete,
    required this.onAddCategory,
  });

  final GlobalKey<FormState> formKey;
  final ScrollController scrollController;
  final TextEditingController nameController;
  final TextEditingController thresholdController;
  final Color formColor;
  final CategoryIcon formIcon;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<CategoryIcon> onIconChanged;
  final void Function(Category category, String accountName) onConfirmDelete;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final accounts = ref.watch(
      accountsSessionProvider.select((state) => state.accounts),
    );
    final settings = ref.watch(
      categoriesSettingsProvider.select(
        (state) => (
          account: state.account,
          isLoading: state.status.isLoading,
          editingCategory: state.editingCategory,
          localCategories: state.localCategories,
          availableIcons: state.availableIcons,
          isCreatingCategory: state.isCreatingCategory,
        ),
      ),
    );

    final selectedAccount = accounts.isEmpty
        ? null
        : settings.account == null
        ? accounts.first
        : accounts.firstWhere(
            (account) => account.id == settings.account!.id,
            orElse: () => accounts.first,
          );
    final persistedCategories = selectedAccount?.id == null
        ? const <Category>[]
        : ref.watch(
            categoriesSessionProvider.select(
              (state) =>
                  state.categoriesByAccount[selectedAccount!.id!] ??
                  const <Category>[],
            ),
          );
    final categories = [...persistedCategories, ...settings.localCategories];

    return RiverpodFeedback(
      messageListenable: categoriesSettingsProvider.select(
        (s) => s.status.pendingMessage,
      ),
      onConsume: (ref) =>
          ref.read(categoriesSettingsProvider.notifier).consumeMessage(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: BudglySpacing.lg,
              vertical: BudglySpacing.sm,
            ),
            child: EntityTitle(
              title: tr.categories,
              subtitle: tr.selectAccountToManageCategories,
            ),
          ),
          Expanded(
            child: settings.isLoading
                ? const AppLoadingIndicator()
                : accounts.isEmpty
                ? EmptyState(
                    icon: Icons.info_outline,
                    title: tr.noAccountForCategories,
                  )
                : Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: BudglySpacing.lg,
                          vertical: BudglySpacing.sm,
                        ),
                        child: Column(
                          spacing: 8,
                          children: [
                            FramedContainer(
                              child: AccountSelector(
                                accounts: accounts,
                                selectedAccount: selectedAccount!,
                                backgroundColor: theme.colorScheme.surface,
                                onSelect: (account) => ref
                                    .read(categoriesSettingsProvider.notifier)
                                    .selectAccount(account),
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
                                      controller: scrollController,
                                      padding: const EdgeInsets.only(
                                        bottom: 100,
                                      ),
                                      itemCount: categories.length,
                                      itemBuilder: (context, index) {
                                        final category = categories[index];
                                        final editingId =
                                            settings.editingCategory?.id;
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Card(
                                            key: ValueKey(
                                              category.id ??
                                                  identityHashCode(category),
                                            ),
                                            child: Padding(
                                              padding: BudglyComponentStyles
                                                  .cardPadding,
                                              child:
                                                  category.id != null &&
                                                      category.id != editingId
                                                  ? CategoryView(
                                                      category: category,
                                                      onEdit: () => ref
                                                          .read(
                                                            categoriesSettingsProvider
                                                                .notifier,
                                                          )
                                                          .setEditingCategory(
                                                            category,
                                                          ),
                                                      onDelete: () =>
                                                          onConfirmDelete(
                                                            category,
                                                            selectedAccount
                                                                .name,
                                                          ),
                                                    )
                                                  : CategoryForm(
                                                      formKey: formKey,
                                                      nameController:
                                                          nameController,
                                                      monthlyThresholdController:
                                                          thresholdController,
                                                      initialColor: formColor,
                                                      initialIcon: formIcon,
                                                      availableIcons: settings
                                                          .availableIcons,
                                                      onColorChanged:
                                                          onColorChanged,
                                                      onIconChanged:
                                                          onIconChanged,
                                                      onSubmit: () {
                                                        final notifier = ref.read(
                                                          categoriesSettingsProvider
                                                              .notifier,
                                                        );
                                                        final isLocal =
                                                            category.id == null;
                                                        if (isLocal) {
                                                          notifier.createCategory(
                                                            draft: category,
                                                            name: nameController
                                                                .text,
                                                            color: formColor,
                                                            icon: formIcon,
                                                            monthlyThreshold:
                                                                thresholdController
                                                                    .text,
                                                          );
                                                        } else {
                                                          notifier.updateCategory(
                                                            category: category,
                                                            name: nameController
                                                                .text,
                                                            color: formColor,
                                                            icon: formIcon,
                                                            monthlyThreshold:
                                                                thresholdController
                                                                    .text,
                                                          );
                                                        }
                                                      },
                                                      onCancel: () => ref
                                                          .read(
                                                            categoriesSettingsProvider
                                                                .notifier,
                                                          )
                                                          .cancelEdit(),
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
                        disabled: settings.isCreatingCategory,
                        onPressed: onAddCategory,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
