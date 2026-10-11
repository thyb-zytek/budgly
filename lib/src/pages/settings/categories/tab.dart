import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/pages/settings/categories/categories_settings_provider.dart';
import 'package:budgly/src/pages/settings/categories/widgets/categories_tab_content.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/state/accounts_provider.dart';

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

    return CategoriesTabContent(
      formKey: _formKey,
      scrollController: _scrollController,
      nameController: _nameController,
      thresholdController: _thresholdController,
      formColor: _formColor,
      formIcon: _formIcon,
      onColorChanged: (color) => setState(() => _formColor = color),
      onIconChanged: (icon) => setState(() => _formIcon = icon),
      onConfirmDelete: _confirmDelete,
      onAddCategory: _addCategory,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
