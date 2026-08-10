import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/settings/widgets/accounts/view_model.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/shared/widgets/accounts/default.dart';
import 'package:budgly/src/shared/widgets/accounts/form.dart';
import 'package:budgly/src/shared/widgets/buttons/add_fab.dart';
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
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ConfirmDelete(
          title: tr.confirmDeleteAccount(account.name),
          content: tr.confirmDeleteAccountMessage(
            account.name
          ),
          onConfirm: () async {
            await widget.accountsViewModel.removeAccount(account);
          },
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

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
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 24),
                    child: Text(
                      tr.accounts,
                      style: theme.textTheme.headlineLarge,
                    ),
                  ),
                  Expanded(
                    child:
                        accounts.isNotEmpty
                            ? ListView.builder(
                              itemCount: accounts.length,
                              itemBuilder: (context, index) {
                                final account = accounts[index];
                                return BudglyCard(
                                  key: ValueKey(account.id ?? identityHashCode(account)),
                                  child:
                                      (account.id != null &&
                                              account.id != editingAccountId)
                                          ? AccountView(
                                            account: account,
                                            onEdit:
                                                () =>
                                                    widget
                                                            .accountsViewModel
                                                            .editingAccount =
                                                        account,
                                            onDelete:
                                                () => _confirmDelete(account),
                                          )
                                          : AccountForm(
                                            formKey: _formKey,
                                            editingData:
                                                widget
                                                    .accountsViewModel
                                                    .editingData,
                                            pickImage:
                                                () => widget.accountsViewModel
                                                    .pickImage(context),
                                            onChangeColor:
                                                (color) =>
                                                    widget
                                                        .accountsViewModel
                                                        .color = color,
                                            onChangePicture:
                                                (picture) =>
                                                    widget
                                                        .accountsViewModel
                                                        .picture = picture,
                                            onSubmit:
                                                () =>
                                                    account.id == null
                                                        ? widget
                                                            .accountsViewModel
                                                            .createAccount(
                                                              account,
                                                            )
                                                        : widget
                                                            .accountsViewModel
                                                            .updateAccount(
                                                              account,
                                                            ),
                                            onCancel:
                                                () =>
                                                    account.id == null
                                                        ? widget
                                                            .accountsViewModel
                                                            .removeAccount(
                                                              account,
                                                            )
                                                        : widget
                                                            .accountsViewModel
                                                            .cancelEdit(),
                                            onRemovePicture:
                                                () =>
                                                    widget.accountsViewModel
                                                        .removePicture(),
                                          ),
                                );
                              },
                            )
                            : Padding(
                              padding: const EdgeInsets.all(
                                16,
                              ).copyWith(top: 40),
                              child: Text(tr.noAccountFound),
                            ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: IgnorePointer(
                ignoring: widget.accountsViewModel.isCreatingAccount,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: widget.accountsViewModel.isCreatingAccount ? 0.4 : 1,
                  child: AddFab(
                    heroTag: 'add_account',
                    onPressed: widget.accountsViewModel.addAccount,
                  ),
                ),
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