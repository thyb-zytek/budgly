# Budgly — Refactoring et dette technique

> Source de vérité du chantier de refactorisation. Le détail exhaustif des anciens checkpoints n'est volontairement plus conservé : le plan et l'état actuel suffisent pour reprendre le travail.

## 1. Plan de refactorisation



## Goal
Bring Budgly to a stable, maintainable production base before adding major product features. The refactor may change architecture substantially; preserving legacy structure is not a goal.

## Phase 1 — Reliability foundations
- [x] Normalize business dates to calendar-day semantics.
- [x] Harden offline create/update/delete behavior.
- [x] Make sync dependency blocking entity-scoped.
- [x] Reconcile remote refreshes with pending local mutations.
- [x] Protect profile/session state from stale asynchronous results.
- [x] Make recurring split retries deterministic/idempotent where required.

## Phase 2 — Dependency injection and state ownership
- [x] Remove service singletons for Accounts, Categories, Expenses, Budgets, Auth, Profile and CategoryIcons.
- [x] Compose those services through Riverpod providers.
- [x] Replace service-to-service singleton calls with constructor dependencies.
- [x] Remove migration probes/no-op compatibility hooks encountered during the migration.
- [x] Finish domain-service singleton access removal; retain only lifecycle/telemetry process-wide resources behind Riverpod.
- [x] Make sync handler registration explicit instead of constructor side effects.
- [x] Consolidate reactive state ownership around Riverpod sessions/notifiers.
- [ ] Remove remaining duplicated service/session/cache state where it has no technical purpose.

## Phase 3 — Model and date correctness
- [x] Audit all model collections for immutability/copy semantics.
- [x] Make equality semantics explicit, especially null IDs.
- [x] Centralize occurrence exception date parsing.
- [x] Audit all period/date comparisons for half-open calendar ranges.
- [x] Verify amount normalization/rounding contracts with focused tests.
- [x] Add explicit half-open calendar-range contract tests and migrate Firestore/in-memory period filters to the same semantics.

## Phase 4 — Persistence and sync scalability
- [x] Make every offline mutation explicitly session-owned and prevent replay under a different Firebase user.
- [x] Reduce whole-JSON SharedPreferences queue rewrites during sync batches without introducing unnecessary storage dependencies.
- [x] Review signed URL caching and duplicate requests.
- [x] Review recurring-expense Firestore query scope.
- [x] Review undebited-expense occurrence expansion for large histories.
- [x] Audit sync handlers for ambiguous-outcome idempotence and make recurring split creation deterministic.
- [ ] Validate process-restart and ambiguous-outcome replay with a real Flutter runtime.
- [ ] Add ID indexing only if profiling demonstrates a real need.

## Phase 5 — Dead code and documentation
- [x] Remove unused bridges and obsolete migration files after reference audit.
- [x] Consolidate architecture documentation.
- [x] Remove stale coverage/process documentation.
- [x] Ensure README reflects the current architecture.

## Phase 6 — Tests and CI
- [x] Simplify the test pyramid so test groups are disjoint and intentional.
- [x] Strengthen critical contracts rather than chasing 100% coverage.
- [ ] Cover low-coverage critical services and UI flows where regressions are costly.
- [x] Add format/analyze gates and keep generated-code checks consistent.
- [x] Keep release APK artifact generation deterministic.

## Phase 7 — Performance and final cleanup
- [x] Perform a static performance audit and identify rebuild scopes that can be tightened without changing product semantics.
- [x] Remove unnecessary Riverpod listeners that recomputed feature state for unrelated session changes.
- [x] Validate ScreenUtil usage is centralized in app/theme/test bootstrap.
- [ ] Profile the running application on representative devices before adding caches/indexes or claiming runtime gains.
- [x] Separate first-frame-critical startup dependencies from deferred initialization.
- [x] Document the startup performance contract and deferred-loading rules.
- [ ] Re-run the full audit and resolve remaining high-impact findings.

## Delivery process
At every checkpoint: update `REFACTORING.md` and `STATUS.md`, include `Agent.md`, and deliver a new project archive.

### Recurrence lower-bound invariant
- [x] Ensure backwards calendar navigation never causes recurring-expense projection before the expense `debitDate`.
- [x] Add explicit regression coverage for a recurrence created mid-month and queried in earlier periods.


---

## 2. État actuel du chantier

### Réalisé

- Fondations de fiabilité, dates calendaires et plages `[start, endExclusive)` stabilisées.
- Architecture Riverpod/DI consolidée ; suppression des singletons métier et ownership réactif centralisé.
- Mutations Supabase offline explicitement rattachées à l'utilisateur Firebase courant.
- SyncQueue persistante et SyncManager avec retry/backoff, dépendances par entité et batch persistence.
- Audit d'idempotence : créations Firestore déterministes pour les opérations ambiguës, notamment les splits de récurrence.
- Audit récurrence : bornes calendaires, mois courts, années bissextiles, offsets négatifs et borne inférieure `debitDate`.
- Audit startup : travail non essentiel différé après `runApp()` et contrat de première frame documenté.
- Audit performance statique des scopes Riverpod et de ScreenUtil réalisé.

### Reste à valider

- Validation runtime Flutter des scénarios process-restart et réponses réseau ambiguës.
- Profilage réel sur appareils représentatifs avant tout cache/index supplémentaire.
- Compléter la couverture des services/UI critiques identifiés par la stratégie de tests.
- Audit final repository-wide et suppression des derniers doublons d'état qui auraient une justification insuffisante.

### Reprise du chantier

Chaque nouveau checkpoint doit mettre à jour `REFACTORING.md`, `STATUS.md` et `Agent.md`, puis produire une archive du projet.

### Checkpoints historiques

- **2026-09-20** — Checkpoint — Phase 12 ambiguous-outcome idempotence audit
- **2026-09-20** — Checkpoint — Phase 11 offline queue ownership and session-boundary hardening
- **2026-09-19** — Checkpoint — Phase 7 static performance audit and rebuild-scope cleanup
- **2026-09-19** — Checkpoint — Phase 6 test pyramid / CI gates completed
- **2026-09-19** — Checkpoint — Phase 5 architecture/dead-code cleanup completed
- **2026-09-19** — Checkpoint — Phase 4 network/query scope completed
- **2026-09-19** — Checkpoint — Phase 4 sync queue batch persistence completed
- **2026-09-19** — Previous checkpoint — Phase 3 date-range contract completed
- **2026-09-20** — Checkpoint — DI/session and idempotence audit started
- **2026-09-20** — Checkpoint — recurrence matrix and startup audit
- **2026-09-20** — Checkpoint — recurrence lower-bound correction

## 2026-10-06 — Static audit hardening

- Added a forward Supabase migration enabling RLS on `user_profiles`, `accounts`, and `categories`.
- Reworked RLS architecture tests to inspect migration contents rather than tautological literal assertions.
- Hardened audited `Overview` and `Tutorial` async state writes with lifecycle guards.
- Moved Flutter `TextEditingController` ownership from `ExpenseEditingData` to `ExpenseFormController`.
- Switched undebited expense rendering to a lazy list and category summary resolution to O(1) ID lookup.
- Added a CI guard rejecting tracked signing credentials, `.env`, Google Services and certificate material while preserving ignored local secret files.

## 2026-09-20 — Test failure remediation checkpoint

The latest local `tests_all.log` was audited failure-by-failure. The remediation distinguishes test-contract drift from production defects instead of weakening assertions indiscriminately.

### Corrected production defects

- Fixed `ExpenseOccurrenceException.sourceDate` validation so canonical `expenseId@YYYY-MM-DD` keys are parsed correctly.
- Fixed `SyncManager` dependency blocking so a parent operation that succeeds during a forced retry unblocks its dependents later in the same flush.

### Corrected test contracts

- Migrated recurrence tests to the half-open `[start, endExclusive)` range contract.
- Updated transient `Account`/`Category` equality tests to the explicit null-ID identity contract.
- Updated `ExpenseEditingData` default-date test for calendar-day normalization.
- Updated recurring split test to assert stable preallocated identity.
- Added missing `AuthService` overrides to tests that indirectly construct `ProfileSession`.
- Updated `UndebitedExpensesService` fakes for the account-before query contract.
- Updated queue tests to assert crash-safe create→delete replay rather than cancellation.
- Injected the integration test's shared `SyncManager` into `SyncIssueBanner`.

### Recurrence invariant retained

Backward navigation may calculate previous calendar dates, but occurrence projection remains bounded by the recurring expense's first valid date (`debitDate`). An expense created on 2025-12-12 must never appear in a period before December 2025. The monthly date arithmetic fix for negative month offsets is retained because it correctly handles year boundaries; it does not override the business lower bound.

### Validation status

Flutter/Dart execution is not available in the current environment, so this checkpoint is based on the uploaded test output plus static source/test reconciliation. A fresh local `flutter test --coverage test` and `flutter test --coverage integration_test` run is required before declaring the suite green.


## 2026-09-20 — Follow-up remediation from latest local test output

The user-provided `tests_all.log` is the current runtime baseline for this pass:
- unit/widget suite: **992 passed, 14 failed**;
- integration suite: **8 passed, 2 failed**.

The 14 unit failures were traced to:
- two inverted `Account` equality assertions;
- one transient `Category` equality assertion;
- two Category Expenses tests indirectly constructing `ProfileSession` without a Firebase-safe `AuthService` double;
- three Login tests with the same Firebase-session test-double gap;
- four Revenue tests with the same Firebase-session test-double gap;
- two SyncManager tests whose category fixtures omitted the `account_id` required by the entity-scoped dependency contract.

The two integration failures were caused by constructing `ExpensesService` directly without registering its `expenses` sync handler with the shared integration `SyncManager`. The test setup now registers that handler explicitly.

The production `SyncManager.instance` static accessor was also removed because it was unused and violated the current DI rule.

No recurrence arithmetic was changed in this pass. The existing lower-bound invariant remains: backwards calendar calculation is allowed, but occurrence projection must never materialize an occurrence before the series `debitDate`.

Validation status: these changes were reconciled against the supplied local test output and source statically. A fresh local Flutter test run is still required to confirm the post-fix result.

## 2026-09-20 — Static-analysis cleanup: `sync_manager_force_retry_test`

The latest local `dart analyze` reported 17 errors, all in `test/services/offline/sync_manager_force_retry_test.dart`. The test still referenced the removed singleton APIs (`SyncManager.instance`) and used `SyncQueue.instance`, while the production coordinator is now explicitly constructed/injected.

The test was migrated to its own explicit `SyncQueue` + `SyncManager` fixture, matching the DI contract already used by the other SyncManager tests. No production singleton API was reintroduced.

## 2026-09-23 — RL-01 compliance pass (auth, onboarding, preferences, cache revalidation)

Brought the app's behavior in line with `docs/rules/RL-01.md`, in two passes: an
initial audit, then a second pass after the domain owner clarified several
points (see below). At the time of that pass no Flutter/Dart execution was available in the authoring
environment; **this work was validated on 2026-09-29** (`flutter analyze` 0 issue, `flutter test` 1180/1180,
`flutter test integration_test -d emulator-5554` 12/12, coverage 68,8 %).

### Corrected production defects

- **Post-auth routing (§2):** `Login.resolvePostAuthDestination` and
  `RouteGuards` now key exclusively off `UserProfile.onboardingCompleted`,
  including bidirectionally (an unfinished onboarding is confined to
  `/tutorial`; a completed one bypasses it even without an account).
  Previously, having zero accounts could route a completed profile back into
  onboarding, and the guard only redirected away from `/login`.
- **Google verification (§1.1):** added `isAccountVerified` (Google
  Sign-In is treated as verified regardless of Firebase's `emailVerified`
  flag) and wired it into `User.fromFirebaseUser` and `RouteGuards`.
- **Onboarding resume (§2.2):** `resolveOnboardingStartStep` makes the
  no-saved-step / has-saved-step / no-account-yet cases explicit; the
  onboarding flow no longer starts on the account-creation step by default
  nor resumes past a step whose data (an account) doesn't exist yet.
- **Local preference mirror (§1.3):** the `theme_mode` / `app_locale` /
  `app_currency` / `amount_decimal_places` `SharedPreferences` keys were
  global (not scoped per Firebase uid) and were only ever written by the
  explicit Preferences screen, never by `ProfileSession` applying a
  cache/remote profile. On a device shared by several accounts this could
  paint one user's theme/locale/currency for another, and could leave a
  previous user's settings visible after sign-out until a profile reloaded.
  The keys are now uid-scoped (`ProfileService.loadLocalPreferences`/
  `cacheLocalPreferences`), and `ProfileSession._setUser` write-throughs the
  local mirror every time a profile is applied, not just from the
  Preferences screen.
- **Cache-first revalidation not reaching the UI (§3.2):** `AccountsService`
  and `CategoriesService` leaked their in-flight guard on the
  cache-hit-then-background-refresh path (never released, since only the
  `await future` branch's `finally` released it) — once a background
  revalidation had run once, later calls (including `forceRefresh: true`)
  returned the same stale completed future forever instead of hitting the
  network again. Separately, in `AccountsService`, `CategoriesService`,
  `ExpensesService` (period loads) and `AccountBudgetsService`, the result of
  a background revalidation was dropped (`unawaited(future)`) rather than
  reaching the reactive session — so even when the service did refresh, nor
  Overview nor any other watcher would ever rebuild from it. Both are fixed:
  the in-flight guard is now always released via `whenComplete`, and each
  method takes an optional `onRevalidated` callback that the corresponding
  Riverpod session (`AccountsSession`, `CategoriesSession`, `ExpensesSession`,
  `AccountBudgetsSession`) wires to its existing merge/set logic, so a later
  server-confirmed result updates shared state and the UI rebuilds.
- **Onboarding completion (§2.2/§3.4):** `Tutorial.completeTutorial` no
  longer waits for confirmation that `onboardingCompleted` reached the
  session before clearing the persisted step. `ProfileSession.completeOnboarding`
  already writes the local cache and enqueues the remote update before
  returning (the optimistic-mutation contract every other mutation follows);
  a remote failure at that point is an ordinary pending `SyncQueue` entry
  retried silently in the background, not a completion failure.

### Confirmed compliant, no change made

- `UndebitedExpensesService`/`UndebitedExpensesProvider`: per-account, prior-
  period-only scope for all of the user's accounts is the intended behavior,
  not a bug.
- `RefreshThrottle`'s one-minute interval governs how often a background
  network revalidation may fire, not cache expiration; RL-01's "no
  expiration timers" clause is about never invalidating cached data on a
  timer, which the app still never does.

### Tests added

- `test/services/accounts/accounts_service_revalidation_test.dart`,
  `test/services/categories/categories_service_revalidation_test.dart`:
  real-service regression coverage for the in-flight leak and for
  `onRevalidated` firing.
- `test/state/accounts_session_test.dart`, `categories_session_test.dart`,
  `expenses_session_test.dart`, `account_budgets_session_test.dart`: new
  cases asserting a simulated background revalidation updates shared state.
- `test/services/profile/profile_local_preferences_test.dart`,
  `test/state/profile_session_test.dart`: uid-scoping, no cross-account
  leakage, defaults when signed out, and the `ProfileSession` write-through
  end to end.

### Still open

- Empty-cache/offline error state (retry banner) on Overview.
- `docs/QUALITY.md` not updated in this pass.

## 2026-09-23 — Coverage-gap pass on the RL-01 workstream

A supplied `coverage_report.json`/`.log` (unit/widget suite only — line
coverage does not include `integration_test/`) was audited for gaps directly
tied to this workstream:

- `lib/src/pages/tutorial/onboarding_resume.dart`: 1/3 lines (33%) — the
  no-account clamp branch was only reached indirectly through
  `tutorial_provider_test.dart` and never asserted on its own. Added
  `test/pages/tutorial/onboarding_resume_test.dart` covering every branch.
- `lib/src/services/budget/account_budgets_service.dart`: 10/60 lines (17%)
  — the only three services whose `onRevalidated` callback was added in this
  pass (`AccountsService`, `CategoriesService`, `AccountBudgetsService`) had
  real-service regression tests for only the first two. Added
  `test/services/budget/account_budgets_service_revalidation_test.dart` for
  parity (this service turned out to already release its in-flight guard
  correctly — the test locks in that contract rather than fixing a bug).
- Other large gaps noted but out of this pass's scope (not modified by this
  workstream): `lib/src/pages/overview/view.dart` (0.7%),
  `overview_content.dart` (0%), `overview_provider.dart` (17%),
  `lib/src/core/navigation/app_router.dart` (10%, the GoRouter wiring itself
  — `RouteGuards`'s decision function is well covered at 91%, but the actual
  `redirect:` callback wiring it into GoRouter is not), and the tutorial step
  widgets (`account_step.dart`, `budget_step.dart`, `category_step.dart`, all
  0%). These are widget-level gaps pre-dating this workstream.

### RL-01 integration coverage added

- `integration_test/overview_background_revalidation_test.dart`: chains
  `AccountsService` → `AccountSelection` → `ExpensesService` →
  `PeriodExpenses` end to end and asserts the Overview pipeline renders the
  cache-first snapshot immediately, then rebuilds once a scripted background
  revalidation delivers server-confirmed data — the integration-level
  regression test for the "Overview shows stale/empty content and never
  rebuilds" bug (RL-01 §3.2).
- `integration_test/user_journey_resume_test.dart`: added the missing "zero
  accounts, onboarding completed" case — the exact regression the §2 routing
  fix targeted — alongside the existing resume/overview scenarios.

## 2026-09-23 (2) — Filling significant coverage gaps

Added real behavior tests for the largest gaps identified in the previous
checkpoint that were unit-testable without full widget pumping:

- `lib/src/pages/overview/overview_provider.dart` (was 17%): added
  `loadInitialData` happy path (populates `PeriodExpenses`/`Revenue` for the
  selected account), the zero-accounts case, a re-entry-guard regression test
  (a second concurrent call must not duplicate the account fetch), and full
  `createExpense` coverage (every fast-fail validation branch plus the
  success path), and `consumeMessage`.
- `lib/src/pages/settings/profile/profile_settings_provider.dart` (was 9.8%):
  added full branch coverage of the pure `validatePassword` function and
  `changePassword`'s three outcomes (success, the dedicated
  `password-change-failed` message, any other error falling back to the
  generic classifier).
- `lib/src/pages/tutorial/onboarding_resume.dart`, `account_budgets_service.dart`:
  covered in the previous checkpoint.
- `AppRouter.parsePeriod`: added the remaining edge cases (`month=0`,
  non-numeric `year`, `month` missing while `year` is present) to the
  existing test.

### Deliberately not attempted in this pass

Building these requires pumping a full widget tree (`MaterialApp` /
`GoRouter` with every branch's page, or at minimum several chained
Riverpod providers) that this environment cannot execute to verify, so
attempting them blind risked shipping tests that look plausible but don't
actually compile or pass:

- `lib/src/core/navigation/app_router.dart`'s `redirect:` wiring itself (the
  decision function `RouteGuards.decideRedirect` it calls is already at 91%
  coverage from `route_guards_test.dart`; what's uncovered is GoRouter
  actually invoking it end to end, which needs a pumped `MaterialApp.router`
  and, because `StatefulShellRoute.indexedStack` mounts every branch eagerly,
  a full fake dependency graph for both the Overview and Settings tabs).
- `lib/src/pages/overview/view.dart`, `overview_content.dart` (0-1%) and the
  tutorial step widgets `account_step.dart`, `budget_step.dart`,
  `category_step.dart` (0%): plain widget tests, not covered by this RL-01
  workstream's changes, and out of scope for a blind pass.

A follow-up pass with the ability to actually run `flutter test` (to iterate
on pump/override mistakes) is the right way to close these — attempting them
without that feedback loop is more likely to produce broken tests than
working coverage.


## 2026-09-23 — Overview initial-load session reactivity regression

### Problem
The first correction removed the `PeriodExpenses` session listeners to avoid an
eager recomputation during the sequential initial load. That removed the stale
final-state overwrite, but it also broke the reactive path used by cache-first
loads/background revalidation: when `ExpensesSession` or `CategoriesSession`
changed after the provider had built, `PeriodExpenses` no longer rebuilt from
the new session state. The Overview could therefore remain empty until a
manual pull-to-refresh.

### Correction
- `PeriodExpenses.build()` listens to both `ExpensesSession` and
  `CategoriesSession`, so background/session updates are reflected immediately.
- `PeriodExpenses.load()` still loads expenses first, categories second, then
  recomputes from the current shared session state.
- The final `load()` state transition reads the current notifier state after
  recomputation instead of restoring a stale snapshot captured before awaits.
- The provider tests cover both session-reactivity paths: expenses changes and
  category changes.

### Validation status
The project was statically inspected and the regression tests were updated.
Flutter/Dart execution is not available in this environment, so local `flutter
analyze` and the relevant provider test still need to be run on a Flutter
environment.


### Overview data ownership correction (2026-09-23)
- `ProfileSession` preloads accounts and categories for every account before exposing the loaded signed-in profile to navigation.
- `Overview` no longer loads accounts or categories. It loads the selected period's expenses when the page is entered.
- Expenses remain screen/period-scoped data and are intentionally excluded from profile bootstrap.

## 2026-09-23 — Overview account switching and global undebited scope

- Changing the selected account in Overview now explicitly reloads the new
  account's period expenses (and its revenue) instead of relying on the
  previously selected account's provider state.
- The undebited-expenses pipeline remains intentionally account-independent:
  it loads expense data for **all** accounts and computes the global set of
  undebited occurrences. Account filtering is only a presentation concern in
  the Undebited Expenses UI.
- The all-account undebited loads are now performed concurrently rather than
  sequentially, while preserving the same all-account scope.
- Added a regression test ensuring an Overview account change triggers a
  period-expense load for the newly selected account.

## 2026-10-06 — Audit hardening: W6/W7 UI decomposition

- `006_rls_security.sql` was renamed to `006_storage_rls.sql` to make its
  storage-only scope explicit. The migration content is unchanged; core table
  RLS remains enabled by `008_enable_core_rls.sql`.
- W6: the large `build()` methods identified by the audit were decomposed into
  named rendering responsibilities (summary compact/expanded, occurrence
  card, user details, advanced options, expense card, settings views and
  login). The original behavior and state ownership remain unchanged.
- W7: `CategoryExpensesPage._openEditSheet()` now only prepares the editing
  state and opens the sheet. The `ExpenseEditorSheet` construction is isolated
  in `_buildExpenseEditorSheet()`, reducing the orchestration method from 213
  lines to a short workflow.
- No generated Riverpod files were modified.
