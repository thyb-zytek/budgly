import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/models/account/account.dart';
import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:flutter/material.dart';

class AccountsForm extends StatelessWidget {
  final List<Account> accounts;
  final Function(Account account) onAdd;
  final Function(String id, Account Function(Account) account, String Function(Account) idSelector) onEdit;
  final Function(String id, String Function(Account) idSelector) onDelete;

  const AccountsForm({
    super.key,
    required this.accounts,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    AppLocalizations tr = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 16,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 16, bottom: 24),
            child: Text(tr.accounts, style: theme.textTheme.headlineLarge),
          ),

          BudglyButton(
            leadingIcon: Icons.add_rounded,
            text: tr.newAccount,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
