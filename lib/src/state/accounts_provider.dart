import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'accounts_provider.g.dart';

class AccountsSessionState {
  const AccountsSessionState({required this.accounts, required this.hasLoaded});

  final List<Account> accounts;
  final bool hasLoaded;
}

@Riverpod(keepAlive: true)
class AccountsSession extends _$AccountsSession {
  @override
  AccountsSessionState build() =>
      const AccountsSessionState(accounts: [], hasLoaded: false);

  Future<void> load({bool forceRefresh = false}) async {
    final accounts = await ref
        .read(accountsServiceProvider)
        .loadAccounts(
          forceRefresh: forceRefresh,
          // RL-01 §3.2: a cache-first response renders immediately below; if
          // the service later revalidates against the server in the
          // background, push that result into the session too so listeners
          // (AccountSelection, Overview, ...) rebuild instead of staying
          // stuck on the cached snapshot.
          onRevalidated: setAccounts,
        );
    // Routed through setAccounts so the initial load is sorted the same way
    // as every later update instead of duplicating (and risking drifting
    // from) the sort order.
    setAccounts(accounts);
  }

  void setAccounts(List<Account> accounts) {
    final next = List<Account>.from(accounts)
      ..sort((a, b) => a.name.compareTo(b.name));
    state = AccountsSessionState(
      accounts: List.unmodifiable(next),
      hasLoaded: true,
    );
  }

  void updateLocal(Account account) {
    final next = [
      for (final item in state.accounts)
        if (item.id == account.id) account else item,
    ];
    if (!next.any((item) => item.id == account.id)) next.add(account);
    next.sort((a, b) => a.name.compareTo(b.name));
    state = AccountsSessionState(
      accounts: List.unmodifiable(next),
      hasLoaded: state.hasLoaded,
    );
  }

  Future<Account> create(Account account) async {
    final created = await ref
        .read(accountsServiceProvider)
        .createAccount(account);
    updateLocal(created);
    return created;
  }

  Future<Account> update(Account account) async {
    final updated = await ref
        .read(accountsServiceProvider)
        .updateAccount(account);
    updateLocal(updated);
    return updated;
  }

  Future<bool> delete(String accountId) async {
    final result = await ref
        .read(accountsServiceProvider)
        .deleteAccount(accountId);
    if (result) {
      state = AccountsSessionState(
        accounts: List.unmodifiable(
          state.accounts.where((a) => a.id != accountId),
        ),
        hasLoaded: state.hasLoaded,
      );
    }
    return result;
  }

  void clear() {
    state = const AccountsSessionState(accounts: [], hasLoaded: false);
    ref.read(accountsServiceProvider).clearLocalAccounts();
  }
}
