import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/models/account/account.dart';
import 'package:app/src/pages/settings/widgets/accounts/view_model.dart';
import 'package:app/src/pages/settings/widgets/add_fab.dart';
import 'package:app/src/pages/settings/widgets/confirm_dialog.dart';
import 'package:app/src/shared/widgets/accounts/form_card.dart';
import 'package:app/src/shared/widgets/accounts/view_card.dart';
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
    if (!oldWidget.accountsViewModel.hasAccountsLoaded &&
        widget.accountsViewModel.hasAccountsLoaded) {
      widget.accountsViewModel.loadAccounts();
    }
  }

  @override
  void dispose() {
    widget.accountsViewModel.dispose();
    super.dispose();
  }

  void _confirmDelete(Account account) {
    showDialog(
      context: context,
      builder:
          (context) => ConfirmDialog(
            title: AppLocalizations.of(
              context,
            )!.confirmDeleteAccount(account.name),
            content: AppLocalizations.of(
              context,
            )!.confirmDeleteAccountMessage(account.name),
            onConfirm: () => widget.accountsViewModel.removeAccount(account),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    AppLocalizations tr = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.accountsViewModel,
      builder: (context, child) {
        if (widget.accountsViewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

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
                        widget.accountsViewModel.accounts.isNotEmpty
                            ? ListView.builder(
                              itemCount:
                                  widget.accountsViewModel.accounts.length,
                              itemBuilder: (context, index) {
                                final account =
                                    widget.accountsViewModel.accounts[index];
                                if (account.id != null &&
                                    account.id !=
                                        widget
                                            .accountsViewModel
                                            .editingAccount
                                            ?.id) {
                                  return AccountViewCard(
                                    account: account,
                                    onEdit:
                                        () =>
                                            widget
                                                .accountsViewModel
                                                .editingAccount = account,
                                    onDelete: () => _confirmDelete(account),
                                  );
                                }

                                return AccountFormCard(
                                  formKey: _formKey,
                                  editingData:
                                      widget.accountsViewModel.editingData,
                                  pickImage:
                                      () => widget.accountsViewModel.pickImage(
                                        context,
                                      ),
                                  onChangeColor:
                                      (color) =>
                                          widget.accountsViewModel.color =
                                              color,
                                  onChangePicture:
                                      (picture) =>
                                          widget.accountsViewModel.picture =
                                              picture,
                                  onSubmit:
                                      () =>
                                          account.id == null
                                              ? widget.accountsViewModel
                                                  .createAccount(account)
                                              : widget.accountsViewModel
                                                  .updateAccount(account),
                                  onCancel:
                                      () =>
                                          account.id == null
                                              ? widget.accountsViewModel
                                                  .removeAccount(account)
                                              : widget
                                                  .accountsViewModel
                                                  .editingAccount = null,
                                  onRemovePicture:
                                      () =>
                                          widget.accountsViewModel
                                              .removePicture(),
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
              child: AddFab(
                heroTag: 'add_account',
                onPressed: widget.accountsViewModel.addAccount,
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
