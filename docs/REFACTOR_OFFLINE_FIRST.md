# Offline-first refactor

## Goal

Budgly treats local data as the source used by the UI. Network calls refresh data or synchronize mutations; they do not block normal navigation or rendering when local data exists.

## Rules

1. `main.dart` waits only for infrastructure required to build the app.
2. Route guards never perform network requests.
3. Reads hydrate from local state first, then refresh remotely in the background when possible.
4. Supabase writes update local state first and are persisted in `SyncQueue`; the UI does not wait for the remote round-trip.
5. Firestore writes use Firestore's own offline persistence.
6. Analytics and user feedback remain explicit product concerns and are not removed for the sake of reducing code.
7. A fire-and-forget task must catch its own errors; `unawaited()` is only used for deliberately detached work.

## Current data ownership

| Data | Local source | Remote source | Sync mechanism |
|---|---|---|---|
| Profile | `ProfileStore` + `LocalCache` | Supabase | `SyncQueue` |
| Accounts | `AccountsStore` + `LocalCache` | Supabase | `SyncQueue` |
| Categories | `CategoriesStore` + `LocalCache` | Supabase | `SyncQueue` |
| Expenses | `ExpensesStore` + Firestore offline cache | Firestore | Firestore |
| Budgets | `AccountBudgetsStore` + Firestore offline cache | Firestore | Firestore |
| Category icons | bundled asset | Supabase optional refresh | none required |

## Startup

The cold start is intentionally small:

```text
dotenv + Firebase + SharedPreferences
            ↓
      Supabase init
            ↓
          runApp
            ↓
 local profile / sync / analytics / Google init
         in background
```

The Firebase `currentUser` is trusted for initial routing. A remote auth/profile refresh may invalidate the session later, but it is not a prerequisite for the first frame.

## Navigation

`RouteGuards.authRedirect` is local-only. The router listens to both Firebase auth state and `ProfileService`, so it can react when local profile hydration finishes without doing a network request during every navigation.

## Writes

Supabase mutations follow: `store → LocalCache → SyncQueue → remote`. This gives immediate UI feedback and preserves the mutation across app restarts/offline periods. Password changes are intentionally different because Firebase requires a server-authenticated operation.

## What was removed/simplified

- duplicate Overview readiness state;
- debug TEST action in Overview;
- blocking remote writes for accounts/categories/profile settings;
- remote category-icon loading as a prerequisite for displaying icons;
- five-minute sync polling as a safety net, with mutation/resume triggers doing the real work.

`ViewModelSelector`, `SyncQueue`, and `SyncManager` remain because they provide useful behavior without duplicating domain state: targeted rebuilds, and durable Supabase delivery/retry. Overview derived data is memoized directly in `OverviewViewModel`; service-local `Future` maps handle request de-duplication without a generic cache layer. Firestore metrics were removed because they had no user-visible impact.


## Dependency cleanup

Unused `flutter_iconpicker` and `flutter_localization` dependencies were removed. Flutter's built-in `flutter_localizations` remains because it is used by the MaterialApp localization delegates.


## Analytics during non-blocking startup

Analytics initialization is deliberately detached from `runApp()`. `AnalyticsService` therefore buffers a small number of sanitized events and the latest identity until PostHog is ready. This keeps analytics coverage without turning telemetry into a cold-start dependency.
