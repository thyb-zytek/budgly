import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AccountsStore store;

  setUp(() {
    store = AccountsStore.instance;
    store.clearLocalAccounts();
  });

  Account buildAccount({
    String id = 'acc-1',
    String name = 'Checking',
    String? pictureUrl,
  }) {
    return Account(
      id: id,
      userId: 'user-1',
      name: name,
      color: Colors.blue,
      pictureUrl: pictureUrl,
    );
  }

  test('does not notify when replacing accounts with identical data', () {
    store.setAccounts([buildAccount()]);
    var notifications = 0;
    store.addListener(() => notifications++);

    store.setAccounts([buildAccount()]);

    expect(notifications, 0);
  });

  test('notifies when an account actually changes', () {
    store.setAccounts([buildAccount()]);
    var notifications = 0;
    store.addListener(() => notifications++);

    store.setAccounts([buildAccount(name: 'Savings')]);

    expect(notifications, 1);
  });

  test('does not notify when removing an unknown account', () {
    store.setAccounts([buildAccount()]);
    var notifications = 0;
    store.addListener(() => notifications++);

    store.removeAccount('missing');

    expect(notifications, 0);
  });
}
