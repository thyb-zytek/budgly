import 'dart:io';
import 'dart:math';

import 'package:budgly/src/core/loading/progressive_loader.dart';
import 'package:budgly/src/core/stores/accounts_store.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts.dart';
import 'package:budgly/src/services/image.dart';
import 'package:budgly/src/shared/widgets/accounts/constants.dart';
import 'package:flutter/material.dart';

class AccountsViewModel extends BaseViewModel {
  final AccountsStore _accountsStore = AccountsStore.instance;
  final AccountsService _accountsService = AccountsService.instance;

  final List<Account> _localAccounts = [];
  Account? _editingAccount;

  final TextEditingController _nameController = TextEditingController();

  late Color _selectedColor;
  String? _picture;
  bool _isLocalPicture = true;

  List<Account> get accounts => [..._accountsStore.accounts, ..._localAccounts];
  bool get hasAccountsLoaded => _accountsStore.hasLoaded;
  bool get isCreatingAccount => _localAccounts.isNotEmpty;

  Account? get editingAccount => _editingAccount;

  AccountEditingData get editingData => AccountEditingData(
    nameController: _nameController,
    color: _selectedColor,
    picture: _picture,
    isLocalPicture: _isLocalPicture,
  );

  set editingAccount(Account? account) {
    _editingAccount = account;
    _nameController.text = account?.name ?? '';
    _selectedColor =
        account?.color ??
        Colors.primaries[Random().nextInt(Colors.primaries.length)];

    if (account?.pictureUrl != null) {
      _picture = account!.pictureUrl;
      _isLocalPicture = false;
    } else {
      _picture = account?.picture;
      _isLocalPicture = _picture == null || !_picture!.startsWith('http');
    }

    if (!isDisposed) {
      notifyListeners();
    }
  }

  set color(Color color) {
    _selectedColor = color;
    if (!isDisposed) {
      notifyListeners();
    }
  }

  set picture(String? picture) {
    _picture = picture;
    _isLocalPicture = true;
    if (!isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void removePicture() {
    _picture = null;
    _isLocalPicture = true;
    if (!isDisposed) {
      notifyListeners();
    }
  }

  Future<void> loadAccounts({bool needLoading = true}) async {
    if (needLoading) {
      setLoading(true);
    }

    await ProgressiveLoader.loadEssentialOnly(
      essentialData: () async {
        await _accountsStore.loadAccounts();
      },
      secondaryData: () async {
        // Load signed URLs for accounts in background
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
      onProgress: (progress) {
        // Optional progress tracking
      },
    );

    setLoading(false);
    if (!isDisposed) {
      notifyListeners();
    }
  }

  Future<void> addAccount() async {
    // Only one account can be created at a time.
    if (_localAccounts.isNotEmpty) return;

    setLoading(true);

    final account = Account(
      id: null,
      name: '',
      picture: null,
      pictureUrl: null,
      color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
    );

    _selectedColor = account.color!;
    _nameController.text = '';
    _picture = null;
    _isLocalPicture = true;

    _localAccounts.add(account);

    setLoading(false);
    if (!isDisposed) {
      notifyListeners();
    }
  }

  Future<void> removeAccount(Account account) async {
    if (account.id != null) {
      // This is an existing account - actually delete it.
      if (account.picture != null) {
        await _accountsService.deletePicture(account.picture!, account.id!);
      }
      await _accountsService.deleteAccount(account.id!);

      // _accountsStore.removeAccount() already updates the store's local
      // state correctly and notifies its own listeners - do NOT follow it
      // with _accountsStore.invalidateCache(): that would clear the store
      // and require a full reload for something we already fixed locally.
      // We only bust the service-level HTTP cache so a future full
      // loadAccounts() doesn't return stale data.
      _accountsStore.removeAccount(account.id!);
      _accountsService.invalidateCache();
    } else {
      // This is a local temporary account - just remove from local list.
      // Use identity comparison: Account's == likely compares by id, and
      // every not-yet-saved account shares id == null, so a value-based
      // match would wipe out every local account instead of just this one.
      _localAccounts.removeWhere((a) => identical(a, account));
    }
    if (!isDisposed) {
      notifyListeners();
    }
  }

  void cancelEdit() {
    // Cancel editing without deleting the account, and without touching
    // any other account currently being created locally.
    _editingAccount = null;
    _nameController.clear();
    _picture = null;
    _isLocalPicture = true;
    if (!isDisposed) {
      notifyListeners();
    }
  }

  Future<String?> pickImage(BuildContext context) async {
    final path = await ImageService.pickAndCropImage(context);
    if (path != null) picture = path;
    return path;
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
        // Handle error silently
      }
    }
  }

  Future<void> createAccount(Account account) async {
    setLoading(true);

    String? fileName;
    File? persisted;
    Account? createdAccount;

    if (_picture != null) {
      fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${_picture!.split('/').last}";
      persisted = await ImageService.persistFile(_picture!, fileName);
    }

    try {
      final newAccount = account.copyWith(
        name: _nameController.text,
        color: _selectedColor,
        picture: fileName,
      );
      createdAccount = await _accountsService.createAccount(newAccount);
    } catch (e) {
      setLoading(false);
      return;
    }

    if (persisted != null && fileName != null) {
      try {
        await _accountsService.uploadPicture(
          persisted,
          createdAccount.id!,
          fileName,
        );
        final pictureUrl = await _accountsService.getSignedUrl(
          fileName,
          createdAccount.id!,
        );
        createdAccount = createdAccount.copyWith(pictureUrl: pictureUrl);
        _isLocalPicture = pictureUrl != null;
      } catch (_) {}
    }

    // Remove from local accounts and add to store. The store is already
    // correct at this point - only the service-level cache needs busting.
    _localAccounts.removeWhere((a) => identical(a, account));
    _accountsStore.addAccount(createdAccount!);
    _editingAccount = null;
    setLoading(false);
    _accountsService.invalidateCache();
  }

  Future<void> updateAccount(Account account) async {
    setLoading(true);

    String? fileName = account.picture;
    File? persisted;
    Account? updatedAccount;
    String? pictureUrl;

    try {
      if (_picture != null && _isLocalPicture) {
        if (account.picture != null) {
          await _accountsService.deletePicture(
            account.picture!,
            account.id!,
          );
          fileName = null;
        }

        fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${_picture!.split('/').last}";
        persisted = await ImageService.persistFile(_picture!, fileName);

        await _accountsService.uploadPicture(persisted!, account.id!, fileName);
        pictureUrl = await _accountsService.getSignedUrl(fileName, account.id!);
        _isLocalPicture = pictureUrl != null;
      } else if (_picture == null && account.picture != null) {
        await _accountsService.deletePicture(
          account.picture!,
          account.id!,
        );
        fileName = null;
      }

      account = account.copyWith(
        name: _nameController.text,
        color: _selectedColor,
        picture: fileName,
      );

      updatedAccount = await _accountsService.updateAccount(account);

      if (pictureUrl != null) {
        updatedAccount = updatedAccount.copyWith(pictureUrl: pictureUrl);
      } else if (account.pictureUrl != null && !_isLocalPicture) {
        updatedAccount = updatedAccount.copyWith(pictureUrl: account.pictureUrl);
      }
    } catch (e) {
      setLoading(false);
      return;
    }

    // The store is already correct via updateAccount() below - only the
    // service-level cache needs busting.
    _accountsStore.updateAccount(updatedAccount);
    _editingAccount = null;
    setLoading(false);
    _accountsService.invalidateCache();
  }
}