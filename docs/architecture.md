# Budgly — architecture

> Contrats techniques courants (propriété de l'état, injection de dépendances, dates, offline-first, démarrage). L'état des validations est résumé dans [`STATUS.md`](STATUS.md).

## Goal

Budgly uses a pragmatic Flutter/Riverpod architecture. The objective is clear ownership and reliable offline behaviour, not a full Clean Architecture stack.

## Ownership

```text
UI / pages
    ↓
Riverpod Notifier (feature state / ViewModel)
    ↓
Service (business orchestration)
    ├── LocalCache / technical cache
    ├── Firestore / Supabase
    └── SyncQueue / SyncManager where required
```

### UI

Widgets render provider state and own transient Flutter objects such as `TextEditingController`, `FocusNode` and `PageController`. Widgets do not access Firestore or Supabase directly.

### Riverpod Notifiers

Notifiers own reactive in-memory state consumed by the UI. Shared application state lives in `lib/src/state/` (`AccountsSession`, `CategoriesSession`, `ExpensesSession`, `AccountBudgetsSession`, `ProfileSession`). Page-specific Notifiers live next to their page.

A Notifier is the ViewModel for its feature. Do not add another Controller/ViewModel layer around it.

### Services

Services own business operations, persistence, remote calls and synchronization. Dependencies are constructor-injected through Riverpod providers. Services may keep narrowly scoped technical caches for request deduplication, throttling, optimistic reconciliation or signed URL lifetime; these caches must not become a second reactive source of truth.

### Persistence

- `LocalCache`: durable SharedPreferences-backed state for Supabase-owned entities.
- Firestore persistence: native offline persistence for expenses and budgets.
- `SyncQueue`: durable pending Supabase mutations.
- `SyncManager`: lifecycle-bound coordinator that replays the queue. It is explicitly constructed through Riverpod, owns no UI state, and exposes its status as a stream consumed by `SyncStatusNotifier`. It has no production singleton compatibility API.
- Firebase Auth is the authentication source of truth. `AuthService.authStateChanges` is observed by `ProfileSession` for session isolation and by `AppRouter` for redirect refresh; there is no separate mutable auth `ChangeNotifier` bridge.

## Dependency injection

Riverpod is the composition boundary. Providers construct services and pass their dependencies explicitly.

Rules:

- no `SomeService.instance` access in production domain code;
- process-wide resources are allowed only when their lifecycle is genuinely process-scoped (for example the analytics client or Firebase Auth stream), and they remain exposed through Riverpod;
- tests instantiate explicit services/coordinators instead of relying on production singletons;
- constructors must not silently reach into unrelated global state;
- backend SDK clients (Firebase Auth, Firestore, Supabase, Google Sign-In) are composed in `lib/src/core/dependencies/backend_clients_provider.dart` and injected explicitly into services and adapters. Constructor fallbacks to the global instances (`?? FirebaseAuth.instance`, `?? AccountSupabase()`, …) remain for direct tests and isolated use only; production providers always pass every dependency.

## Shared state

The shared reactive source of truth is Riverpod state:

| Domain | Reactive state | Durable/remote ownership |
|---|---|---|
| Profile | `ProfileSession` | `LocalCache` + Supabase |
| Accounts | `AccountsSession` | `LocalCache` + Supabase |
| Categories | `CategoriesSession` | `LocalCache` + Supabase |
| Expenses | `ExpensesSession` | Firestore + technical service cache |
| Budgets | `AccountBudgetsSession` | Firestore + technical service cache |

A widget rebuild must not trigger a duplicate request. Services use in-flight registries/throttling and sessions retain already-loaded application state.

### Session isolation and stale async results

- Firebase `authStateChanges` is the identity source. `ProfileSession` tracks the UID observed from that stream independently of `state.currentUser` (which is not published until accounts/categories are preloaded), and resets the profile plus the Accounts/Categories/Expenses/Budgets sessions on an external sign-out or an identity change. Initial auth restoration is not treated as an identity switch.
- `_sessionRevision` (profile) and per-account revisions (`ExpensesSession`) are concurrency guards: a load, revalidation or mutation result that started before a `clear()`/invalidation, or before a newer local change, is not applied. Keep these guards until equivalent guarantees are proven by tests.
- `ProfileService` keys an in-flight profile load by Firebase UID (a login for user B never awaits user A's request) and keeps a per-user mutation revision: a remote snapshot that began before a local profile mutation is rejected, the pending-mutation check is repeated immediately before the cache write, and cache writes are serialized.

## Dates and periods

Business dates are calendar dates; time-of-day has no business meaning.

`CalendarDateRange` defines the shared range contract as:

```text
[start, endExclusive)
```

The start is included and the end is excluded. Firestore queries therefore use `>= start` and `< endExclusive`. Recurring expenses keep their user-facing `endDate` as an inclusive calendar date, while internal range calculations use the following day as the exclusive boundary.

### Storage of calendar dates

`debitDate` and `endDate` are persisted as a Firestore `Timestamp` at **UTC midnight** of the calendar day (`lib/src/models/expense/stored_calendar_date.dart`: `calendarDateToTimestamp`, `calendarDateFromTimestamp`, `calendarDateQueryStart`, `calendarDateQueryEndExclusive`). The stored value therefore does not depend on the author's time zone.

- **Legacy values** were written as local midnight of the author. They are decoded with a heuristic: a UTC time of day `>= 12:00` means the next calendar day.
- **Queries** are widened by 14 h at each bound and post-filtered on the decoded calendar date, so legacy and new values both fall in the right period.
- **Known limits:** the heuristic is ambiguous for old writes made at UTC+10…+14 or UTC-10…-12, and data written abroad before this change may remain shifted by one day. To verify on real data.
- **Arithmetic** on calendar days never uses `Duration(days: 1)` (24 elapsed hours is not one day across a DST change): use `DateTime(y, m, d ± 1)`. Regression tests: `test/regression/calendar_arithmetic_dst_test.dart`, `stored_calendar_date_test.dart`.

## Expenses and recurrence

`ExpenseOccurrenceCalculator` is the single projection engine for recurring occurrences. It accepts `CalendarDateRange`, jumps directly to the first relevant occurrence and applies keyed occurrence exceptions without creating a separate Firestore collection.

Undebited historical occurrences are handled by `UndebitedExpensesService`. The initial Firestore scan is bounded to expenses whose source series begins before the current period; occurrence expansion then determines which historical occurrences actually require action. The displayed set is projected by `UndebitedExpenses` from the shared expenses session, so on first arrival the account is force-loaded: the session must reflect the whole account history before the current period, not only the periods the Overview already cached, otherwise older undebited occurrences are silently dropped.

## Offline-first contract

Local optimistic changes remain visible immediately and survive refreshes, retries and process crashes until the remote mutation is confirmed.

For Supabase-backed mutations (accounts, categories, profile), the Riverpod session calls the service, which does:

```text
mutation
  ↓
SyncQueue.enqueue        durable intent, the source of truth; a failure is rethrown to the caller
  ↓
LocalCache (mirror)      best-effort, serialized read-modify-write; a failure is only logged
  ↓
Riverpod session update  once the service call returns
  ·
  · (asynchronously, flush requested after enqueue)
SyncManager → Supabase
```

The queue entry is written **before** the cache: a crash between the two loses nothing, and a queue failure is reported instead of leaving an optimistic change that would silently vanish. `LocalCache` is a single shared instance (injected by provider) whose read-modify-write operations are serialized; an undecodable entry is quarantined and read as absent (the app goes back to the server) rather than as an empty list, and every key embeds a schema version so an entry written under an older schema is invisible rather than mis-decoded.

`SyncManager.flush` runs a single drain loop with a final pass (an operation enqueued during a pass is not left waiting for the next periodic cycle) and never runs two passes at once.

Sync ordering is preserved per entity. A failed account blocks only dependent categories/expenses; unrelated entities continue to synchronize. Failed operations are retried with backoff (scheduled to wake at the earliest retry time, not just on the periodic timer) and are never silently dropped.

Queue semantics worth knowing before touching `SyncQueue` / `SyncManager`:

- **Coalescing:** partial `update` patches (profile, pending avatar) are merged rather than replaced. A `create` followed by a `delete` is deliberately kept as **two operations**: the create may already have reached the server before a crash or an ambiguous response, so cancelling it locally could leave an orphaned remote entity.
- **Revision guard:** `PendingSync.revision` (absent from the JSON when 0, so the format stays backward compatible). `enqueue` gives a revision strictly greater than any operation it replaces (same id or same entity); `SyncQueue.applyBatch(replayedRevisions:)` ignores the removal/failure of an operation whose revision changed while it was being replayed. A mutation recorded during its own replay is therefore never lost.
- **Corruption:** an unreadable queue blob is quarantined and decoded item by item instead of being overwritten.
- **Legacy ownerless entries** (written before `owner_user_id` existed) stay untouched while signed out. The first authenticated queue read assigns them to the current user and persists that owner; later users cannot claim or replay them. This is an explicit product decision: the first authenticated user on the device is assumed to own the legacy queue. A failure the server will keep rejecting (see `SyncError` classification in `sync_error_classifier.dart`) is flagged `permanent`: it stops being replayed by background triggers but stays visible and durable, and an explicit user retry (`flush(retryPermanent: true)`) gives it another chance.

For Firestore-backed expenses and budgets, native Firestore offline persistence provides the durable write queue; Budgly does not introduce a second application queue for those writes. Expense/budget writes are not awaited by the caller: the write's Future only completes on a server acknowledgement, which never happens offline. A rejection is reported asynchronously (`ExpensesService.rejectedWrites`) and reconciled by reloading the affected account.

A forced refresh of an account's expenses (`listExpensesForAccount(forceRefresh: true)`) never returns an empty list when the server read fails: it reads the local Firestore cache, completed with the period cache and the pending mutations.

Reads follow the cache-first rule: render from the local state, revalidate in the background, and apply a revalidation result only if it still belongs to the current session (see below). The rules for authentication, onboarding and cache revalidation are specified in [`rules/RL-01.md`](rules/RL-01.md).

Deleting an account or a category enqueues a durable `cleanup` operation (`DeletionCleanupService`) once the Supabase delete is server-confirmed. It purges the Firestore documents this device may not have cached (server-side query) and the storage folder, and is retried like any other queue entry until it succeeds — it is not a fire-and-forget best effort.

Sign-out never blocks on an empty queue: it replays pending work with a bounded timeout, then signs out regardless. Every queue entry is scoped to the user who created it (`PendingSync.ownerUserId`) and is durable across sessions, so nothing is lost and nothing leaks between users.

## Startup

Budgly paints its first useful frame without waiting for services that are not required to render the initial route. The contract has two stages (it matches `lib/main.dart`).

**First-frame critical** — before `runApp`, because the dependency graph requires them:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `.env` loading and Firebase initialization
3. Supabase initialization
4. creation of the root `ProviderContainer`

No domain data fetch, analytics initialization, Crashlytics setup, Google Sign-In setup or sync replay may block this stage.

**Deferred** — started from `addPostFrameCallback` in `BudglyStartup`, and allowed to finish after the first frame: sync handler registration (`syncBootstrapProvider`) and sync lifecycle start (`SyncManager.start()`), Crashlytics configuration, PostHog initialization and startup analytics (`identify` included), Google Sign-In initialization.

**Hydration rule.** `ProfileSession` hydrates local preferences/profile asynchronously and must not make `main()` wait for profile or network data. A cached profile is used as soon as it is available; the remote refresh is background work. Feature providers follow the same rule: render from the current local state first, attach remote refreshes afterwards.

**Audit rule.** Do not move work into the critical path because it is convenient. A new startup dependency must answer: is it required to construct the first route? to render the first frame correctly? can a local/cache value replace the remote result initially? can it safely start after `addPostFrameCallback`? If the answer is no, it belongs in the deferred phase.

A real startup benchmark still requires runtime profiling on representative Android devices; no measured first-frame improvement is claimed (see `STATUS.md`).

## Testing

- Domain contracts: deterministic unit tests.
- Services: persistence, synchronization, errors and business rules.
- Riverpod Notifiers: state transitions and feature mutations.
- Widgets: presentation and local interaction.
- Integration tests: a small set of end-to-end offline/recovery journeys.

Critical contracts take priority over raw coverage: offline sync, authentication/session boundaries, dates/recurrence, optimistic mutations, ownership and financial calculations.
