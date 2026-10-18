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

  // Separates session lifetime (invalidated by clear) from ordinary writes.
  // A cache/network result started for the previous user must never repopulate
  // this keepAlive session after sign-out.
  int _sessionRevision = 0;
  int _mutationRevision = 0;
  int _loadRevision = 0;

  Future<void> load({bool forceRefresh = false}) async {
    final sessionRevision = _sessionRevision;
    final mutationRevision = _mutationRevision;
    final loadRevision = ++_loadRevision;

    bool canApply() =>
        ref.mounted &&
        sessionRevision == _sessionRevision &&
        mutationRevision == _mutationRevision &&
        loadRevision == _loadRevision;

    final accounts = await ref
        .read(accountsServiceProvider)
        .loadAccounts(
          forceRefresh: forceRefresh,
          // Cache-first remote revalidation is accepted only while the session,
          // latest load and local mutation snapshot still match.
          onRevalidated: (remote) {
            if (canApply()) _applyAccounts(remote);
          },
        );
    if (!canApply()) return;
    _applyAccounts(accounts);
  }

  void setAccounts(List<Account> accounts) {
    _mutationRevision++;
    _applyAccounts(accounts);
  }

  void _applyAccounts(List<Account> accounts) {
    final next = List<Account>.from(_preservePictureUrls(accounts))
      ..sort((a, b) => a.name.compareTo(b.name));
    state = AccountsSessionState(
      accounts: List.unmodifiable(next),
      hasLoaded: true,
    );
  }

  /// Keeps a signed picture URL the session already resolved when the same
  /// account is applied again from a source that never carries it.
  ///
  /// Signed URLs are ephemeral and are deliberately not persisted, so a
  /// cache-first load (including one that hits the refresh throttle and so
  /// schedules no revalidation) returns accounts whose `pictureUrl` is null
  /// even though the avatar is already resolved in memory. Without this, such a
  /// snapshot would blank the avatar until the next un-throttled refresh. A
  /// modified picture (different [Account.picture]) is never carried over.
  List<Account> _preservePictureUrls(List<Account> accounts) {
    final known = <String, Account>{
      for (final account in state.accounts)
        if (account.id != null && account.pictureUrl != null)
          account.id!: account,
    };
    if (known.isEmpty) return accounts;
    return [
      for (final account in accounts)
        if (account.pictureUrl == null &&
            account.picture != null &&
            known[account.id]?.picture == account.picture)
          account.copyWith(pictureUrl: known[account.id]!.pictureUrl)
        else
          account,
    ];
  }

  void updateLocal(Account account) {
    _mutationRevision++;
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

  void _applyUpdatedAccount(Account account) {
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
    final sessionRevision = _sessionRevision;
    _mutationRevision++;
    final created = await ref
        .read(accountsServiceProvider)
        .createAccount(account);
    if (ref.mounted && sessionRevision == _sessionRevision) {
      _mutationRevision++;
      _applyUpdatedAccount(created);
    }
    return created;
  }

  Future<Account> update(Account account) async {
    final sessionRevision = _sessionRevision;
    _mutationRevision++;
    final updated = await ref
        .read(accountsServiceProvider)
        .updateAccount(account);
    if (ref.mounted && sessionRevision == _sessionRevision) {
      _mutationRevision++;
      _applyUpdatedAccount(updated);
    }
    return updated;
  }

  Future<bool> delete(String accountId) async {
    final sessionRevision = _sessionRevision;
    _mutationRevision++;
    final result = await ref
        .read(accountsServiceProvider)
        .deleteAccount(accountId);
    if (result && ref.mounted && sessionRevision == _sessionRevision) {
      _mutationRevision++;
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
    _sessionRevision++;
    _mutationRevision++;
    _loadRevision++;
    state = const AccountsSessionState(accounts: [], hasLoaded: false);
    ref.read(accountsServiceProvider).clearLocalAccounts();
  }
}
