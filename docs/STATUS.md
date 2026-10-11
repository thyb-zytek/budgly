# Budgly — État des lieux

Dernière mise à jour : 2026-10-11

## Checkpoint Groupe 1 — issue #34 — validé par exécution le 2026-10-11

Le **Groupe 1** de l'issue #34 (A8, A11, A14, A17 + un seul formulaire actif dans les onglets Settings) a été
implémenté et **validé localement** (Flutter 3.47.7 / Dart 3.13.5) :

| Porte | Commande | Résultat |
|---|---|---|
| Format | `dart format --output=none --set-exit-if-changed lib test integration_test tool` | ✅ 0 fichier à reformater |
| Analyse | `flutter analyze` | ✅ 0 problème (repo entier, état final) |
| Tests unitaires + widgets | `flutter test` | ✅ **1 253 / 1 253** |
| Suites du périmètre (re-lancées après formatage final) | `flutter test test/pages/{overview,category_expenses,undebited_expenses,settings}` | ✅ overview 12/12 · category_expenses 24/24 · undebited 18/18 · settings 61/61 |
| Tests d'intégration | `flutter test integration_test -d emulator-5554` | ⏳ non relancé (émulateur requis) ; dernier résultat connu : 12/12 (2026-09-29) |

Contenu du checkpoint :

- **A8** — dépenses débitées : suppression bloquée côté service (`deleteOccurrence`,
  `deleteSingleOccurrence`, `deleteFutureOccurrences` rejettent les occurrences débitées) et dans l'UI
  (bouton « Supprimer » masqué, menu long limité à « Remise en attente »). Changement de compte depuis
  l'éditeur : non récurrente → déplacement via `updateExpense` (`account_id`), récurrente → toute la série
  change de compte ; la page quitte l'expense et la session la reparente.
- **A11** — getter `isCarriedOver` (report réel uniquement) et badge « Reporté ».
- **A14** — page dépenses non débitées : refresh du service avant `loadAccount` et garde de génération
  `_recomputeGen` + `await _recompute()` (pas de recompute obsolète après une mise à jour plus récente).
- **A17** — Overview restauré à froid : `_initialLoadSkippedForMissingAccount` + écoute de
  `accountSelectionProvider` dans `build()` relancent `loadInitialData()` dès qu'un compte apparaît ;
  test de reproduction ajouté (12/12).
- **Onglets Settings** — un seul formulaire actif : l'édition d'un compte/catégorie remet le brouillon à
  zéro, `cancelEdit` vide brouillon + édition, et l'ajout (ou le changement d'onglet) ferme l'édition en
  cours (dossier `test/pages/settings/`, 61/61).

Point de transparence sur les preuves : le run complet 1 253/1 253 a été exécuté sur la logique finale ;
cinq fichiers (2 prod, 2 tests, 1 outil) ont ensuite été reformatés et les infos de lint restantes du
helper `tool/clean_manual_test_user.dart` ont été corrigées. Ces changements sont mécaniques et ont été
re-vérifiés : format 0 écart, analyse 0 problème, suites du périmètre vertes (chiffres du tableau).

## Statut global

> Le tableau ci-dessous décrit la baseline historique. La révision courante (travail du 2026-10-08 au
> 2026-10-11 inclus) a depuis été validée par exécution : voir « Checkpoint Groupe 1 — issue #34 » ci-dessus.

**Base technique validée par exécution.** Le plan de correction de l'audit offline-first / Riverpod / MVVM du
2026-09-24 (`AUDIT_PLAN.md`) a été validé localement le 2026-09-29 avec le SDK Flutter 3.47.5 :

| Porte de validation | Commande | Résultat |
|---|---|---|
| Format | `dart format --output=none --set-exit-if-changed lib test integration_test tool` | ✅ 0 fichier à reformater |
| Analyse | `flutter analyze` | ✅ 0 problème |
| Tests unitaires + widgets — baseline du 2026-10-06 | `flutter test` | ✅ 1 224 / 1 224 (historique) |
| Tests d'intégration | `flutter test integration_test -d emulator-5554` | ✅ 12 / 12 (2026-09-29, non relancé depuis) |
| Couverture | `coverage_report.json` / `coverage_report.log` (2026-10-06) | **70,6 %** (7 773 / 11 015 lignes) |

Format, analyse et tests unitaires/widgets ont été relancés le **2026-10-06** sur le checkpoint W6/W7 :
0 fichier à reformater, 0 problème d'analyse, **1 224 tests verts** (les 1 180 du 2026-09-29 plus les tests
ajoutés depuis). La suite d'intégration n'a pas été relancée ce jour-là (émulateur requis) ; son dernier
résultat connu reste celui du 2026-09-29.

Les chiffres de couverture ci-dessus proviennent du dernier artefact local présent dans l’archive
(`coverage_report.json` / `.log`, tous deux ignorés par git), généré le 2026-10-06.
La CI GitHub exécute les mêmes étapes (voir `.github/workflows/main.yml`,
job `test` + job `integration` sur émulateur Android API 36).

## Dernier résultat de tests fourni — 2026-10-10 12:33

Le run du checkpoint lots 6/7 fourni par l'utilisateur a rapporté **1 202 / 1 239 tests unitaires/widgets réussis et 37 échecs**. La suite d'intégration a quitté avec le code 1 mais **0 test rapporté** : ce n'est pas un résultat vert et le JSON ne contient pas la sortie console qui permet d'identifier précisément l'échec préalable à l'exécution.

Les correctifs préparés après cette exécution concernent les doubles `AuthService.authStateChanges`, les clients backend de test injectés dans les tests de services et le harnais widget, le `ProviderScope` du harnais widget, les fixtures auth de `ProfileSession`, le test de navigation initiale et la sélection ciblée de préférences de `CategoryView`. Ils n'ont pas été ré-exécutés dans l'environnement d'édition. Voir [`TEST_FAILURE_ANALYSIS_2026-10-10.md`](TEST_FAILURE_ANALYSIS_2026-10-10.md).

**À la date du 2026-10-10 : validation en attente.** Cette phrase décrit l'état du checkpoint lots 6/7 à sa
date. Elle ne décrit plus la révision courante : le run local du 2026-10-11 (1 253 / 1 253, voir le
checkpoint Groupe 1 en tête de document) couvre désormais l'ensemble de la révision. Ne pas présenter la
baseline historique 1 224/1 224 du 6 octobre comme le résultat du checkpoint actuel.

## Offline-first — état après l'audit du 2026-09-24

- Une seule file d'attente par domaine : `SyncQueue`/`SyncManager` pour Supabase (comptes, catégories, profil),
  persistance offline native Firestore pour les dépenses et budgets (plus de double file pour les dépenses).
- Les écritures Firestore ne sont plus attendues par l'appelant (le Future ne se résout qu'à l'ack serveur, donc ne
  se résout jamais hors-ligne) ; un rejet asynchrone du serveur invalide l'état optimiste (`ExpensesService.rejectedWrites`).
- `SyncQueue` fusionne les patchs partiels (profil, avatar en attente) au lieu de les écraser, et met en quarantaine
  les données illisibles plutôt que d'écraser silencieusement la file entière.
- `SyncManager.flush` a une seule boucle de relecture avec passe finale (plus d'op qui attend le prochain cycle de
  5 min), un backoff réellement planifié, et distingue les erreurs permanentes (jamais rejouées par un déclencheur
  automatique) des erreurs transitoires.
- `LocalCache` est unique et sérialise ses lectures-modifications-écritures ; les mutations Supabase enfilent
  d'abord dans la file durable, le cache local n'est qu'un miroir best-effort écrit ensuite.
- La déconnexion ne bloque plus sur une file non vide : flush borné, puis déconnexion. Les opérations restent
  durables et rattachées à l'utilisateur qui les a créées.
- La suppression d'un compte/d'une catégorie déclenche une opération durable `cleanup` (au lieu d'un nettoyage
  fire-and-forget) pour les données Firestore et le dossier de stockage restants côté serveur.

## Architecture

- Flutter/Dart + Riverpod, avec une architecture MVVM pragmatique : UI → Notifier → Service → persistence/remote.
- Riverpod est la frontière de composition et le propriétaire de l'état réactif partagé.
- Firebase Auth ; Firestore pour dépenses/budgets ; Supabase pour comptes, catégories, profils et Storage.
- Offline-first : cache local + SyncQueue pour Supabase, persistance offline native Firestore pour les données Firestore.
- Les services métier n'exposent plus de singletons applicatifs comme API de production.

## Fiabilité / données

- Dates métier traitées comme des dates calendaires, avec plages `[start, endExclusive)`.
- Les récurrences ne peuvent jamais produire d'occurrence avant leur `debitDate`.
- Les mois courts et années bissextiles sont couverts par des tests ciblés.
- Les mutations offline Supabase sont ownership-scoped par utilisateur Firebase.
- Le replay est idempotent sur les opérations auditées ; les opérations ambiguës de split récurrent utilisent un identifiant stable.
- Le logout ne perd plus les mutations critiques en attente (elles restent en file, rattachées à l'utilisateur).

## Démarrage et performance

- Le chemin avant `runApp()` est limité aux dépendances nécessaires au graphe applicatif.
- Analytics, Crashlytics, Google Sign-In et le démarrage du moteur de sync sont différés après le premier rendu lorsque possible.
- Les scopes Riverpod et les usages ScreenUtil ont fait l'objet d'un audit statique.
- **À faire sur appareil réel :** mesurer `main → runApp → first frame → Overview utilisable`, puis auditer les chargements progressifs de l'Overview.

## Produit livré

- Comptes, catégories, dépenses ponctuelles/récurrentes, budgets et revenus mensuels.
- Exceptions et versioning des dépenses récurrentes.
- Gestion des dépenses non débitées et actions de report/débit.
- Auth email/Google, onboarding, préférences, profil et stockage d'image.
- Offline-first et synchronisation.

## Prochaines fonctionnalités produit

La roadmap actuelle est regroupée dans `docs/PRODUCT.md`. Elle couvre notamment Financial Insights, Forecast, saisie express et monétisation Free/Premium.

## Validation

La baseline du 2026-09-29 et le checkpoint W6/W7 du 2026-10-06 ont été exécutés avec succès à leur date.
Le checkpoint lots 6/7 (2026-10-10) était en attente de validation locale à sa date ; il est couvert par
le run du 2026-10-11 (**1 253 / 1 253**, `flutter analyze` 0 problème) décrit dans le checkpoint Groupe 1
ci-dessus.
Le refactor du 2026-09-29 a été validé après correction de trois défauts : un import `AppLogger` manquant dans
`state/profile_providers.dart` (erreur de production), 21 erreurs de compilation dans deux fichiers de test
suite au changement de contrat de `ExpenseFormData` (`debitDate` devenu non-nullable), et un helper de test qui
ne chargeait pas la page avant édition.

Reste à faire pour une release : la campagne manuelle sur appareil réel (`QUALITY.md` §2) et la validation runtime
des performances (startup, frames), qui ne peuvent pas être mesurées sur un émulateur headless.

## Documents de référence

| Thème | Document |
|---|---|
| État actuel | `STATUS.md` |
| Architecture et contrats techniques | `ARCHITECTURE.md` |
| Développement/refactor | `DEVELOPMENT.md`, `REFACTORING.md` |
| Produit/roadmap/business | `PRODUCT.md` |
| Tests/performance/startup | `QUALITY.md` |
| Analytics/crash | `OBSERVABILITY.md` |
| Audit offline-first/Riverpod/MVVM et plan de correction | `AUDIT_PLAN.md` |


## Dernier checkpoint — 2026-09-20

Le dernier `tests_all.log` a été analysé et les corrections ont été appliquées. Les échecs ont été séparés entre contrats de tests obsolètes, fakes incomplets et deux défauts réels corrigés (`sourceDate` des exceptions récurrentes et déblocage des dépendances après retry forcé). Le log fourni reste le **baseline avant correction** ; il doit être régénéré localement pour confirmer le résultat final.


## Dernier checkpoint — correction du baseline de tests local

Le `tests_all.log` fourni avec l'archive indiquait 14 échecs unit/widget et 2 échecs d'intégration. Les corrections portent principalement sur des contrats de tests devenus obsolètes/incomplets et sur les doubles Firebase/Riverpod. Le setup d'intégration enregistre désormais explicitement le handler de synchronisation des dépenses lorsqu'il construit `ExpensesService` directement.

Aucun changement supplémentaire n'a été apporté à la logique de récurrence lors de ce checkpoint.

## Latest validation checkpoint — 2026-09-20

The latest local `dart analyze` identified 17 stale singleton/static references in `sync_manager_force_retry_test.dart`. These were test-only errors caused by the removal of `SyncManager.instance`/static test access. The test was migrated to explicit injected `SyncQueue` and `SyncManager` instances. No production singleton was restored.


## Latest checkpoint — 2026-09-23 — Overview initial-load session reactivity

The first Overview fix correctly removed the stale post-`await` state overwrite,
but testing on a cold-start installation showed that the list could still stay
empty until pull-to-refresh. The remaining issue was that `PeriodExpenses` had
no reactive listener after the initial build, so session updates from the
cache/server revalidation path were not propagated to the provider.

The provider now listens to both `ExpensesSession` and `CategoriesSession`. Its
explicit `load()` sequence remains responsible for the deterministic final
recompute, while listeners keep the provider synchronized with later session
updates. A category-session regression test was added alongside the existing
expense-session test.

Runtime validation for this change was performed on 2026-09-29: the category-session regression test passes.

### Overview data ownership correction (2026-09-23)
- Profile bootstrap now loads accounts, then all account categories, before the loaded profile is exposed to navigation.
- Overview initial loading is reduced to screen data: selected-period expenses (plus existing Overview-specific data such as revenue/undebited expenses).
- This removes the account/category/expense startup race from `PeriodExpenses` and makes its responsibility explicit.

## Dernier checkpoint — 2026-09-23 — Account switching / undebited scope

- Le changement de compte dans l'Overview recharge explicitement les dépenses
  de la période du nouveau compte sélectionné (ainsi que son revenu).
- Les dépenses non-débitées restent chargées sur **tous les comptes** ; le
  compte sélectionné ne sert qu'au filtrage d'affichage de la page dédiée.
- Le chargement initial des dépenses non-débitées est parallélisé entre les
  comptes.
- Un test de régression couvre le rechargement des dépenses lors d'un
  changement de compte.

## Latest checkpoint — 2026-10-06 — W6/W7 UI decomposition

The W6/W7 audit findings were addressed without changing application behavior:
large widget builds were split into named rendering responsibilities, and the
category-expense edit-sheet orchestration was separated from the editor widget
construction. The storage migration `006_rls_security.sql` was renamed to
`006_storage_rls.sql` to reflect that it contains storage RLS policies only.

## Dernier checkpoint — 2026-10-08 — Auth/session + SyncManager hardening

Le chantier de durcissement a supprimé les deux bridges `ChangeNotifier` qui n'avaient plus de raison de rester dans le socle réactif :
- `AuthSessionNotifier` / `AuthSessionRevision` ont été retirés. Firebase `authStateChanges` est désormais la source observée par `ProfileSession`, tandis que `AppRouter` écoute le même flux pour déclencher `GoRouter.refresh()`.
- `SyncManager` n'expose plus d'état réactif via `ChangeNotifier`. Son statut UI est exposé par un `Stream<SyncStatus>` et relayé par `SyncStatusNotifier` (Riverpod).

`ProfileSession` réinitialise désormais toutes les sessions métier lors d'une déconnexion Firebase externe ou d'un changement d'identité, tout en conservant `_sessionRevision` comme garde de concurrence jusqu'à la refonte complète du cycle `load/refresh`.

`ProfileService.refreshFromServer()` passe désormais par le chemin de refresh distant protégé contre les mutations `user_profiles` en attente et contre les réponses provenant d'une ancienne session. Le chemin manuel peut continuer à propager les erreurs, tandis que le refresh background reste tolérant aux erreurs réseau.

Des tests de régression ont été ajoutés pour la déconnexion externe, le refresh du routeur, le flux de statut du sync manager et les courses/erreurs de refresh du profil.

Les optimisations UI évidentes ont aussi commencé : `Overview` et `CategoryView` utilisent des dépendances Riverpod plus granulaires et les `MediaQuery` ciblés utilisent désormais les accesseurs spécialisés.

Le minimum Dart déclaré est maintenant `^3.13.0` et la CI est alignée sur Flutter 3.47.5 / Dart 3.13.4. `.metadata` n'a pas été édité manuellement.

**Validation :** Flutter/Dart n'est pas disponible dans l'environnement d'édition actuel. Cette révision n'a donc pas encore été validée par `dart format`, `flutter analyze`, `flutter test` ou les tests d'intégration. La dernière baseline verte documentée est antérieure à ces changements.

### Lot 3 — Login/profile initialization

Le polling `_waitForProfileLoaded()` (50 tentatives de 100 ms) a été supprimé. `ProfileSession.load()` constitue désormais explicitement la barrière d'attente : lorsqu'il se termine après un chargement valide, le profil est appliqué et les comptes/catégories de référence sont déjà préchargés. Les tests de login utilisent maintenant une identité Firebase simulée afin d'exercer réellement la garde d'UID de `ProfileSession`, et une régression dédiée valide le chargement sans délai arbitraire. `_sessionRevision` reste volontairement en place jusqu'à la refonte complète du cycle de vie.


## Dernier checkpoint — 2026-10-08 — Lot 5 UI/Riverpod hotspots

Le lot 5 a poursuivi le durcissement structurel sans modifier les contrats métier :
- `CategoryExpensesPage` ne construit plus directement son long edit-sheet. L’éditeur est devenu un `ConsumerWidget` dédié qui lit localement les dépendances Riverpod nécessaires et conserve `ExpenseFormController` comme état de formulaire local.
- `CategoriesTab` et `AccountsTab` délèguent désormais leur contenu à des widgets Riverpod dédiés ; les parents conservent uniquement le cycle de vie des contrôleurs/framework et les listeners de synchronisation avec le formulaire.
- `TutorialPage` observe uniquement l’état de navigation (`currentStep`, `totalSteps`, `canGoBack`, `isInitializing`), tandis que `AccountStep` et `CategoryStep` utilisent des sélections ciblées de `TutorialState`.
- `Overview`/`Preferences` ont été resserrés sur les dépendances réellement utilisées, et le résumé Overview sélectionne les champs nécessaires des providers compte/dépenses/revenu.

**Validation :** Flutter/Dart n’est pas disponible dans l’environnement d’édition actuel. Ce checkpoint doit encore être validé avec `dart format`, `flutter analyze`, `flutter test` et les tests d’intégration dans l’environnement de développement/CI.


## Lot 4 — Toolchain / CI determinism (2026-10-09)

- The project baseline is pinned to Flutter 3.47.5 / Dart 3.13.4. `pubspec.yaml` declares Dart `^3.13.0`, and `pubspec.lock` records a Dart lower bound of `3.13.0-0`. Flutter 3.47.5 ships Dart 3.13.4 (official Flutter release metadata).
- Added `tool/verify_toolchain.sh`; the test, integration, and APK-build jobs all fail early if the actual SDK versions or the repository's SDK constraints drift. The workflow has a single version pair in its top-level `env`.
- The CI `.env` and `google-services.json` generation steps pass secret values through step environment variables and `printf`, rather than interpolating secret contents into shell source. Required Supabase/Google service configuration is checked before use.
- Removed the misleading generated-source `git diff` requirement from the quality documentation. Generated Riverpod files remain Git-ignored and are rebuilt in each job.
- `.metadata` was deliberately left tool-managed: its platform `create_revision` / `base_revision` fields are migration history, not a CI SDK pin, and the file explicitly must not be edited by hand. The exact CI/local baseline is enforced by the workflow and verification script instead.

**Validation in this environment:** the version-check script passed against test doubles reporting Flutter 3.47.5 / Dart 3.13.4 and correctly rejected a Dart 3.12.2 mismatch. The GitHub Actions YAML parsed successfully. Flutter/Dart themselves are not installed here, so application formatting, analysis, unit/widget tests, integration tests, and APK build still require local/CI execution.

## 2026-10-10 — Lots 6/7: DI, async races, queue ownership, dependency strategy

- Added `core/dependencies/backend_clients_provider.dart` and wired production service providers to injected Firebase Auth, Firestore, Supabase and Google Sign-In clients. Constructor fallbacks remain for direct tests/isolated usage.
- Profile-cache remote revalidation now uses per-user mutation revisions and a serialized cache-write path, including mutations made while a remote request is in flight. `savePreferences` marks the revision before its first `await`.
- Profile loading futures are keyed by Firebase UID so an in-flight load for one user is not reused for another identity. `ProfileSession` also observes initial Firebase auth restoration separately from a true identity switch.
- Accounts/Categories/Expenses/AccountBudgets guard in-flight loads and revalidation callbacks after `clear()` or account invalidation.
- Legacy SyncQueue entries without `owner_user_id` remain untouched while signed out. The first authenticated queue read assigns them to the current user and persists that ownership; later users cannot claim/replay those entries. This is the explicit migration policy chosen for this project and is covered by queue tests.
- Added deterministic regression test cases covering stale completion after session clearing, auth sign-out during reference-data preload, legacy ownerless queue migration (signed-out preservation, first authenticated claim, persisted ownership), and a profile mutation racing a remote refresh.
- Added `docs/DEPENDENCY_UPGRADE_PLAN.md`. Package constraints/lock versions are intentionally unchanged: compatible upgrades and major migrations are separate checkpoints.

**Validation status:** a lightweight delimiter scan on 21 changed Dart files, YAML parsing and `bash -n tool/verify_toolchain.sh` passed. This is not a Dart compiler. Flutter/Dart are unavailable in this environment; `dart format`, `flutter analyze`, unit/widget/integration tests and APK build remain required locally/CI.
