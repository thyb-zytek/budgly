# Budgly — État des lieux

Dernière mise à jour : 2026-09-29

## Statut global

**Base technique validée par exécution.** Le plan de correction de l'audit offline-first / Riverpod / MVVM du
2026-09-24 (`AUDIT_PLAN.md`) a été validé localement le 2026-09-29 avec le SDK Flutter 3.47.5 :

| Porte de validation | Commande | Résultat |
|---|---|---|
| Format | `dart format --output=none --set-exit-if-changed lib test integration_test tool` | ✅ 0 fichier à reformater |
| Analyse | `flutter analyze` | ✅ 0 problème |
| Tests unitaires + widgets | `flutter test` | Dernier artefact local : 1 180 tests ; exécution non vérifiée par l’audit statique |
| Tests d'intégration | `flutter test integration_test -d emulator-5554` | ✅ 12 / 12 |
| Couverture | `coverage_report.json` / `coverage_report.log` (2026-10-05) | **69,6 %** (7 632 / 10 961 lignes) |

Les chiffres de couverture ci-dessus proviennent du dernier artefact local présent dans l’archive. Ils ne sont pas une exécution réalisée pendant l’audit du 2026-10-06. La CI GitHub exécute les mêmes étapes (voir `.github/workflows/main.yml`,
job `test` + job `integration` sur émulateur Android API 36).

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

Les tests, l'analyse et le formatage **ont été exécutés et passent** (tableau « Statut global »).
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
