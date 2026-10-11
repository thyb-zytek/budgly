# Foundation review — Lots 6/7 (2026-10-10)

## Scope and validation boundary

This checkpoint consolidates dependency-upgrade guidance, explicit SDK-client composition, session-generation guards, and regressions for async completions after state clearing. It is a source-level change set. Flutter/Dart executables are not available in the editing environment, so this document does **not** claim `dart format`, `flutter analyze`, unit/widget/integration tests, or an APK build passed.

## Lot 6 — dependency injection and async failure handling

- Added `lib/src/core/dependencies/backend_clients_provider.dart` as the composition point for Firebase Auth, Firestore, Supabase and Google Sign-In SDK clients.
- Production Riverpod service providers now inject SDK clients into the Auth, Account, Category, Expense, AccountBudget and Profile adapters/services. Constructor fallbacks remain available for tests/standalone usage; they are not removed wholesale without compilation and caller inventory.
- `ProfileSession._setUser` now sends local preference mirror failures to `AppLogger` through a guarded helper instead of leaking an unhandled `unawaited` failure.
- `ProfileService` protects in-flight remote snapshots using a per-user mutation revision, verifies identity and queued mutations again immediately before cache write, and serializes profile cache writes with local mirrors.
- `savePreferences` marks its mutation before its first `await`; user-name/preferences/onboarding mirrors skip stale results if a newer mutation has started.
- `AccountImageHelper.uploadAndLinkImage` now awaits the retry-queue attempt and logs queue failures instead of discarding an unhandled future.

## Lot 7 — ownership, race guards and regression coverage

- `AccountsSession`, `CategoriesSession`, `ExpensesSession` and `AccountBudgetsSession` reject results/callbacks started before session/account invalidation. Local account/category/expense mutations also invalidate stale in-flight list responses where applicable.
- `ProfileSession` compares the UID observed from Firebase Auth independently of `state.currentUser`. This catches sign-out/identity changes even while the profile has not been published because accounts/categories are still preloading.
- `SyncQueue` migrates legacy operations missing `owner_user_id` to the authenticated user on the first queue read while signed in. If the app starts signed out, the entries stay ownerless until the first authenticated read after login, then the assigned owner is persisted and never silently changed later. This policy is explicit because the legacy schema did not record a provable owner.
- Regression tests were added/updated for ownerless queue migration (signed-out preservation and first authenticated claim), profile refresh racing a local preference mutation, stale account/category/expense/budget loads after clearing, and auth logout during reference-data preload.

### Legacy owner migration policy

The product decision is to assign legacy operations without `owner_user_id` to the currently authenticated user on the first queue read. When no user is authenticated, the queue remains unchanged; after the first user logs in, the first authenticated queue read claims and persists those entries for that user. Once persisted, the owner is never changed by subsequent accounts. This deliberately accepts the product's migration assumption that the first authenticated user on the device owns the legacy local queue. Verify the signed-out → first login → replay path in an integration test before release.

## Dependency upgrades

See `docs/DEPENDENCY_UPGRADE_PLAN.md`. The current `pub outdated` output does not justify forcing all latest versions at once. In particular, `go_router` 18, `cross_file` 0.4, `equatable` 3, `cli_util` 0.6 and `pub_api_client` 4 are separate major-version migrations. This checkpoint deliberately leaves `pubspec.yaml` / `pubspec.lock` package versions unchanged.

## Remaining items (not claimed as completed)

- Run formatting, analyzer, unit/widget tests, integration tests and build on the user's Flutter toolchain.
- Fix all reported analyzer/test failures from this checkpoint before manually validating.
- Decide a user-safe recovery strategy for unknown-owner legacy queue items.
- Add/execute an end-to-end offline account/category deletion recovery test.
- Verify deployed Supabase RLS/JWT policy behavior with two real Firebase test users on a staging project.
- Review ExpensePeriodCache/optimistic reconciliation only against a defined behavioral matrix; do not remove the cache preemptively.
- Profile frame timings and startup on physical Android devices; static audit is not a runtime performance measurement.
