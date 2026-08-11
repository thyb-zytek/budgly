import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/settings/widgets/accounts/account_form.dart';
import 'package:budgly/src/pages/settings/widgets/accounts/view_model.dart';
import 'package:budgly/src/pages/settings/widgets/add_entity.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/pages/settings/widgets/entity_title.dart';
import 'package:budgly/src/shared/widgets/accounts/default.dart';
import 'package:budgly/src/shared/widgets/common/card.dart';
import 'package:flutter/material.dart';

class AccountsTab extends StatefulWidget {
  final AccountsViewModel accountsViewModel;

  const AccountsTab({super.key, required this.accountsViewModel});

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab>
    with AutomaticKeepAliveClientMixin<AccountsTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (!widget.accountsViewModel.hasAccountsLoaded) {
      widget.accountsViewModel.loadAccounts();
    }
  }

  @override
  void didUpdateWidget(covariant AccountsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountsViewModel != widget.accountsViewModel &&
        !widget.accountsViewModel.hasAccountsLoaded) {
      widget.accountsViewModel.loadAccounts();
    }
  }

  void _confirmDelete(Account account) {
    final tr = AppLocalizations.of(context)!;

    showConfirmDelete(
      context,
      title: tr.confirmDeleteAccount(account.name),
      content: tr.confirmDeleteAccountMessage(account.name),
      onConfirm: () async {
        await widget.accountsViewModel.removeAccount(account);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tr = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: widget.accountsViewModel,
      builder: (context, child) {
        if (widget.accountsViewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final accounts = widget.accountsViewModel.accounts;
        final editingAccountId = widget.accountsViewModel.editingAccount?.id;

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EntityTitle(
                    title: tr.accounts,
                    subtitle: tr.accountsDescription,
                  ),
                  Expanded(
                    child: accounts.isNotEmpty
                        ? ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: accounts.length,
                            itemBuilder: (context, index) {
                              final account = accounts[index];
                              return BudglyCard(
                                key: ValueKey(
                                  account.id ?? identityHashCode(account),
                                ),
                                child:
                                    (account.id != null &&
                                        account.id != editingAccountId)
                                    ? AccountView(
                                        account: account,
                                        onEdit: () =>
                                            widget
                                                    .accountsViewModel
                                                    .editingAccount =
                                                account,
                                        onDelete: () => _confirmDelete(account),
                                      )
                                    : AccountForm(
                                        formKey: _formKey,
                                        viewModel: widget.accountsViewModel,
                                        account: account,
                                      ),
                              );
                            },
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16).copyWith(top: 40),
                            child: Text(tr.noAccountFound),
                          ),
                  ),
                ],
              ),
            ),
            AddEntity(
              heroTag: 'add_account',
              disabled: widget.accountsViewModel.isCreatingAccount,
              onPressed: widget.accountsViewModel.addAccount,
            ),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
