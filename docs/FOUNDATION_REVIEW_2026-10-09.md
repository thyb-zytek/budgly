# Budgly — foundation review after Lot 4 (2026-10-09)

## Scope and evidence level

This is a static follow-up to the Riverpod/session and UI work. It inspects the current archive's production Dart tree, tests/integration tests, CI workflow, toolchain declarations, and Supabase migrations. Flutter/Dart are unavailable in the editing environment; no current-checkpoint app build, `dart format`, `flutter analyze`, unit/widget tests, integration tests, or device measurements were executed. Existing reports dated 2026-10-06 are historical baselines only.

## Lot 4 delivered

- CI and local documentation now agree on Flutter 3.47.5 / Dart 3.13.4.
- `pubspec.yaml` requires Dart `^3.13.0`; `pubspec.lock` records a compatible lower bound.
- `tool/verify_toolchain.sh` validates installed versions and the declared/resolved SDK contract. The `test`, `integration`, and `build` CI jobs run it after SDK setup.
- CI secret material is passed via step environment variables when generating `assets/.env` and `android/app/google-services.json`.
- The quality guide no longer claims `git diff` can verify `.g.dart` files that are deliberately ignored. `build_runner` remains the generator of record.
- `.metadata` remains untouched because Flutter says it is tool-managed. The CI pin is enforced by the workflow, not `.metadata`.

## Areas already addressed by previous lots

- Removed the `AuthSessionNotifier` / `AuthSessionRevision` `ChangeNotifier` bridge and the `SyncManager` `ChangeNotifier`; UI-facing sync status flows through Riverpod.
- Added an auth-state listener that resets the profile and account/category/expense/budget sessions on observed external logout or identity change.
- Routed profile remote refresh through the protected path, retaining pending profile mutations and guarding stale auth responses.
- Removed login's `_waitForProfileLoaded()` polling.
- Applied targeted Riverpod selectors and UI extraction to Overview, CategoryView, Category Expenses, Categories/Accounts settings, and Tutorial.

These changes are not yet runtime-verified in this environment.

## Remaining high-value review items (not implemented by Lot 4)

### P1 — session isolation while reference data is preloading

`lib/src/state/profile_providers.dart`: `_handleAuthStateChanged` decides whether an identity changed by checking `state.currentUser?.id`. During `_initialize()` / `load()`, accounts and categories are preloaded before `_setUser()` publishes `currentUser`. If the Firebase identity changes while that preload is in progress, `state.currentUser` can still be null, so the current handler does not call `_resetSession()` on the non-null new identity. The revision/UID guards prevent the old asynchronous result from publishing into `ProfileSession`, but a session already populated by the in-flight account load may need an explicit reset. Add a regression test that changes auth during account preload and asserts every prior-user session is empty. The implementation should track the observed auth UID independently of `state.currentUser` and only treat the initial auth emission as initialization, not as a user switch.

### P1 — `SyncQueue` migration for entries without an owner (policy updated 2026-10-10)

The initial review flagged the risk of assigning legacy entries to an account because the old schema did not capture ownership. The explicit product decision is now to keep entries unchanged while signed out, then assign and persist them to the currently authenticated user on the first authenticated queue read. Later users cannot reassign already-owned operations. This policy is implemented in `SyncQueue._read()` and covered by signed-out, first-user-claim, and different-user regression tests. It deliberately uses the first authenticated user as the migration owner; validate the actual signed-out → login → replay flow in integration testing before release.

### P1 — profile refresh vs a mutation created during the remote await

`lib/src/services/profile/profile_service.dart`, `_refreshProfileFromRemote()`: the pending `user_profiles` check happens before `reloadCurrentUser()`, then the method awaits the remote result and writes it to the local cache. A local preference/profile mutation can be enqueued while that remote request is in flight, after the initial pending check. Add a race test that pauses the remote response, performs a local profile mutation, and then releases the response. A second pending check after the await is a useful minimum guard, but fully robust reconciliation may need a local profile revision/version so a response started before a local mutation cannot overwrite that newer mutation even if its queue entry flushes before the response returns.

### P2 — unawaited persistence and media follow-up errors

Review unawaited operations for explicit failure policy rather than assuming they are harmless:

- `lib/src/state/profile_providers.dart`, `_setUser()` starts `cacheLocalPreferences()` without an error handler.
- `lib/src/services/profile/profile_service.dart`, `loadUserProfile()` starts `_refreshProfileFromRemote()` without awaiting it on the cached-profile path; the refresh method's queue pre-check occurs outside its internal remote-error `try` block.
- `lib/src/services/image/account_image_helper.dart`, `uploadAndLinkImage()` starts `queuePictureUpload()` unawaited inside the image-failure recovery path.

These paths should either catch/log errors locally or return an awaitable result to a layer that owns the failure UX. Do not convert all `unawaited` calls indiscriminately; several have explicit error handling and are intentional background work.

### P2 — expense period cache and optimistic reconciliation (existing X2)

`lib/src/services/expenses/expense_period_cache.dart`, `lib/src/services/expenses/expenses_service.dart`, and `lib/src/pages/category_expenses/category_expenses_provider.dart` remain a major coupling/reconciliation area. `docs/AUDIT_PLAN.md` already defers replacing the cache with Firestore streams. Re-open only with a behavior matrix for optimistic writes, rejected writes, recurring splits/exceptions, account changes, offline cached reads, and stale remote snapshots. Do not remove the cache just to simplify the diagram.

### P2 — account/category deletion and cross-backend cleanup

The existing cleanup service and tests are a strong base, but the end-to-end contract still deserves an integration scenario for account deletion while offline, resume/retry, a partial Firestore/Storage cleanup, and an identity change before retry. Keep cleanup durable, idempotent, and tied to the original owner.

### P2 — live Supabase RLS/JWT verification

`supabase_migrations/008_enable_core_rls.sql` enables RLS on core tables; effective isolation depends on the policies created in earlier migrations and the Firebase ID token passed into Supabase. The static architecture test is not proof of a deployed project's actual policy configuration. On a staging Supabase project, verify user A can read/write A's rows, cannot read/write B's rows, and cannot access B's storage objects; use real Firebase-issued tokens and never a service-role key for this test.

### P2 — background lifecycle / first frame

`main.dart`, `sync_bootstrap_provider.dart`, `sync_manager_provider.dart`, and `integration_test/startup_performance_test.dart` should remain a separate lifecycle track. Integration coverage exists, but no performance measurements from the current checkpoint were made. Preserve the documented rule that non-critical sync/analytics/Crashlytics/Google Sign-In work starts after the first frame.

### P2/P3 — outstanding design choices already documented

- `docs/AUDIT_PLAN.md` X7: a user-facing count/indicator of pending mutations remains deferred. This is product observability, not a migration defect.
- `docs/AUDIT_PLAN.md` X8: stronger lints (`strict-casts`, `unawaited_futures`, etc.) remain deferred. Introduce them incrementally after the current checkpoint passes analysis, not alongside large behavior changes.
- `docs/AUDIT_PLAN.md` X6: last-write-wins for cross-device recurring-expense exceptions is a documented product decision; do not relabel it as an accidental bug.
- Provider codegen standardization and UI helper extraction remain lower priority than session ownership, queue ownership, and remote/local reconciliation.

## Suggested order after the user validates this archive

1. Fix/test the auth identity race during reference preload if reproduced by the new test.
2. Add the profile refresh vs local mutation race test and harden the merge contract.
3. Test/document legacy SyncQueue owner migration.
4. Exercise cleanup + ownership under integration conditions.
5. Validate RLS with real user tokens against staging.
6. Only then continue the deferred DI and cleanup lots; leave runtime UI profiling for a device-enabled environment.
