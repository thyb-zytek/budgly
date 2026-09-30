import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_selection_provider.g.dart';

class AccountSelectionState {
  const AccountSelectionState({required this.accounts, this.selectedAccount});

  final List<Account> accounts;
  final Account? selectedAccount;

  AccountSelectionState copyWith({
    List<Account>? accounts,
    Account? selectedAccount,
    bool clearSelection = false,
  }) => AccountSelectionState(
    accounts: accounts ?? this.accounts,
    selectedAccount: clearSelection
        ? null
        : selectedAccount ?? this.selectedAccount,
  );
}

@Riverpod(keepAlive: true)
class AccountSelection extends _$AccountSelection {
  @override
  AccountSelectionState build() {
    ref.listen(accountsSessionProvider, (_, next) => _sync(next.accounts));
    final accounts = ref.read(accountsSessionProvider).accounts;
    return AccountSelectionState(
      accounts: accounts,
      selectedAccount: accounts.isEmpty ? null : accounts.first,
    );
  }

  Future<void> load({bool forceRefresh = false}) async {
    await ref
        .read(accountsSessionProvider.notifier)
        .load(forceRefresh: forceRefresh);
    _sync(ref.read(accountsSessionProvider).accounts);
  }

  void select(Account? account) {
    if (account?.id == state.selectedAccount?.id) return;
    if (account == null) {
      state = state.copyWith(clearSelection: true);
      return;
    }
    state = state.copyWith(selectedAccount: account);
  }

  void _sync(List<Account> accounts) {
    final currentId = state.selectedAccount?.id;
    final selected = accounts.cast<Account?>().firstWhere(
      (account) => account?.id == currentId,
      orElse: () => accounts.isEmpty ? null : accounts.first,
    );
    state = AccountSelectionState(
      accounts: List.unmodifiable(accounts),
      selectedAccount: selected,
    );
  }
}
