import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'accounts_provider.g.dart';

/// Riverpod-observable mirror of [AccountsStore] (issue M2).
///
/// [AccountsStore] itself is not rewritten here: its only consumer today is
/// `AccountsService` (`lib/src/services/accounts/accounts_service.dart`), a
/// plain `.instance` singleton not yet migrated (issue M3). This notifier
/// listens to the store and republishes an immutable snapshot, so a future
/// migrated ViewModel (issue M4) can `ref.watch` account data without
/// waiting for the service layer to move first — same pattern as
/// `ProfileSession` (issue M1b).
class AccountsSessionState {
  const AccountsSessionState({
    required this.accounts,
    required this.hasLoaded,
  });

  final List<Account> accounts;
  final bool hasLoaded;
}

@Riverpod(keepAlive: true)
class AccountsSession extends _$AccountsSession {
  AccountsStore get _store => AccountsStore.instance;

  @override
  AccountsSessionState build() {
    _store.addListener(_onStoreChanged);
    ref.onDispose(() => _store.removeListener(_onStoreChanged));
    return _readState();
  }

  AccountsSessionState _readState() => AccountsSessionState(
        accounts: _store.accounts,
        hasLoaded: _store.hasLoaded,
      );

  void _onStoreChanged() {
    state = _readState();
  }
}
