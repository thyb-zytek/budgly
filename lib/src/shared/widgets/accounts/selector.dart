import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/shared/widgets/accounts/account_view.dart';
import 'package:budgly/src/shared/widgets/selector/selector.dart';
import 'package:flutter/material.dart';

class AccountSelector extends StatelessWidget {
  final List<Account> accounts;
  final Account? selectedAccount;
  final ValueChanged<Account> onSelect;
  final Color? backgroundColor;

  const AccountSelector({
    super.key,
    required this.accounts,
    this.selectedAccount,
    required this.onSelect,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final validAccounts = accounts
        .where((account) => account.id != null)
        .toList();

    return Selector<Account>(
      items: validAccounts,
      selectedItem: selectedAccount,
      onSelect: onSelect,
      maxHeight: 300,
      backgroundColor: backgroundColor,
      itemBuilder: (context, account) => AccountView(
        account: account,
        color: Colors.transparent,
      ),
    );
  }
}