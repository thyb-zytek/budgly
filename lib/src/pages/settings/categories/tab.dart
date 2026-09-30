import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/pages/settings/categories/categories_settings_provider.dart';
import 'package:budgly/src/pages/settings/widgets/add_entity.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
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
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoriesTab extends ConsumerStatefulWidget {
  const CategoriesTab({super.key});

  @override
  ConsumerState<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends ConsumerState<CategoriesTab>
    with AutomaticKeepAliveClientMixin<CategoriesTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _thresholdController = TextEditingController();
  Color _formColor = Colors.primaries.first;
  CategoryIcon _formIcon = CategoryIcon(
    iconName: 'category',
    iconCode: 0,
    iconPack: 'MaterialIcons',
    labels: {},
  );

  @override
  void initState() {
    super.initState();

    // Do not mutate Riverpod state while the PageView is mounting this tab.
    // Accounts are normally preloaded by ProfileSession, but keep this tab
    // safe when it is reached without that bootstrap (e.g. in isolation).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accountsState = ref.read(accountsSessionProvider);
      if (!accountsState.hasLoaded) {
        unawaited(ref.read(accountsSessionProvider.notifier).load());
        return;
      }
      _syncAccount(accountsState.accounts);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _confirmDelete(Category category, String accountName) {
    final tr = AppLocalizations.of(context)!;
    showConfirmDelete(
      context,
      title: tr.confirmDeleteCategory(category.name!),
      content: tr.confirmDeleteCategoryMessage(category.name!, accountName),
      onConfirm: () => ref
          .read(categoriesSettingsProvider.notifier)
          .removeCategory(category),
    );
  }

  void _syncAccount(List<Account> accounts) {
    if (accounts.isEmpty) return;
    final notifier = ref.read(categoriesSettingsProvider.notifier);
    final selected = ref.read(categoriesSettingsProvider).account;
    final selectedId = selected?.id;
    final next = selectedId == null
        ? accounts.first
        : accounts.cast<Account?>().firstWhere(
                (account) => account!.id == selectedId,
                orElse: () => null,
              ) ??
              accounts.first;
    if (next.id != selectedId) notifier.selectAccount(next);
  }

  Future<void> _addCategory() async {
    final category = await ref
        .read(categoriesSettingsProvider.notifier)
        .addCategory();
    if (category != null) {
      final state = ref.read(categoriesSettingsProvider);
      final category = state.editingCategory;
      _nameController.text = category?.name ?? '';
      _thresholdController.text = category?.monthlyThreshold?.toString() ?? '';
      _formColor = category?.color ?? Colors.primaries.first;
      _formIcon = category?.icon ?? _formIcon;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final accounts = ref.watch(
      accountsSessionProvider.select((state) => state.accounts),
    );
    final state = ref.watch(categoriesSettingsProvider);
    final categoriesSession = ref.watch(categoriesSessionProvider);

    ref.listen(
      categoriesSettingsProvider.select(
        (state) => (state.editingCategory, state.availableIcons),
      ),
      (_, next) {
        final category = next.$1;
        _nameController.text = category?.name ?? '';
        _thresholdController.text =
            category?.monthlyThreshold?.toString() ?? '';
        _formColor = category?.color ?? Colors.primaries.first;
        _formIcon = category?.icon ?? _formIcon;
      },
    );

    ref.listen<List<Account>>(
      accountsSessionProvider.select((state) => state.accounts),
      (_, next) => _syncAccount(next),
    );

    final selectedAccount = state.account == null
        ? (accounts.isEmpty ? null : accounts.first)
        : accounts.firstWhere(
            (account) => account.id == state.account!.id,
            orElse: () => accounts.first,
          );
    final persistedCategories = selectedAccount?.id == null
        ? const <Category>[]
        : (categoriesSession.categoriesByAccount[selectedAccount!.id!] ??
              const <Category>[]);
    final categories = [...persistedCategories, ...state.localCategories];

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
            child: state.status.isLoading
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
                                      controller: _scrollController,
                                      padding: const EdgeInsets.only(
                                        bottom: 100,
                                      ),
                                      itemCount: categories.length,
                                      itemBuilder: (context, index) {
                                        final category = categories[index];
                                        final editingId =
                                            state.editingCategory?.id;
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
                                                          _confirmDelete(
                                                            category,
                                                            selectedAccount
                                                                .name,
                                                          ),
                                                    )
                                                  : CategoryForm(
                                                      formKey: _formKey,
                                                      nameController:
                                                          _nameController,
                                                      monthlyThresholdController:
                                                          _thresholdController,
                                                      initialColor: _formColor,
                                                      initialIcon: _formIcon,
                                                      availableIcons:
                                                          state.availableIcons,
                                                      onColorChanged: (color) =>
                                                          _formColor = color,
                                                      onIconChanged: (icon) =>
                                                          _formIcon = icon,
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
                                                            name:
                                                                _nameController
                                                                    .text,
                                                            color: _formColor,
                                                            icon: _formIcon,
                                                            monthlyThreshold:
                                                                _thresholdController
                                                                    .text,
                                                          );
                                                        } else {
                                                          notifier.updateCategory(
                                                            category: category,
                                                            name:
                                                                _nameController
                                                                    .text,
                                                            color: _formColor,
                                                            icon: _formIcon,
                                                            monthlyThreshold:
                                                                _thresholdController
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
                        disabled: state.isCreatingCategory,
                        onPressed: _addCategory,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
