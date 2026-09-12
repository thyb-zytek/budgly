import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/account_view.dart';
import 'package:budgly/src/shared/ui/widgets/layout/avatar.dart';
import 'package:budgly/src/shared/ui/widgets/selector.dart';
import 'package:flutter/material.dart';

class AccountSelector extends StatelessWidget {
  final List<Account> accounts;
  final Account? selectedAccount;
  final ValueChanged<Account> onSelect;
  final Color? backgroundColor;
  final bool compact;

  /// When true, prepends an "All accounts" entry to the list. It is hidden by
  /// default so existing call sites keep their current behavior.
  final bool showAllOption;

  /// Label rendered for the "All accounts" entry.
  final String allAccountsLabel;

  /// Whether the "All accounts" entry is currently active.
  final bool isAllSelected;

  /// Called when the "All accounts" entry is chosen.
  final VoidCallback? onSelectAll;

  const AccountSelector({
    super.key,
    required this.accounts,
    this.selectedAccount,
    required this.onSelect,
    this.backgroundColor,
    this.compact = false,
    this.showAllOption = false,
    this.allAccountsLabel = '',
    this.isAllSelected = false,
    this.onSelectAll,
  });

  Account? get _allOption =>
      showAllOption && allAccountsLabel.isNotEmpty
          ? Account(name: allAccountsLabel)
          : null;

  void _handleSelect(Account item, VoidCallback onSelectAll) {
    if (item.id == null) {
      onSelectAll();
    } else {
      onSelect(item);
    }
  }

  Widget _buildAllItem(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(BudglySpacing.xs),
      child: Row(
        spacing: 16,
        children: [
          _allAccountsAvatar(context, size: 52),
          Flexible(
            child: Text(
              allAccountsLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }

  /// "All accounts" leader reusing the exact [Avatar] footprint the per-account
  /// entries rely on, so switching between an account view and the aggregated
  /// entry never changes the layout size.
  Widget _allAccountsAvatar(BuildContext context, {required double size}) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary,
      ),
      child: Icon(
        Icons.account_balance_wallet_rounded,
        size: size * 0.55,
        color: theme.colorScheme.onPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validAccounts =
        accounts.where((account) => account.id != null).toList();
    if (validAccounts.isEmpty && _allOption == null) {
      return const SizedBox.shrink();
    }
    final allOption = _allOption;

    if (!compact) {
      final options = [?allOption, ...validAccounts];
      final current = allOption != null && isAllSelected
          ? allOption
          : selectedAccount != null &&
                  validAccounts.contains(selectedAccount)
              ? selectedAccount!
              : options.first;
      return Selector<Account>(
        items: options,
        selectedItem: current,
        onSelect: (item) =>
            _handleSelect(item, onSelectAll ?? () {}),
        maxHeight: 300,
        backgroundColor: backgroundColor,
        itemBuilder: (context, item) => item.id == null
            ? _buildAllItem(context)
            : Padding(
                padding: EdgeInsets.all(BudglySpacing.xs),
                child: AccountView(
                  account: item,
                  color: Colors.transparent,
                ),
              ),
      );
    }

    final theme = Theme.of(context);
    final current = allOption != null && isAllSelected
        ? allOption
        : selectedAccount != null && validAccounts.contains(selectedAccount)
            ? selectedAccount!
            : validAccounts.isNotEmpty
                ? validAccounts.first
                : allOption!;
    final anyAccount = selectedAccount != null &&
        validAccounts.contains(selectedAccount);

    return PopupMenuButton<Account>(
      initialValue: current,
      tooltip: '',
      color: theme.colorScheme.surface,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(maxHeight: 300),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      menuPadding: const EdgeInsets.all(8),
      onSelected: (item) => _handleSelect(item, onSelectAll ?? () {}),
      itemBuilder: (context) => [
        if (allOption != null)
          PopupMenuItem<Account>(
            value: allOption,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _buildAllItem(context),
          ),
        for (final account in validAccounts)
          PopupMenuItem<Account>(
            value: account,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Padding(
              padding: EdgeInsets.all(BudglySpacing.xs),
              child: AccountView(account: account, color: Colors.transparent),
            ),
          ),
      ],
      child: !anyAccount && allOption != null
          ? _allAccountsAvatar(context, size: 48)
          : Avatar(
              initial: current.initial,
              backgroundColor: current.color,
              picture: current.pictureUrl,
              isLocalPicture: false,
              size: 48,
            ),
    );
  }
}