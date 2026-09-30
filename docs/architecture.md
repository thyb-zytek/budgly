# Budgly — architecture

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
- `SyncManager`: lifecycle-bound coordinator that replays the queue. It is exposed through Riverpod and has no production singleton compatibility API.

## Dependency injection

Riverpod is the composition boundary. Providers construct services and pass their dependencies explicitly.

Rules:

- no `SomeService.instance` access in production domain code;
- process-wide resources are allowed only when their lifecycle is genuinely process-scoped (for example the analytics client or auth lifecycle bridge), and they remain exposed through Riverpod;
- tests instantiate explicit services/coordinators instead of relying on production singletons;
- constructors must not silently reach into unrelated global state.

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

## Dates and periods

Business dates are calendar dates; time-of-day has no business meaning.

`CalendarDateRange` defines the shared range contract as:

```text
[start, endExclusive)
```

The start is included and the end is excluded. Firestore queries therefore use `>= start` and `< endExclusive`. Recurring expenses keep their user-facing `endDate` as an inclusive calendar date, while internal range calculations use the following day as the exclusive boundary.

## Expenses and recurrence

`ExpenseOccurrenceCalculator` is the single projection engine for recurring occurrences. It accepts `CalendarDateRange`, jumps directly to the first relevant occurrence and applies keyed occurrence exceptions without creating a separate Firestore collection.

Undebited historical occurrences are handled by `UndebitedExpensesService`. The initial Firestore scan is bounded to expenses whose source series begins before the current period; occurrence expansion then determines which historical occurrences actually require action.

## Offline-first contract

Local optimistic changes remain visible immediately and survive refreshes, retries and process crashes until the remote mutation is confirmed.

For Supabase-backed mutations:

```text
mutation
  ↓
Riverpod session update
  ↓
LocalCache
  ↓
SyncQueue
  ↓
SyncManager
  ↓
Supabase
```

Sync ordering is preserved per entity. A failed account blocks only dependent categories/expenses; unrelated entities continue to synchronize. Failed operations are retried with backoff (scheduled to wake at the earliest retry time, not just on the periodic timer) and are never silently dropped. A failure the server will keep rejecting (see `SyncError` classification in `sync_error_classifier.dart`) is flagged `permanent`: it stops being replayed by background triggers but stays visible and durable, and an explicit user retry (`flush(retryPermanent: true)`) gives it another chance.

For Firestore-backed expenses and budgets, native Firestore offline persistence provides the durable write queue; Budgly does not introduce a second application queue for those writes. Expense/budget writes are not awaited by the caller: the write's Future only completes on a server acknowledgement, which never happens offline. A rejection is reported asynchronously (`ExpensesService.rejectedWrites`) and reconciled by reloading the affected account.

Deleting an account or a category enqueues a durable `cleanup` operation (`DeletionCleanupService`) once the Supabase delete is server-confirmed. It purges the Firestore documents this device may not have cached (server-side query) and the storage folder, and is retried like any other queue entry until it succeeds — it is not a fire-and-forget best effort.

Sign-out never blocks on an empty queue: it replays pending work with a bounded timeout, then signs out regardless. Every queue entry is scoped to the user who created it (`PendingSync.ownerUserId`) and is durable across sessions, so nothing is lost and nothing leaks between users.

## Startup

`main()` initializes Flutter, Firebase, Supabase and crash reporting, then creates the Riverpod application scope. The sync composition provider explicitly registers domain handlers and starts the lifecycle-bound coordinator. Analytics and other non-blocking enrichment work starts after `runApp()`.

## Testing

- Domain contracts: deterministic unit tests.
- Services: persistence, synchronization, errors and business rules.
- Riverpod Notifiers: state transitions and feature mutations.
- Widgets: presentation and local interaction.
- Integration tests: a small set of end-to-end offline/recovery journeys.

Critical contracts take priority over raw coverage: offline sync, authentication/session boundaries, dates/recurrence, optimistic mutations, ownership and financial calculations.
