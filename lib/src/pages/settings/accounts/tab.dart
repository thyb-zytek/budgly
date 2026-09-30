import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/settings/accounts/accounts_settings_provider.dart';
import 'package:budgly/src/shared/ui/widgets/image/account_image_picker.dart';
import 'package:budgly/src/pages/settings/widgets/add_entity.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/pages/settings/widgets/entity_title.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/account_form.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/account_view.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/riverpod_feedback.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountsTab extends ConsumerStatefulWidget {
  const AccountsTab({super.key});

  @override
  ConsumerState<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends ConsumerState<AccountsTab>
    with AutomaticKeepAliveClientMixin<AccountsTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  Color _formColor = Colors.primaries.first;
  String? _formPicture;

  @override
  void initState() {
    super.initState();
    if (!ref.read(accountsSessionProvider).hasLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(accountsSettingsProvider.notifier).loadAccounts();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _confirmDelete(Account account) {
    final tr = AppLocalizations.of(context)!;

    showConfirmDelete(
      context,
      title: tr.confirmDeleteAccount(account.name),
      content: tr.confirmDeleteAccountMessage(account.name),
      onConfirm: () async {
        await ref
            .read(accountsSettingsProvider.notifier)
            .removeAccount(account);
      },
    );
  }

  Future<void> _addAccount() async {
    final notifier = ref.read(accountsSettingsProvider.notifier);
    final draft = await notifier.addAccount();
    if (draft != null) {
      _nameController.text = draft.name;
      _formColor = draft.color ?? Colors.primaries.first;
      _formPicture = draft.pictureUrl;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tr = AppLocalizations.of(context)!;

    ref.listen(accountsSettingsProvider.select((s) => s.editingAccount), (
      previous,
      next,
    ) {
      _nameController.text = next?.name ?? '';
      _formColor = next?.color ?? Colors.primaries.first;
      _formPicture = next?.pictureUrl;
    });

    final persistedAccounts = ref.watch(
      accountsSessionProvider.select((s) => s.accounts),
    );
    final localAccounts = ref.watch(
      accountsSettingsProvider.select((s) => s.localAccounts),
    );
    final accounts = [...persistedAccounts, ...localAccounts];
    final isLoading = ref.watch(
      accountsSettingsProvider.select((s) => s.status.isLoading),
    );
    final editingAccountId = ref.watch(
      accountsSettingsProvider.select((s) => s.editingAccount?.id),
    );
    final isCreatingAccount = ref.watch(
      accountsSettingsProvider.select((s) => s.isCreatingAccount),
    );

    return RiverpodFeedback(
      messageListenable: accountsSettingsProvider.select(
        (s) => s.status.pendingMessage,
      ),
      onConsume: (ref) =>
          ref.read(accountsSettingsProvider.notifier).consumeMessage(),
      child: isLoading
          ? const AppLoadingIndicator()
          : Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(BudglySpacing.lg),
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
                                    padding: EdgeInsets.only(
                                      bottom: BudglySpacing.sm,
                                    ),
                                    child: Card(
                                      key: ValueKey(
                                        account.id ?? identityHashCode(account),
                                      ),
                                      child: Padding(
                                        padding:
                                            BudglyComponentStyles.cardPadding,
                                        child:
                                            (account.id != null &&
                                                account.id != editingAccountId)
                                            ? AccountView(
                                                account: account,
                                                onEdit: () => ref
                                                    .read(
                                                      accountsSettingsProvider
                                                          .notifier,
                                                    )
                                                    .setEditingAccount(account),
                                                onDelete: () =>
                                                    _confirmDelete(account),
                                              )
                                            : AccountForm(
                                                formKey: _formKey,
                                                nameController: _nameController,
                                                initialColor: _formColor,
                                                initialPicture: _formPicture,
                                                pickImage: AccountImagePicker
                                                    .pickAndCropImage,
                                                onColorChanged: (color) =>
                                                    _formColor = color,
                                                onPictureChanged: (picture) =>
                                                    _formPicture = picture,
                                                onSubmit: () {
                                                  final notifier = ref.read(
                                                    accountsSettingsProvider
                                                        .notifier,
                                                  );
                                                  if (account.id == null) {
                                                    notifier.createAccount(
                                                      draftAccount: account,
                                                      name:
                                                          _nameController.text,
                                                      color: _formColor,
                                                      picture: _formPicture,
                                                      isLocalPicture:
                                                          _formPicture !=
                                                              null &&
                                                          !_formPicture!
                                                              .startsWith(
                                                                'http',
                                                              ),
                                                    );
                                                  } else {
                                                    notifier.updateAccount(
                                                      account: account,
                                                      name:
                                                          _nameController.text,
                                                      color: _formColor,
                                                      picture: _formPicture,
                                                      isLocalPicture:
                                                          _formPicture !=
                                                              null &&
                                                          !_formPicture!
                                                              .startsWith(
                                                                'http',
                                                              ),
                                                    );
                                                  }
                                                },
                                                onCancel: () => ref
                                                    .read(
                                                      accountsSettingsProvider
                                                          .notifier,
                                                    )
                                                    .cancelEdit(),
                                                withPulse: true,
                                                withHint: true,
                                              ),
                                      ),
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
                AddEntity(
                  heroTag: 'add_account',
                  label: tr.fabNewAccount,
                  disabled: isCreatingAccount,
                  onPressed: _addAccount,
                ),
              ],
            ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
