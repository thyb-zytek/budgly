import 'dart:async';
import 'dart:math';

import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/state/action_status.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/image/account_image_helper.dart';
import 'package:flutter/material.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/account_budgets_provider.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'accounts_settings_provider.g.dart';

Color randomAccountColor() =>
    Colors.primaries[Random().nextInt(Colors.primaries.length)];

/// Combined page state: the local drafts and "which account is being edited" here
/// directly drive what the page renders — not just an action status — so
/// they live in one state object together with [status], rather than as
/// separate providers.
class AccountsSettingsState {
  const AccountsSettingsState({
    required this.localAccounts,
    required this.editingAccount,
    required this.status,
  });

  final List<Account> localAccounts;
  final Account? editingAccount;
  final ActionStatus status;

  bool get isCreatingAccount => localAccounts.isNotEmpty;

  AccountsSettingsState _copyWith({
    List<Account>? localAccounts,
    Object? editingAccount = _unset,
    ActionStatus? status,
  }) => AccountsSettingsState(
    localAccounts: localAccounts ?? this.localAccounts,
    editingAccount: identical(editingAccount, _unset)
        ? this.editingAccount
        : editingAccount as Account?,
    status: status ?? this.status,
  );
}

const _unset = Object();

/// Page-scoped state for account settings. The shared account collection is
/// owned by `AccountsSession`; this Notifier only owns local drafts and action state.
///
/// The persisted account list is *not* duplicated here: it's already
/// reactive via `accountsSessionProvider`. This Notifier only
/// tracks what's specific to the settings page: local (unsaved) drafts,
/// which account is being edited, and the status of create/update/delete
/// actions.
///
/// Like `ProfileSettings`, this Notifier does not own Flutter form controllers.
/// The view owns the form fields and passes their values to this Notifier.
@riverpod
class AccountsSettings extends _$AccountsSettings {
  @override
  AccountsSettingsState build() => const AccountsSettingsState(
    localAccounts: [],
    editingAccount: null,
    status: ActionStatus.idle(),
  );

  void setEditingAccount(Account? account) {
    state = state._copyWith(editingAccount: account);
  }

  void cancelEdit() {
    state = state._copyWith(editingAccount: null);
  }

  Future<void> loadAccounts() async {
    state = state._copyWith(status: state.status.loading());
    try {
      await ref.read(accountsSessionProvider.notifier).load();
      if (!ref.mounted) return;
      // Signed URLs are presentation data. They must never delay the account
      // list, especially when the account list itself came from local cache.
      unawaited(
        Future.wait(
          ref
              .read(accountsSessionProvider)
              .accounts
              .where((account) => account.picture != null && account.id != null)
              .map(_refreshPictureUrl),
        ),
      );
      state = state._copyWith(status: state.status.doneLoading());
    } catch (e) {
      if (!ref.mounted) return;
      state = state._copyWith(status: state.status.failure(e));
    }
  }

  /// Adds a local draft and returns it, so the caller (the adapter) can
  /// prefill the form with the same color the draft was given.
  Future<Account?> addAccount() async {
    if (state.localAccounts.isNotEmpty) return null;

    final account = Account(
      id: null,
      name: '',
      picture: null,
      pictureUrl: null,
      color: randomAccountColor(),
    );
    state = state._copyWith(localAccounts: [...state.localAccounts, account]);
    return account;
  }

  Future<void> _cleanupDeletedAccount(String accountId) async {
    if (!ref.mounted) return;
    try {
      ref.read(categoriesSessionProvider.notifier).invalidateAccount(accountId);
      ref.read(expensesSessionProvider.notifier).clearAccount(accountId);
      ref.read(accountBudgetsSessionProvider.notifier).clearAccount(accountId);
      // Immediate local removal only; neither call waits for the server. The
      // server-side cleanup (uncached documents, storage folder) is a durable
      // `cleanup` operation enqueued once the account deletion reaches the
      // server (see DeletionCleanupService).
      await Future.wait([
        ref.read(expensesServiceProvider).deleteByAccountId(accountId),
        ref.read(accountBudgetsServiceProvider).deleteByAccountId(accountId),
      ]);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clean up deleted account', e, stackTrace);
    }
  }

  Future<void> removeAccount(Account account) async {
    if (account.id == null) {
      state = state._copyWith(
        localAccounts: state.localAccounts
            .where((a) => !identical(a, account))
            .toList(),
      );
      return;
    }

    state = state._copyWith(status: state.status.loading());
    try {
      final accountId = account.id!;
      await ref.read(accountsSessionProvider.notifier).delete(accountId);
      if (!ref.mounted) return;
      state = state._copyWith(
        status: state.status.success(
          const AppUserMessage.success(AppMessageKey.accountDeleted),
        ),
      );
      // Account removal is complete from the user's point of view once the
      // local state and the durable queue are updated.
      unawaited(_cleanupDeletedAccount(accountId));
    } catch (e) {
      if (!ref.mounted) return;
      state = state._copyWith(status: state.status.failure(e));
    }
  }

  Future<void> _refreshPictureUrl(Account account) async {
    if (account.picture == null || account.id == null) return;
    final accountsService = ref.read(accountsServiceProvider);
    try {
      final pictureUrl = await accountsService.getSignedUrl(
        account.picture!,
        account.id!,
      );
      ref
          .read(accountsSessionProvider.notifier)
          .updateLocal(account.copyWith(pictureUrl: pictureUrl));
    } catch (e, st) {
      AppLogger.error('Failed to refresh picture URL', e, st);
    }
  }

  Future<void> createAccount({
    required Account draftAccount,
    required String name,
    required Color color,
    String? picture,
    required bool isLocalPicture,
  }) async {
    state = state._copyWith(status: state.status.loading());
    final accountsService = ref.read(accountsServiceProvider);
    try {
      final imageToUpload = await AccountImageHelper.prepareImage(
        picture,
        isLocal: isLocalPicture,
      );

      Account newAccount = draftAccount.copyWith(
        name: name,
        color: color,
        picture: imageToUpload?.fileName,
      );

      newAccount = await ref
          .read(accountsSessionProvider.notifier)
          .create(newAccount);
      if (!ref.mounted) return;

      if (imageToUpload != null) {
        newAccount = await AccountImageHelper.uploadAndLinkImage(
          accountsService,
          newAccount,
          imageToUpload,
        );
        if (!ref.mounted) return;
        ref.read(accountsSessionProvider.notifier).updateLocal(newAccount);
      }

      state = state._copyWith(
        localAccounts: state.localAccounts
            .where((a) => !identical(a, draftAccount))
            .toList(),
        editingAccount: null,
        status: state.status.success(
          const AppUserMessage.success(AppMessageKey.accountSaved),
        ),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state._copyWith(status: state.status.failure(e));
    }
  }

  Future<void> updateAccount({
    required Account account,
    required String name,
    required Color color,
    String? picture,
    required bool isLocalPicture,
  }) async {
    state = state._copyWith(status: state.status.loading());
    final accountsService = ref.read(accountsServiceProvider);
    try {
      String? currentFileName = account.picture;
      ImageProcessResult? imageToUpload;

      if (picture != account.pictureUrl) {
        if (account.picture != null) {
          await accountsService.deletePicture(account.picture!, account.id!);
          if (!ref.mounted) return;
          currentFileName = null;
        }

        imageToUpload = await AccountImageHelper.prepareImage(
          picture,
          isLocal: isLocalPicture,
        );
        if (!ref.mounted) return;
        if (imageToUpload != null) currentFileName = imageToUpload.fileName;
      }

      Account updatedAccount = account.copyWith(
        name: name,
        color: color,
        picture: currentFileName,
        pictureUrl: currentFileName == null ? null : account.pictureUrl,
      );

      updatedAccount = await ref
          .read(accountsSessionProvider.notifier)
          .update(updatedAccount);
      if (!ref.mounted) return;

      if (imageToUpload != null) {
        updatedAccount = await AccountImageHelper.uploadAndLinkImage(
          accountsService,
          updatedAccount,
          imageToUpload,
        );
        if (!ref.mounted) return;
        ref.read(accountsSessionProvider.notifier).updateLocal(updatedAccount);
      } else if (picture != null && !isLocalPicture) {
        updatedAccount = updatedAccount.copyWith(
          pictureUrl: account.pictureUrl,
        );
        ref.read(accountsSessionProvider.notifier).updateLocal(updatedAccount);
      }

      state = state._copyWith(
        editingAccount: null,
        status: state.status.success(
          const AppUserMessage.success(AppMessageKey.accountSaved),
        ),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state._copyWith(status: state.status.failure(e));
    }
  }

  void consumeMessage() {
    state = state._copyWith(status: state.status.consumeMessage());
  }
}
