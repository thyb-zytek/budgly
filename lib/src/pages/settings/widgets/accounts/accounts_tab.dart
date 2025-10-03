import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/models/account/account.dart';
import 'package:app/src/pages/settings/widgets/accounts/view_model.dart';
import 'package:app/src/pages/settings/widgets/add_fab.dart';
import 'package:app/src/pages/settings/widgets/confirm_dialog.dart';
import 'package:app/src/shared/widgets/accounts/account_form_card.dart';
import 'package:app/src/shared/widgets/accounts/view_card.dart';
import 'package:flutter/material.dart';

class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key});

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab>
    with AutomaticKeepAliveClientMixin<AccountsTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late AccountsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AccountsViewModel();
    _viewModel.loadAccounts();
  }

  @override
  void dispose() {
    _viewModel.dispose();
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
            onConfirm: () => _viewModel.removeAccount(account),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // important for AutomaticKeepAliveClientMixin
    AppLocalizations tr = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
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
                    child: ListView.builder(
                      itemCount: _viewModel.accounts.length,
                      itemBuilder: (context, index) {
                        final account = _viewModel.accounts[index];
                        if (account.id != null &&
                            account.id != _viewModel.editingAccount?.id) {
                          return AccountViewCard(
                            account: account,
                            onEdit: () => _viewModel.editingAccount = account,
                            onDelete: () => _confirmDelete(account),
                          );
                        }

                        return AccountFormCard(
                          formKey: _formKey,
                          editingData: _viewModel.editingData,
                          pickImage: () => _viewModel.pickImage(context),
                          onChangeColor: (color) => _viewModel.color = color,
                          onChangePicture:
                              (picture) => _viewModel.picture = picture,
                          onSubmit:
                              () =>
                                  account.id == null
                                      ? _viewModel.createAccount(account)
                                      : _viewModel.updateAccount(account),
                          onCancel:
                              () =>
                                  account.id == null
                                      ? _viewModel.removeAccount(account)
                                      : _viewModel.editingAccount = null,
                          onRemovePicture: () => _viewModel.removePicture(),
                        );
                      },
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
                onPressed: _viewModel.addAccount,
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
