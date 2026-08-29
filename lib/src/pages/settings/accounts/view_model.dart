import 'dart:async';
import 'dart:math';

import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/image/image_service.dart';
import 'package:budgly/src/models/account/account_editing_data.dart';
import 'package:budgly/src/services/image/account_image_helper.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/shared/domain/view_models/account_form_view_model.dart';
import 'package:flutter/material.dart';

class AccountsViewModel extends BaseViewModel implements AccountFormViewModel {
  final AccountsService _accountsService = AccountsService.instance;

  final List<Account> _localAccounts = [];
  Account? _editingAccount;

  final TextEditingController _nameController = TextEditingController();

  late final AccountEditingData _editingData = AccountEditingData(
    nameController: _nameController,
    color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
    picture: null,
  );

  List<Account> get accounts => [..._accountsService.accounts, ..._localAccounts];
  bool get hasAccountsLoaded => _accountsService.hasLoaded;
  bool get isCreatingAccount => _localAccounts.isNotEmpty;

  Account? get editingAccount => _editingAccount;
  @override
  AccountEditingData get editingData => _editingData;

  set editingAccount(Account? account) {
    _editingAccount = account;
    _nameController.text = account?.name ?? '';
    _editingData.color = account?.color ?? Colors.primaries[Random().nextInt(Colors.primaries.length)];
    _editingData.picture = account?.pictureUrl;
    _editingData.isLocalPicture = account?.pictureUrl == null;

    if (!isDisposed) notifyListeners();
  }

  @override
  Future<String?> pickImage(BuildContext context) async {
    final path = await ImageService.pickAndCropImage(context);
    if (path != null) {
      _editingData.picture = path;
      _editingData.isLocalPicture = true;
    }
    return path;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> loadAccounts() async {
    setLoading(true);
    try {
      await _accountsService.loadAccounts();
      // Signed URLs are presentation data. They must never delay the account
      // list, especially when the account list itself came from local cache.
      unawaited(Future.wait(
        _accountsService.accounts
            .where((account) => account.picture != null && account.id != null)
            .map(refreshPictureUrl),
      ));
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
    } finally {
      setLoading(false);
    }
  }

  Future<void> addAccount() async {
    if (_localAccounts.isNotEmpty) return;

    setLoading(true);

    final account = Account(
      id: null,
      name: '',
      picture: null,
      pictureUrl: null,
      color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
    );

    _editingData.color = account.color!;
    _nameController.text = '';
    _editingData.picture = null;

    _localAccounts.add(account);

    setLoading(false);
  }

  Future<void> _cleanupDeletedAccount(String accountId) async {
    try {
      CategoriesService.instance.invalidateAccountCache(accountId);
      await Future.wait([
        ExpensesService.instance.deleteByAccountId(accountId),
        AccountBudgetsService.instance.deleteByAccountId(accountId),
        _accountsService.deleteAccountFolder(accountId),
      ]);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clean up deleted account', e, stackTrace);
    }
  }

  @override
  Future<void> removeAccount(Account account) async {
    if (account.id == null) {
      _localAccounts.removeWhere((a) => identical(a, account));
      if (!isDisposed) notifyListeners();
      return;
    }

    setLoading(true);
    try {
      final accountId = account.id!;
      await _accountsService.deleteAccount(accountId);
      setSuccessMessage(const AppUserMessage.success(AppMessageKey.accountDeleted));

      // Account removal is complete from the user's point of view once the
      // local state and Supabase queue are updated. Firestore/storage cleanup
      // is best-effort and can finish offline or on the next sync.
      unawaited(_cleanupDeletedAccount(accountId));
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
    } finally {
      setLoading(false);
    }
  }

  @override
  void cancelEdit() {
    _editingAccount = null;
    _nameController.clear();
    _editingData.picture = null;
    if (!isDisposed) notifyListeners();
  }

  Future<void> refreshPictureUrl(Account account) async {
    if (account.picture != null && account.id != null) {
      try {
        final pictureUrl = await _accountsService.getSignedUrl(
          account.picture!,
          account.id!,
        );
        final updatedAccount = account.copyWith(pictureUrl: pictureUrl);
        _accountsService.updateLocalAccount(updatedAccount);
      } catch (e, st) {
        AppLogger.error('Failed to refresh picture URL', e, st);
      }
    }
  }

  Future<ImageProcessResult?> _prepareImage() async {
    return AccountImageHelper.prepareImage(
      _editingData.picture,
      isLocal: _editingData.isLocalPicture,
    );
  }

  Future<Account> _uploadAndLinkImage(Account account, ImageProcessResult image) async {
    return AccountImageHelper.uploadAndLinkImage(_accountsService, account, image);
  }

  @override
  Future<void> createAccount(Account account) async {
    setLoading(true);
    try {
      final imageToUpload = await _prepareImage();

      Account newAccount = account.copyWith(
        name: _nameController.text,
        color: _editingData.color,
        picture: imageToUpload?.fileName,
      );

      newAccount = await _accountsService.createAccount(newAccount);

      if (imageToUpload != null) {
        newAccount = await _uploadAndLinkImage(newAccount, imageToUpload);
        _accountsService.updateLocalAccount(newAccount);
      }

      _localAccounts.removeWhere((a) => identical(a, account));
      _editingAccount = null;
      setSuccessMessage(const AppUserMessage.success(AppMessageKey.accountSaved));
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
    } finally {
      setLoading(false);
    }
  }

  @override
  Future<void> updateAccount(Account account) async {
    setLoading(true);
    try {
      String? currentFileName = account.picture;
      ImageProcessResult? imageToUpload;

      if (_editingData.picture != account.pictureUrl) {
        if (account.picture != null) {
          await _accountsService.deletePicture(account.picture!, account.id!);
          currentFileName = null;
        }

        imageToUpload = await _prepareImage();
        if (imageToUpload != null) currentFileName = imageToUpload.fileName;
      }

      Account updatedAccount = account.copyWith(
        name: _nameController.text,
        color: _editingData.color,
        picture: currentFileName,
        pictureUrl: currentFileName == null ? null : account.pictureUrl,
      );

      updatedAccount = await _accountsService.updateAccount(updatedAccount);

      if (imageToUpload != null) {
        updatedAccount = await _uploadAndLinkImage(updatedAccount, imageToUpload);
        _accountsService.updateLocalAccount(updatedAccount);
      } else if (_editingData.picture != null && !_editingData.isLocalPicture) {
        updatedAccount = updatedAccount.copyWith(pictureUrl: account.pictureUrl);
        _accountsService.updateLocalAccount(updatedAccount);
      }

      _editingAccount = null;
      setSuccessMessage(const AppUserMessage.success(AppMessageKey.accountSaved));
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
    } finally {
      setLoading(false);
    }
  }
}
