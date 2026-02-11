import 'package:app/src/shared/widgets/accounts/view_card.dart';
import 'package:app/src/shared/widgets/inputs/dropdown.dart';
import 'package:flutter/material.dart';
import 'package:app/src/models/account/account.dart';

class AccountSelector extends StatelessWidget {
  final List<Account> accounts;
  final Account? selectedAccount;
  final Function(Account) onSelect;

  const AccountSelector({
    super.key,
    required this.accounts,
    this.selectedAccount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    final validAccounts = accounts.where((account) => account.id != null).toList();
    final initialAccount = selectedAccount ?? (validAccounts.isNotEmpty ? validAccounts.first : null);

    if (validAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: DropDown<Account>(
        initialValue: initialAccount!,
        onSelect: (account) => onSelect(account),
        options: validAccounts,
        dense: true,
        optionBuilder:
            (account, isSelected) => SizedBox(
              width: MediaQuery.of(context).size.width * .75,
              child: AccountViewCard(
                account: account,
                color:
                    isSelected
                        ? theme.colorScheme.primary.withAlpha(75)
                        : Theme.of(context).colorScheme.surfaceContainer,
              ),
            ),
      ),
    );
  }
}
