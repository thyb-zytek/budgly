import 'dart:io';
import 'dart:math';

import 'package:app/src/models/account/account.dart';
import 'package:app/src/services/accounts.dart';
import 'package:app/src/services/image.dart';
import 'package:app/src/shared/widgets/accounts/constants.dart';
import 'package:flutter/material.dart';

class AccountsViewModel extends ChangeNotifier {
  final AccountsService _accountsService = AccountsService.instance;

  final List<Account> _accounts = [];
  Account? _editingAccount;

  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  late Color _selectedColor;
  String? _picture;
  bool _isLocalPicture = true;

  bool get isLoading => _isLoading;
  List<Account> get accounts => List.unmodifiable(_accounts);

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

    notifyListeners();
  }

  set color(Color color) {
    _selectedColor = color;
    notifyListeners();
  }

  set picture(String? picture) {
    _picture = picture;
    _isLocalPicture = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void removePicture() {
    _picture = null;
    _isLocalPicture = true;
    notifyListeners();
  }

  Future<void> loadAccounts() async {
    _isLoading = true;
    notifyListeners();

    _accounts.clear();
    _accounts.addAll(await _accountsService.listAccountsWithSignedUrls());

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addAccount() async {
    _isLoading = true;
    notifyListeners();

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

    _accounts.add(account);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> removeAccount(Account account) async {
    if (account.id != null) {
      if (account.picture != null) {
        await _accountsService.deletePicture(account.picture!, account.id!);
      }
      await _accountsService.deleteAccount(account.id!);
    }
    _accounts.remove(account);
    _accountsService.invalidateCache();
    notifyListeners();
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
        final index = _accounts.indexOf(account);
        if (index != -1) {
          _accounts[index] = account.copyWith(pictureUrl: pictureUrl);
          _accountsService.invalidateCache();
          notifyListeners();
        }
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> createAccount(Account account) async {
    _isLoading = true;
    notifyListeners();

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
      _isLoading = false;
      notifyListeners();
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

    _accounts.remove(account);
    _accounts.add(createdAccount!);
    _editingAccount = null;
    _isLoading = false;
    _accountsService.invalidateCache();
    notifyListeners();
  }

  Future<void> updateAccount(Account account) async {
    _isLoading = true;
    notifyListeners();

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
      _isLoading = false;
      notifyListeners();
      return;
    }

    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      _accounts[index] = updatedAccount;
    }

    _editingAccount = null;
    _isLoading = false;
    _accountsService.invalidateCache();
    notifyListeners();
  }
}
