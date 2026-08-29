import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/settings/accounts/view_model.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/account_form.dart';
import 'package:budgly/src/pages/settings/widgets/add_entity.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/pages/settings/widgets/entity_title.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/account_view.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/view_model_feedback.dart';
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
  final ScrollController _scrollController = ScrollController();

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    return ViewModelFeedback(
      viewModel: widget.accountsViewModel,
      child: ListenableBuilder(
      listenable: widget.accountsViewModel,
      builder: (context, child) {
        if (widget.accountsViewModel.isLoading) {
          return const AppLoadingIndicator();
        }
        final accounts = widget.accountsViewModel.accounts;
        final editingAccountId = widget.accountsViewModel.editingAccount?.id;

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(BudglySpacing.lg),
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
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: accounts.length,
                            itemBuilder: (context, index) {
                              final account = accounts[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: BudglySpacing.sm),
                                child: Card(
                                  key: ValueKey(
                                    account.id ?? identityHashCode(account),
                                  ),
                                  child: Padding(
                                    padding: BudglyComponentStyles.cardPadding,
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
                                            onDelete: () =>
                                                _confirmDelete(account),
                                          )
                                        : AccountForm(
                                            formKey: _formKey,
                                            viewModel: widget.accountsViewModel,
                                            account: account,
                                            withPulse: true,
                                            withHint: true,
                                          ),
                                  ),
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
              label: tr.fabNewAccount,
              disabled: widget.accountsViewModel.isCreatingAccount,
              onPressed: () {
                widget.accountsViewModel.addAccount();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              },
            ),
          ],
        );
      },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
