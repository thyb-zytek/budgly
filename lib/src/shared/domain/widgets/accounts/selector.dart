import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/account_view.dart';
import 'package:budgly/src/shared/ui/widgets/layout/avatar.dart';
import 'package:budgly/src/shared/ui/widgets/selector.dart';
import 'package:flutter/material.dart';

/// Account switcher, in two flavours:
///  - default: full-width row (avatar + name + dropdown arrow) using the
///    shared [Selector] chrome — used wherever there's room, e.g. the
///    expanded summary card.
///  - [compact]: avatar-only trigger with no background/arrow, for tight
///    spaces like the collapsed summary header. The dropdown menu itself
///    is unchanged either way — always the full account list.
class AccountSelector extends StatelessWidget {
  final List<Account> accounts;
  final Account? selectedAccount;
  final ValueChanged<Account> onSelect;
  final Color? backgroundColor;
  final bool compact;

  const AccountSelector({
    super.key,
    required this.accounts,
    this.selectedAccount,
    required this.onSelect,
    this.backgroundColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final validAccounts = accounts.where((account) => account.id != null).toList();
    if (validAccounts.isEmpty) return const SizedBox.shrink();

    if (!compact) {
      return Selector<Account>(
        items: validAccounts,
        selectedItem: selectedAccount,
        onSelect: onSelect,
        maxHeight: 300,
        backgroundColor: backgroundColor,
        itemBuilder: (context, account) => Padding(
          padding: const EdgeInsets.all(4.0),
          child: AccountView(account: account, color: Colors.transparent),
        ),
      );
    }

    final theme = Theme.of(context);
    final current = (selectedAccount != null && validAccounts.contains(selectedAccount))
        ? selectedAccount!
        : validAccounts.first;

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
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final account in validAccounts)
          PopupMenuItem<Account>(
            value: account,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: AccountView(account: account, color: Colors.transparent),
            ),
          ),
      ],
      child: Avatar(
        initial: current.name.isNotEmpty ? current.name[0].toUpperCase() : '?',
        backgroundColor: current.color,
        picture: current.pictureUrl,
        isLocalPicture: false,
        size: 32,
      ),
    );
  }
}
