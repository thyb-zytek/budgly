# Budgly — Qualité, tests et performance

> Source de vérité pour la stratégie de validation, les tests manuels et les audits de performance. Les mesures runtime restent à effectuer sur appareil réel.

## 0. Suivi de l'audit offline-first (2026-09-24)

Le plan de correction détaillé et son état d'avancement vivent dans `AUDIT_PLAN.md`. Points notables pour la
couverture de tests :

- `test/services/offline/sync_queue_merge_and_recovery_test.dart`, `sync_manager_flush_loop_test.dart` : fusion des
  payloads, quarantaine de la file corrompue, boucle de flush avec passe finale, erreurs permanentes.
- `test/services/accounts/accounts_service_mutations_test.dart`, `test/services/offline/local_cache_test.dart` :
  ordre enqueue-avant-cache, merge des opérations en attente, corruption du cache.
- `test/services/expenses/expense_offline_writes_test.dart`, `test/helpers/offline_expense_firestore.dart` : le
  fake Firestore précédent (`throw StateError('offline')`) ne reproduisait pas le vrai comportement offline du SDK
  (écriture locale immédiate, Future en attente jusqu'à l'ack serveur) — remplacé partout où c'était pertinent.
- `test/services/cleanup/deletion_cleanup_service_test.dart`, `test/services/offline/sync_bootstrap_provider_test.dart` :
  nettoyage durable après suppression, régression du composition root (chaque type d'entité a bien un handler).
- Ces tests ont été écrits par lecture du code puis **validés par exécution le 2026-09-29**
  (`dart analyze` 0 problème, 1 180 tests unitaires + 12 intégration verts).

## 1. Stratégie de tests

> Mesures du 2026-09-29 (Flutter 3.47.5, `dart run tool/test_pyramid.dart full`) :
> **1 180 tests unitaires/widgets + 12 tests d'intégration, tous verts, 68,8 % de couverture lignes.**
> Répartition mesurée de la couverture : `lib/src/models` ≈ 95 %, `lib/src/services/offline` ≈ 94 %,
> `lib/src/state` ≈ 85 %, `lib/src/pages` ≈ 53 % (le déficit est dans les `view.dart` de présentation,
> pas dans la logique métier).



## Goal

The test suite is organized by responsibility, not by maximizing a global coverage percentage. A regression should be caught at the lowest layer that can express the contract clearly.

## Test pyramid

| Layer | Location | Responsibility |
|---|---|---|
| Domain/core | `test/core`, `test/models`, `test/unit`, `test/shared/domain` | Pure business rules, value objects, date/amount contracts, deterministic domain controllers |
| Services | `test/services` | Persistence, synchronization, service orchestration and external-service boundaries through fakes/mocks |
| Riverpod state | `test/state` | Session/notifier state ownership, provider lifecycle and state transitions |
| Features | `test/pages` | Feature-level providers/controllers and page-specific orchestration |
| Widgets | `test/widget`, `test/golden` | User-visible rendering and interaction contracts |
| Regression | `test/regression` | Cross-cutting bugs whose contract spans multiple layers |
| Integration | `integration_test` | Real application journeys and offline/recovery behaviour requiring the application runtime |

The `test_pyramid.dart` runner keeps these groups disjoint. `all` delegates to `flutter test test` once instead of running overlapping directories repeatedly.

## Commands

```text
dart run tool/test_pyramid.dart fast
```

Fast domain-only feedback.

```text
dart run tool/test_pyramid.dart services
dart run tool/test_pyramid.dart state
dart run tool/test_pyramid.dart features
dart run tool/test_pyramid.dart widgets
dart run tool/test_pyramid.dart regression
```

Run one responsibility group.

```text
dart run tool/test_pyramid.dart all
```

Run the complete `test/` suite once and generate the coverage report.

```text
dart run tool/test_pyramid.dart integration
```

Run integration tests separately because they have a different runtime/environment contract.

## What deserves high-confidence coverage

The following contracts are intentionally prioritized over raw line coverage:

- half-open calendar ranges: `[start, endExclusive)`;
- recurring occurrence generation and exception dates;
- amount normalization/rounding;
- offline CRUD and synchronization ordering/retry behaviour;
- session/provider lifecycle and stale async results;
- persistence recovery after partial synchronization;
- cache expiry/invalidation and duplicate-request suppression;
- critical user journeys represented by widget/regression/integration tests.

## Coverage interpretation

Global line coverage is a diagnostic, not a release target. Generated localization code is excluded from the report because its generated getters do not represent independent application behaviour. A low percentage on a critical service or contract is actionable even when the global percentage is high; conversely, increasing coverage on trivial generated/UI plumbing is not a substitute for testing a critical invariant.

## CI gates

CI is expected to enforce, in order:

1. dependency installation;
2. deterministic code generation with conflicting generated outputs removed when necessary;
3. generated-source cleanliness (`git diff --exit-code -- lib`);
4. Dart formatting;
5. `dart analyze`;
6. the complete `test/` suite;
7. the `integration_test/` suite on an Android emulator (job `integration`, API 36);
8. release APK generation only after both test jobs succeed.

Integration tests run in a separate `integration` job because `flutter test` only walks `test/`. The job uses
`reactivecircus/android-emulator-runner`; it is **not** merged into the unit/widget suite because it requires a
device, and a silently-skipped integration suite must never be read as a passing one.


---

## 2. Campagne manuelle minimale



L'automatisation couvre les invariants métier, la sérialisation, les mutations offline, la queue/reconnexion, le versioning récurrent et la majorité des interactions widgets. La campagne manuelle doit donc rester courte et chercher uniquement les comportements dépendants du vrai appareil, du vrai réseau ou des services externes.

## Passe recommandée — 10 scénarios

| # | Scénario | Vérification | Priorité |
|---|---|---|---|
| 1 | Première installation → ouverture → onboarding complet | aucun écran bloqué, création compte/catégorie/budget cohérente | P0 |
| 2 | Fermeture forcée pendant onboarding puis relance | reprise à l'étape attendue, aucune donnée dupliquée | P0 |
| 3 | Login email + vérification email | connexion, redirection overview/tutorial correcte | P0 |
| 4 | Login Google réel | authentification et création/récupération du profil | P1 |
| 5 | Création/modification/suppression d'une dépense avec réseau réel | données persistées après relance | P0 |
| 6 | Coupure réseau pendant create/update/delete puis reconnexion | UI reste cohérente, synchronisation finale sans doublon | P0 |
| 7 | Modifier une occurrence récurrente passée/milieu/future | choisir « uniquement » ou « et les suivantes », vérifier que l'historique reste inchangé | P0 |
| 8 | Dépenses non débitées des mois précédents au démarrage | bannière d'avertissement visible dès qu'il reste des dépenses antérieures non débitées, total en tête de la bottom sheet, regroupement par période d'origine, actions reporter / débiter sur origine / débiter maintenant cohérentes après traitement | P0 |
| 9 | Changer devise + nombre de décimales + langue | formats affichés partout, après redémarrage | P1 |
| 10 | Photo/avatar : prise/sélection, refus permission, suppression | fallback visuel et permissions OS | P1 |
| 11 | Parcours long sur petit écran + tablette | pas d'overflow, menus/dialogues accessibles, swipe utilisable | P1 |

## Scénarios à ne pas refaire manuellement

Les combinaisons suivantes sont volontairement automatisées :

- CRUD offline des comptes, catégories et dépenses ;
- ordre FIFO et coalescence create/update/delete ;
- backoff et retry forcé ;
- snapshot serveur obsolète contre mutation locale ;
- suppression locale qui ne doit pas être ressuscitée par un refresh ;
- migration des statistiques lors d'un déplacement compte/catégorie ;
- conservation des occurrences débitées lors du versioning récurrent ;
- bornes de dates, mois, récurrences et formats de données ;
- états loading/success/error des Notifiers testables sans service externe.

## Vérification visuelle ciblée

Les goldens couvrent déjà des composants représentatifs. Sur appareil réel, vérifier seulement :

1. iPhone/Android compact : login, overview, formulaire dépense ;
2. écran tablette : overview et category details ;
3. thème clair/sombre ;
4. locale française et anglaise ;
5. clavier ouvert dans les formulaires ;
6. texte long / noms de catégories longs.

Une anomalie visuelle reproductible dans `flutter_test` doit devenir un test widget ou golden plutôt qu'un nouveau point de checklist manuel.


---

## 3. Performance statique et runtime



## Scope

This document records the performance work completed during the refactor. It deliberately distinguishes **static/code-level findings** from **runtime measurements**.

Static analysis (`flutter analyze`) reports **0 issues** as of 2026-09-29. That is evidence of lint/style
compliance, not of coverage or of the absence of complexity. Frame timings, rebuild counts, memory profile and
startup benchmarks are still **not** measured: they require a real device profile, not a headless emulator.

## Static audit completed

### Riverpod rebuild scope

Feature Notifiers were reviewed for listeners attached to entire session objects.

The following expensive recalculation paths are now scoped to the data that can actually affect the feature:

- `PeriodExpenses` listens only to the selected account's expenses and categories.
- `CategoryExpenses` listens only to the selected account's expenses/categories, the selected account color, and the profile fields displayed by the page.
- `UndebitedExpenses` listens only to the profile fields that affect formatting/display instead of every profile mutation.

This prevents unrelated account/category/profile changes from triggering occurrence expansion, category summaries or pagination reconciliation.

### Responsive UI / ScreenUtil

`flutter_screenutil_plus` remains part of the design system.

Its use is intentionally centralized:

- initialization is performed once at the application root;
- spacing/component dimensions use `BudglySpacing` / `BudglyComponentStyles`;
- Material typography is defined centrally in `MaterialTheme`;
- no feature-level direct `ScreenUtilPlusInit` was found;
- tests configure ScreenUtil once in `test/flutter_test_config.dart`.

No replacement with ad-hoc `MediaQuery` sizing was introduced.

### Expensive calculations

The expense occurrence and summary calculators remain pure and deterministic. No speculative memoization or ID index was added: the refactor plan requires measured evidence before introducing another cache/index.

### Persistence/network

The previous checkpoints already addressed the larger known costs:

- batched `SyncQueue` persistence;
- signed URL reuse and concurrent-request deduplication;
- tighter recurring Firestore query bounds;
- narrower undebited-expense history queries.

## Runtime validation required before final release

Run on at least one representative Android phone and one larger/slow device profile:

1. cold startup → first interactive frame;
2. Overview with 1, 10, 100 and 500 expenses;
3. Category Expenses with pagination and recurring expenses;
4. Undebited Expenses with several historical periods;
5. rapid period/account switching;
6. offline → reconnect → sync replay;
7. light/dark mode and font scaling;
8. compact phone and tablet layouts.

Record:

- frame build/raster timings;
- rebuild counts for the major Notifiers/widgets;
- peak memory;
- Firestore/Supabase request counts;
- signed URL request counts;
- startup time.

Only introduce additional caching, indexing, pagination or widget memoization when a measured bottleneck justifies it.


---

## 4. Startup et première frame



## Goal

Budgly should paint its first useful Flutter frame without waiting for services that are not required to render the initial route.

The startup contract is split into two stages:

### First-frame critical

These operations happen before `runApp` because the application dependency graph requires them:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `.env` loading
3. Firebase initialization
4. Supabase initialization
5. creation of the root `ProviderContainer`

The goal is that no domain data fetch, analytics initialization, Crashlytics setup, Google Sign-In setup, or sync replay blocks this stage.

### Deferred after first frame

Started from `addPostFrameCallback`:

- Sync handler registration and sync lifecycle start
- Crashlytics configuration
- PostHog initialization and startup analytics
- Google Sign-In initialization

These tasks are intentionally allowed to complete after the first frame.

## Data hydration rule

`ProfileSession` hydrates local preferences/profile asynchronously. It must not make `main()` wait for profile/network data. A cached profile may be used as soon as available, while remote refresh remains background work.

Feature providers should follow the same rule: render from the current local state first and attach remote refreshes afterwards.

## Audit rule

Do not move work into the critical startup path merely because it is convenient. A new startup dependency must answer:

- Is it required to construct the first route?
- Is it required to render the first frame correctly?
- Can a local/cache value replace the remote result initially?
- Can the operation safely start after `addPostFrameCallback`?

If the answer is no, it belongs in the deferred phase.

## Validation

A real startup benchmark still requires Flutter runtime profiling on representative Android devices. The refactor intentionally does not claim a measured first-frame improvement without that runtime measurement.

## 5. Test-failure remediation checkpoint — 2026-09-20

The uploaded `tests_all.log` was treated as the authoritative baseline for this correction pass.
The failures were classified before changing code or expectations:

- **Incorrect tests:** several recurrence tests used dates outside their declared `[start, endExclusive)` window, expected an occurrence on an exclusive boundary, or retained the old null-ID equality contract.
- **Missing test doubles:** Category Expenses and Revenue tests indirectly built `ProfileSession`, which now reads the injected `AuthService`; the tests now override that dependency instead of touching Firebase.
- **Outdated fakes:** `UndebitedExpensesService` now uses `listExpensesForAccountBefore`, so its fake service was updated to implement the same contract.
- **Real code defect:** `ExpenseOccurrenceException.sourceDate` used an over-escaped regular expression and rejected valid `YYYY-MM-DD` keys.
- **Real sync defect:** a dependency marked blocked before a forced retry remained blocked even after its parent operation succeeded in the same flush. The block is now removed on successful parent completion.
- **Intentional sync semantics:** create→delete is retained as two queue operations. This is deliberate: the create may have reached the server before a process crash/ambiguous response, so cancelling it locally could leave an orphaned remote entity. Tests now assert crash-safe replay semantics.
- **Idempotent recurring split:** when Firestore returns no created object after the split attempt, the preallocated next-expense ID is retained rather than replaced by a new local identity.
- **Integration banner:** the test now injects the same `SyncManager` instance into the widget tree as the integration harness.

The baseline log also contains an Android/Gradle load failure for `offline_crud_roundtrip_test`. That failure is environment/runtime dependent and cannot be validated in the current environment because the Flutter SDK is unavailable here.

The baseline `tests_all.log` is intentionally retained as the input evidence for this checkpoint; it should be regenerated locally after applying these corrections rather than treated as the post-fix result.


## 2026-09-20 — Latest local test baseline remediation

The supplied `tests_all.log` reported **14 unit/widget failures and 2 integration failures**. The failures were classified before changes:

- Model tests had contradictory expectations (`same id` was described as equal but asserted `isNot`).
- Several provider tests allowed `ProfileSession` to reach `AuthService.firebaseUser`, which correctly requires Firebase in production; the tests now provide Firebase-safe auth doubles.
- Sync dependency tests omitted `account_id` from category payloads, contradicting the entity-scoped dependency contract.
- The integration CRUD test instantiated `ExpensesService` outside the normal provider composition root and therefore had to register its sync handler explicitly.

The current archive contains those corrections. The original `tests_all.log` remains the pre-fix evidence and is not rewritten.

## 2026-09-20 — Analyze remediation: force-retry test

The latest local `dart analyze` output contained 17 errors, all caused by stale static/singleton access in `sync_manager_force_retry_test.dart`. The test now owns explicit `SyncQueue` and `SyncManager` instances and invokes instance methods directly. This preserves the production DI contract and removes the need for static test reset APIs.

Validation still needs to be rerun locally with `dart analyze` and the test suite.

## Test runner — full mode output

`dart run tool/test_pyramid.dart full` runs the unit/widget and integration suites with coverage. In `full` mode, successful test output is suppressed; when a suite fails, the runner prints only the failure/error sections and stderr. This keeps `tests_all.log` focused on actionable failures while preserving the coverage merge behavior.
