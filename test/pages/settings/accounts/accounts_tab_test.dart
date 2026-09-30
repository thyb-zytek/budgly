import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/settings/accounts/tab.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/supabase/accounts.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/builders.dart';
import '../../../helpers.dart';

class FakeAccountSupabase extends AccountSupabase {
  FakeAccountSupabase(this.result);
  final List<Account> result;

  @override
  Future<List<Account>> listByUserId(String userId) async => result;
}

AccountsService accountsService(List<Account> accounts) {
  // Local sync pair on purpose. The shared `testSyncQueue` is reset by the
  // global setUp in `flutter_test_config.dart`, which awaits it in the real
  // async zone. `SyncQueue` serializes through an internal lock future
  // (sync_queue.dart:109), so that reset leaves the lock chained to a real
  // microtask the fake-async widget zone can never flush — reading the shared
  // queue from here would deadlock the tab's initial load behind its loading
  // spinner. A fresh instance is only ever used in this zone, so its lock
  // always settles. This test asserts nothing about sync behaviour.
  final queue = SyncQueue();
  return AccountsService(
    analytics: AnalyticsService(),
    auth: MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'test@budgly.app'),
    ),
    accountSupabase: FakeAccountSupabase(accounts),
    syncManager: SyncManager(queue: queue, analytics: AnalyticsService()),
    syncQueue: queue,
  );
}

Future<void> pumpAccountsTab(
  WidgetTester tester,
  List<Account> accounts,
) async {
  final service = accountsService(accounts);
  final container = ProviderContainer(
    overrides: [accountsServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  await pumpApp(
    tester,
    UncontrolledProviderScope(container: container, child: const AccountsTab()),
  );
}

void main() {
  testWidgets('renders the list of accounts with their names', (tester) async {
    await pumpAccountsTab(tester, [
      Fixtures.account(id: 'a1', name: 'Compte courant'),
      Fixtures.account(id: 'a2', name: 'Épargne'),
    ]);

    expect(find.text('Compte courant'), findsOneWidget);
    expect(find.text('Épargne'), findsOneWidget);
  });

  testWidgets('shows the empty message when no account exists', (tester) async {
    await pumpAccountsTab(tester, const []);

    expect(find.textContaining('Aucun compte trouvé'), findsOneWidget);
  });

  testWidgets('always offers the add-account entry point', (tester) async {
    await pumpAccountsTab(tester, const []);

    expect(find.text('Nouveau compte'), findsOneWidget);
  });

  testWidgets('renders accounts from the Riverpod session', (tester) async {
    await pumpAccountsTab(tester, [
      Fixtures.account(id: 'a1', name: 'Compte courant'),
    ]);

    expect(find.text('Compte courant'), findsOneWidget);
  });

  testWidgets('tapping "add account" reveals an empty account form', (
    tester,
  ) async {
    await pumpAccountsTab(tester, const []);
    await tester.tap(find.text('Nouveau compte'));
    await tester.pump();

    // A draft with no id renders as an AccountForm (name field), not an
    // AccountView — the same way a persisted account without a name never
    // would.
    expect(find.byType(TextFormField), findsWidgets);
  });
}
