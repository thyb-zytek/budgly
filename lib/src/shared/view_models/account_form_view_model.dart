import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/account/account_editing_data.dart';
import 'package:flutter/material.dart';

abstract class AccountFormViewModel implements ChangeNotifier {
  AccountEditingData get editingData;
  Future<String?> pickImage(BuildContext context);
  Future<void> createAccount(Account account);
  Future<void> updateAccount(Account account);
  Future<void> removeAccount(Account account);
  void cancelEdit();
}
