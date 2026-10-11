import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/settings/accounts/accounts_settings_provider.dart';
import 'package:budgly/src/pages/settings/widgets/add_entity.dart';
import 'package:budgly/src/pages/settings/widgets/entity_title.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/account_form.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/account_view.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/riverpod_feedback.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:budgly/src/shared/ui/widgets/image/account_image_picker.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountsTabContent extends ConsumerWidget {
  const AccountsTabContent({
    super.key,
    required this.formKey,
    required this.scrollController,
    required this.nameController,
    required this.formColor,
    required this.formPicture,
    required this.onColorChanged,
    required this.onPictureChanged,
    required this.onConfirmDelete,
    required this.onAddAccount,
  });

  final GlobalKey<FormState> formKey;
  final ScrollController scrollController;
  final TextEditingController nameController;
  final Color formColor;
  final String? formPicture;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<String?> onPictureChanged;
  final ValueChanged<Account> onConfirmDelete;
  final VoidCallback onAddAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = AppLocalizations.of(context)!;
    final persistedAccounts = ref.watch(
      accountsSessionProvider.select((s) => s.accounts),
    );
    final settings = ref.watch(
      accountsSettingsProvider.select(
        (s) => (
          localAccounts: s.localAccounts,
          isLoading: s.status.isLoading,
          editingAccountId: s.editingAccount?.id,
          isCreatingAccount: s.isCreatingAccount,
        ),
      ),
    );
    final accounts = [...persistedAccounts, ...settings.localAccounts];

    return RiverpodFeedback(
      messageListenable: accountsSettingsProvider.select(
        (s) => s.status.pendingMessage,
      ),
      onConsume: (ref) =>
          ref.read(accountsSettingsProvider.notifier).consumeMessage(),
      child: settings.isLoading
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
                                controller: scrollController,
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
                                            account.id != null &&
                                                account.id !=
                                                    settings.editingAccountId
                                            ? AccountView(
                                                account: account,
                                                onEdit: () => ref
                                                    .read(
                                                      accountsSettingsProvider
                                                          .notifier,
                                                    )
                                                    .setEditingAccount(account),
                                                onDelete: () =>
                                                    onConfirmDelete(account),
                                              )
                                            : AccountForm(
                                                formKey: formKey,
                                                nameController: nameController,
                                                initialColor: formColor,
                                                initialPicture: formPicture,
                                                pickImage: AccountImagePicker
                                                    .pickAndCropImage,
                                                onColorChanged: onColorChanged,
                                                onPictureChanged:
                                                    onPictureChanged,
                                                onSubmit: () {
                                                  final notifier = ref.read(
                                                    accountsSettingsProvider
                                                        .notifier,
                                                  );
                                                  final isLocal =
                                                      account.id == null;
                                                  final isLocalPicture =
                                                      formPicture != null &&
                                                      !formPicture!.startsWith(
                                                        'http',
                                                      );
                                                  if (isLocal) {
                                                    notifier.createAccount(
                                                      draftAccount: account,
                                                      name: nameController.text,
                                                      color: formColor,
                                                      picture: formPicture,
                                                      isLocalPicture:
                                                          isLocalPicture,
                                                    );
                                                  } else {
                                                    notifier.updateAccount(
                                                      account: account,
                                                      name: nameController.text,
                                                      color: formColor,
                                                      picture: formPicture,
                                                      isLocalPicture:
                                                          isLocalPicture,
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
                                padding: const EdgeInsets.all(16)
                                    .copyWith(top: 40),
                                child: Text(tr.noAccountFound),
                              ),
                      ),
                    ],
                  ),
                ),
                AddEntity(
                  heroTag: 'add_account',
                  label: tr.fabNewAccount,
                  disabled: settings.isCreatingAccount,
                  onPressed: onAddAccount,
                ),
              ],
            ),
    );
  }
}
