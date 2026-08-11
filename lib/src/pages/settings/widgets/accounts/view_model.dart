import 'dart:io';
import 'dart:math';

import 'package:budgly/src/core/loading/progressive_loader.dart';
import 'package:budgly/src/core/stores/accounts.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts.dart';
import 'package:budgly/src/services/image.dart';
import 'package:budgly/src/shared/widgets/accounts/constants.dart';
import 'package:flutter/material.dart';

class _ImageProcessResult {
  final String fileName;
  final File file;
  _ImageProcessResult(this.fileName, this.file);
}

class AccountsViewModel extends BaseViewModel {
  final AccountsStore _accountsStore = AccountsStore.instance;
  final AccountsService _accountsService = AccountsService.instance;

  final List<Account> _localAccounts = [];
  Account? _editingAccount;

  final TextEditingController _nameController = TextEditingController();

  late final AccountEditingData _editingData = AccountEditingData(
    nameController: _nameController,
    color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
    picture: null,
  );

  List<Account> get accounts => [..._accountsStore.accounts, ..._localAccounts];
  bool get hasAccountsLoaded => _accountsStore.hasLoaded;
  bool get isCreatingAccount => _localAccounts.isNotEmpty;

  Account? get editingAccount => _editingAccount;
  AccountEditingData get editingData => _editingData;

  set editingAccount(Account? account) {
    _editingAccount = account;
    _nameController.text = account?.name ?? '';
    _editingData.color = account?.color ?? Colors.primaries[Random().nextInt(Colors.primaries.length)];
    // On privilégie l'URL distante si elle existe, sinon le nom du fichier local
    _editingData.picture = account?.pictureUrl ?? account?.picture;

    if (!isDisposed) notifyListeners();
  }

  Future<String?> pickImage(BuildContext context) async {
    final path = await ImageService.pickAndCropImage(context);
    if (path != null) _editingData.picture = path;
    return path;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> loadAccounts({bool needLoading = true}) async {
    if (needLoading) setLoading(true);

    await ProgressiveLoader.loadEssentialOnly(
      essentialData: () async {
        await _accountsStore.loadAccounts();
      },
      secondaryData: () async {
        for (final account in _accountsStore.accounts) {
          if (account.picture != null && account.id != null) {
            try {
              await refreshPictureUrl(account);
            } catch (e) {
              // Continue even if one fails
            }
          }
        }
      },
      onProgress: (progress) {},
    );

    setLoading(false);
    if (!isDisposed) notifyListeners();
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
    if (!isDisposed) notifyListeners();
  }

  Future<void> removeAccount(Account account) async {
    if (account.id != null) {
      if (account.picture != null) {
        await _accountsService.deletePicture(account.picture!, account.id!);
      }
      await _accountsService.deleteAccount(account.id!);
      _accountsStore.removeAccount(account.id!);
      _accountsService.invalidateCache();
    } else {
      _localAccounts.removeWhere((a) => identical(a, account));
    }
    if (!isDisposed) notifyListeners();
  }

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
        _accountsStore.updateAccount(updatedAccount);
        _accountsService.invalidateCache();
      } catch (e) {
        // Ignore errors when refreshing picture URL
      }
    }
  }

  Future<_ImageProcessResult?> _prepareImage() async {
    if (_editingData.picture == null || !_editingData.isLocalPicture) return null;

    final fileName = "${DateTime.now().millisecondsSinceEpoch}_${_editingData.picture!.split('/').last}";
    final file = await ImageService.persistFile(_editingData.picture!, fileName);

    return file != null ? _ImageProcessResult(fileName, file) : null;
  }

  Future<Account> _uploadAndLinkImage(Account account, _ImageProcessResult image) async {
    try {
      await _accountsService.uploadPicture(image.file, account.id!, image.fileName);
      final url = await _accountsService.getSignedUrl(image.fileName, account.id!);
      return account.copyWith(pictureUrl: url);
    } catch (_) {
      return account; 
    }
  }

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
      }

      _localAccounts.removeWhere((a) => identical(a, account));
      _accountsStore.addAccount(newAccount);
      _editingAccount = null;
    } finally {
      setLoading(false);
      _accountsService.invalidateCache();
    }
  }

  Future<void> updateAccount(Account account) async {
    setLoading(true);
    try {
      String? currentFileName = account.picture;
      _ImageProcessResult? imageToUpload;

      if (_editingData.picture != account.pictureUrl && _editingData.picture != account.picture) {
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
      );

      updatedAccount = await _accountsService.updateAccount(updatedAccount);

      if (imageToUpload != null) {
        updatedAccount = await _uploadAndLinkImage(updatedAccount, imageToUpload);
      } else if (_editingData.picture != null && !_editingData.isLocalPicture) {
        updatedAccount = updatedAccount.copyWith(pictureUrl: account.pictureUrl);
      }

      _accountsStore.updateAccount(updatedAccount);
      _editingAccount = null;
    } finally {
      setLoading(false);
      _accountsService.invalidateCache();
    }
  }
}