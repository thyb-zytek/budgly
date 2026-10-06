# Budgly — Plan de correction (audit du 2026-09-24)

> Fichier de suivi. Mis à jour à la fin de chaque étape.
> **Validé par exécution le 2026-09-29** (Flutter 3.47.5) : `dart format` ✅ 0 écart, `flutter analyze` ✅ 0 problème,
> `flutter test` ✅ 1180/1180, `flutter test integration_test -d emulator-5554` ✅ 12/12, couverture **68,8 %**.
> **Ré-exécution le 2026-10-06** (checkpoint W6/W7) : `dart format` ✅ 0 écart, `flutter analyze` ✅ 0 problème,
> `flutter test` ✅ 1224/1224 ; intégration non relancée (émulateur requis).
> Une étape « ✅ » signifie désormais *code + tests + docs modifiés **et** validés par exécution*.

Légende : ⬜ à faire · 🔧 en cours · ✅ fait et validé par exécution · ⏸ reporté (raison indiquée) · ❌ abandonné

## Vue d'ensemble

| Phase | Sujet | Statut |
|---|---|---|
| 1 | Moteur de sync (SyncQueue / SyncManager) | ✅ |
| 2 | Services Supabase : comptes, catégories, profil, LocalCache | ✅ |
| 3 | Dépenses Firestore : une seule file d'attente | ✅ |
| 4 | Logout non bloquant et cascades durables | ✅ |
| 5 | Riverpod / MVVM : correctifs de sûreté | ✅ |
| 6 | Tests, documentation, CI | ✅ (validé 2026-09-29 : 1180 unit + 12 intégration) |
| 7 | Chantiers structurels — X3, X5, X6 faits ; X1/X2 ouverts ; X7/X8 ouverts | 🔧 |

## Phase 1 — Moteur de sync

| ID | Audit | Tâche | Statut |
|---|---|---|---|
| S1 | P0-3, P0-6 | `SyncQueue.enqueue` : fusionner les payloads `update`+`update` et `create`+`update` au lieu de remplacer (patchs partiels du profil, `_local_picture_*`) | ✅ |
| S2 | P1-12 | File corrompue : mise en quarantaine du blob brut, décodage item par item, plus d'écrasement silencieux | ✅ |
| S3 | tests/AGENTS | Supprimer `SyncQueue.instance` (tests migrés vers des instances explicites) | ✅ |
| S4 | P1-7 | `SyncManager.flush` : passe finale si une op arrive pendant une passe ; une seule passe à la fois ; `_flushHandle` fiable pour `waitForIdle` | ✅ |
| S5 | P1-8 | Retry planifié à la plus proche `nextAttemptAt` (le backoff devient effectif) | ✅ |
| S6 | P1-9 | Classification des erreurs (transitoire / permanente) ; op permanente = visible tout de suite, jamais supprimée, pas rejouée par timer/resume | ✅ |
| S7 | P1-7 | `syncManagerProvider` : `ref.onDispose` (arrêt du timer et de l'observer) | ✅ |

## Phase 2 — Services Supabase et LocalCache

| ID | Audit | Tâche | Statut |
|---|---|---|---|
| D1 | P1-11 | `LocalCache` unique (provider) avec verrou et mutation atomique (`update…`) ; revalidation et mutations sérialisées | ✅ |
| D2 | P1-12 | `LocalCache` : erreur de décodage → `null` (retour au serveur) + quarantaine, plus de `[]` | ✅ |
| D3 | P0-5 | Comptes / catégories / profil : **enqueue avant cache**, erreur d'enqueue propagée (plus avalée) | ✅ |
| D4 | P0-4 | `_mergePending*` : filtre par `ownerUserId`, deletes toujours appliqués (comptes et catégories) | ✅ |
| D5 | P0-6 | Avatar : nom de fichier relatif (pas de chemin absolu), garde nom/`picture`, suppression du fichier local après upload | ✅ |
| D6 | P1-14 | `updateProfile` : ligne absente ≠ succès | ✅ |
| D7 | Riverpod | Services : `LocalCache` injecté par provider, `ref.watch` dans les providers de services *(partiel : les replis `FirebaseAuth.instance` / `AccountSupabase()` par défaut restent, ils servent aux tests ; voir X3)* | ✅ |

## Phase 3 — Dépenses Firestore

| ID | Audit | Tâche | Statut |
|---|---|---|---|
| E1 | P0-1 | Écritures Firestore **non attendues** (create/update/delete/split) ; rejet asynchrone → rollback + rafraîchissement | ✅ |
| E2 | P0-2 | Plus d'enqueue `expenses` dans SyncQueue ; handler conservé uniquement pour drainer les ops héritées | ✅ |
| E3 | P1-13 | Cache vide hors-ligne : lecture `serverAndCache`, pas d'attente du timeout | ✅ |

## Phase 4 — Logout et cascades

| ID | Audit | Tâche | Statut |
|---|---|---|---|
| L1 | P1-9 | `signOut` : flush borné puis déconnexion **sans bloquer** (les ops restent scopées par owner) — réalisé en phase 2 | ✅ |
| L2 | P1-10 | Suppression compte / catégorie : nettoyage Firestore + Storage via op durable `cleanup` (requête serveur, pas `Source.cache`) | ✅ |

## Phase 5 — Riverpod / MVVM

| ID | Audit | Tâche | Statut |
|---|---|---|---|
| R1 | Riverpod | Garde `ref.mounted` après chaque `await` dans les 5 notifiers concernés | ✅ (ré-audité le 2026-10-06) |
| R2 | Riverpod | `CategoryExpenses._syncFromExternalChanges` : ne plus dépendre du `==` par id | ✅ |
| R3 | Riverpod | `AccountsSession.load` : tri cohérent avec `setAccounts` | ✅ |
| R4 | MVVM | `ProfileService` : ne plus construire ses dépendances par défaut | ✅ |

## Phase 6 — Tests, docs, CI

| ID | Tâche | Statut |
|---|---|---|
| T1 | Tests des correctifs (voir liste ci-dessous) | ✅ |
| T2 | Adapter les tests obsolètes (queue expenses, logout bloquant, tautologie `offline_conflict_policy_test`) | ✅ |
| T3 | Docs : `architecture.md`, `STATUS.md`, `QUALITY.md`, `REFACTORING.md` | ✅ |
| T4 | **Actions à faire chez vous** : `dart format`, `build_runner`, `analyze`, `flutter test` | ✅ fait le 2026-09-29 |

## Phase 7 — Chantiers structurels (décision requise)

| ID | Sujet | Statut |
|---|---|---|
| X1 | Sessions en `AsyncNotifier` et dépendance à l'auth (`ref.watch`) à la place de `_sessionRevision` et des `.clear()` manuels | ⏸ à prioriser |
| X2 | Dépenses en `StreamProvider` sur snapshots Firestore (suppression de `ExpensePeriodCache`) | ⏸ à prioriser |
| X3 | `ImageService` sorti de `services/` (UI) ; `ProfileService` scindé (orchestration du logout dans un notifier) | ✅ |
| X4 | ~~`connectivity_plus` comme déclencheur de sync~~ | ❌ **abandonné** |
| X5 | Version de schéma de `LocalCache` | ✅ |
| X6 | Exceptions de récurrence en last-write-wins multi-appareils | ✅ décision prise : conservé tel quel |
| X7 | Indicateur « N modifications en attente » | ⏸ à prioriser |
| X8 | Lints stricts (`strict-casts`, `unawaited_futures`, …) | ⏸ à prioriser |

### X5 — fait (2026-09-25)
- `LocalCache` : toutes les clés embarquent désormais un numéro de schéma (`offline.v1.accounts.`, etc., même
  principe que `SyncQueue`'s `.v2`). Une entrée écrite sous un ancien schéma devient invisible à la lecture
  (`load...` renvoie `null`, comme au premier lancement) plutôt que risquer un décodage silencieusement erroné
  d'une donnée périmée — une garantie plus forte que la gestion de corruption par lecture (qui ne rattrape qu'un
  décodage qui lève une exception).
- `purgeObsoleteCacheEntries()` : nettoyage best-effort des clés laissées par un schéma antérieur, à appeler une
  fois au démarrage. **Bug intercepté avant livraison** : ma première version balayait toute clé préfixée
  `offline.` hors namespace courant, ce qui aurait aussi supprimé les données de `SyncQueue`
  (`offline.pending_sync.v2`, préfixe différent mais commençant aussi par `offline.`). Corrigé avec une liste
  explicite de préfixes obsolètes connus (`_obsoletePrefixes`), documentée pour être complétée à chaque futur bump
  de version — plus sûr qu'un filtre générique.
- Câblé dans `sync_bootstrap_provider.dart` (`unawaited`, jamais sur le chemin du premier rendu).
- Tests : `local_cache_schema_version_test.dart` (nouveau — couvre explicitement la régression SyncQueue ci-dessus),
  `local_cache_test.dart` adapté (clés littérales `offline.accounts.*` → `offline.v1.accounts.*`, etc.).

### X6 — décision produit prise (2026-09-25)
- **Décision : garder le comportement last-write-wins actuel.** Deux appareils qui modifient offline des
  exceptions différentes de la même série récurrente : celui qui synchronise en second écrase le tableau
  `occurrenceExceptions` de celui qui a synchronisé en premier (`occurrenceExceptions` est réécrit en entier à
  chaque update, pas fusionné champ à champ).
- Aucun changement de code fonctionnel : uniquement un commentaire ajouté sur le champ `Expense.occurrenceExceptions`
  pour que ce point ne soit plus jamais remonté comme un "trou" dans un futur audit — c'est un choix assumé, pas un
  oubli.
- Si ce choix doit être révisé plus tard (edge case client réel, multi-appareil plus fréquent qu'anticipé), la piste
  technique reste : fusionner par date d'occurrence au lieu de remplacer tout le tableau, dans
  `ExpensesService` (`modifySingleOccurrence`/`deleteSingleOccurrence`/`deleteFutureOccurrences`, autour des lignes
  340-620) et dans `RecurringExpenseVersioning`.

### X4 — abandonné (2026-09-25)

Discuté et écarté : le timer périodique (5 min) est déjà un filet de sécurité nécessaire même avec `connectivity_plus`
(la lib indique « associé à un réseau », pas « a un accès Internet réel » — portail captif, wifi mort, etc. — donc
elle ne peut être qu'un signal de plus, jamais remplacer le timer). Le trigger `resume` ne peut pas non plus être
remplacé par le stream de connectivité (pas de garantie d'événement délivré pendant que l'app est en arrière-plan).
Le seul gain réel aurait été de réduire, dans un cas rare, un délai déjà borné à 5 minutes maximum — sans impact
produit mesurable pour une app de suivi de dépenses. Conclusion : nouvelle dépendance, complexité et surface de test
en plus, pour un gain insignifiant. Ne pas revisiter sans un cas d'usage concret qui change cette analyse.

### X3 — fait (2026-09-25)
- `services/image/image_service.dart` supprimé, scindé en deux fichiers cohérents avec leur couche :
  - `shared/ui/widgets/image/account_image_picker.dart` (`AccountImagePicker`) : tout ce qui dépendait de
    `BuildContext`/`Theme`/l10n (sélection galerie + rognage en cercle).
  - `services/image/local_image_store.dart` (`LocalImageStore`) : le seul morceau réellement service-layer
    (copie de fichier pure, aucune dépendance UI).
  - 4 appelants migrés : `pages/tutorial/widgets/account_step.dart`, `pages/settings/accounts/tab.dart`,
    `shared/domain/widgets/accounts/account_form.dart`, `services/image/account_image_helper.dart`.
- `ProfileService` ne construit plus `AccountsService`/`CategoriesService`/`ExpensesService`/`AccountBudgetsService`
  par défaut : ces 4 dépendances sont retirées entièrement de son constructeur (aucun site d'appel, prod ou test, ne
  les utilisait explicitement — vérifié par recherche avant suppression). `signOut()` ne fait plus que auth + flush.
- **Trouvaille en cours de route** : `CategoriesSession.clear()`, `ExpensesSession.clear()` et
  `AccountBudgetsSession.clear()` appelaient déjà `invalidateCache()` sur leur service — seul
  `AccountsSession.clear()` ne le faisait pas (incohérence, pas volontaire). Corrigé pour aligner les 4 sessions sur
  le même pattern, plutôt que d'ajouter un appel dupliqué dans `ProfileSession.signOut()`. Au final `signOut()` ne
  fait plus qu'appeler `.clear()` sur les 4 sessions — c'est plus simple qu'avant mon changement, pas juste déplacé.
- Tests : `profile_session_signout_test.dart` (nouveau, bout-en-bout), `accounts_session_test.dart` enrichi
  (vérifie que `clear()` invalide aussi le cache du service).

## Journal

### 2026-09-28 — recoupement avec deux audits externes (ChatGPT, rapport « Space bunny »)
Chaque affirmation a été vérifiée contre le code réel, pas reprise telle quelle.
- **Corrigé** : `UndebitedExpenses` créait son propre `LocalCache()` et son service en créait un second (jamais passé
  au constructeur) : trois instances au lieu de l'instance partagée `localCacheProvider`. Aucun verrou n'était
  contourné (seules les clés de bannière étaient touchées) mais le contrat « instance unique » était violé. Test de
  régression ajouté (`dismiss` doit passer par l'instance injectée).
- **Corrigé** : `analytics.track('screen_viewed')` retiré de la phase synchrone de `CategoryExpenses.build()`.
- **Corrigé** : `UserProfileSupabase` accepte `FirebaseAuth` injecté (rafraîchissement de jeton sur erreur JWT), test ajouté.
- **Corrigé** : `offline_id.dart` (une seule ligne, non conforme à `dart format`) reformaté, `Random.secure()`.
- **Déjà corrigé avant les rapports** : `AccountBudgetFirestore` non injectable (le rapport 2 le décrit encore ainsi) ;
  « deux files pour les dépenses » (obsolète depuis la phase 3).
- **Affirmation erronée du rapport 2** : « cache des dépenses répliqué dans `LocalCache` » — `LocalCache` ne contient
  ni dépenses ni budgets (vérifié).
- **Déjà satisfait** : personne hors de `services/expenses/` ne connaît `ExpensePeriodCache`.
- **Mis à jour le 2026-10-06** : l'archive courante contient `supabase_migrations/` ; une migration dédiée
  `008_enable_core_rls.sql` active désormais RLS sur `user_profiles`, `accounts` et `categories`. Les tests
  d'architecture RLS lisent les migrations au lieu de vérifier uniquement des chaînes littérales. Un test cross-user
  contre une vraie instance Supabase reste nécessaire pour valider le comportement distant.
- **Confirmé, corrigé le 2026-10-06** : `TextEditingController` a été retiré de `ExpenseEditingData` et reste
  désormais détenu par `ExpenseFormController` ; `profileServiceProvider` dans `state/` (32 fichiers importent ce
  fichier) ;
  `getExpenseById` en O(n) ; client id Google en dur (configuration, pas un secret) ; fallbacks `?? X.instance`
  optionnels restants (`AccountsService`, `AuthService`, providers Supabase, `Supabase.instance.client`) ;
  `CategoryExpenses`/`UndebitedExpenses` volumineux.

### 2026-09-27 — comblement des branches catch/finally restantes (ViewModels)
- `category_expenses_provider_error_paths_test.dart` : `loadMore` (succès première page, échec première page
  sans/avec repli local sur `ExpensesSession` — ce dernier scénario est directement le cas offline visé par
  l'audit, jamais testé jusqu'ici —, échec sur une page suivante qui ne doit *pas* remonter en erreur écran),
  `saveEditing` (succès, déplacement de catégorie, échec), `deleteOccurrence` (échec), `deleteSingleOccurrence`
  routé par `_deleteRecurring` (succès avec republication des occurrences après exception d'occurrence, échec),
  `toggleDebited` (échec).
- `categories_settings_provider_error_paths_test.dart` : `loadCategories` (succès, échec réseau classé comme
  simple hors-ligne et non comme erreur écran, échec non-réseau qui lui remonte comme erreur), `removeCategory`
  (échec), `createCategory` (succès, échec qui conserve le brouillon local pour permettre une nouvelle tentative),
  `updateCategory` (succès, échec).
  **Piège trouvé et évité** : `selectAccount` déclenche son propre `loadCategories()` en arrière-plan si le compte
  n'est pas déjà marqué chargé — mes premiers tests appelaient aussi `loadCategories()` explicitement juste après,
  créant une vraie course entre les deux appels. Corrigé en pré-chargeant `CategoriesSession` avant chaque
  scénario, pour que `selectAccount` ne déclenche jamais cet appel implicite.
- `profile_settings_provider_error_paths_test.dart` : `loadUser` (succès, échec), `onChangeName` (succès avec
  mise à jour de `ProfileSession`, échec sans effet de bord), `refreshUser` (branche hors-ligne — mutations en
  attente non synchronisées → échec sans toucher aux données locales, conformément au contrat offline-first).
  Le succès complet de `refreshUser`/`loadUser` (qui enchaîne comptes + catégories + profil) n'est pas testé ici :
  la mise en place de tous les faux services nécessaires dépasse le rapport effort/gain pour cette passe.
- Comme toujours : vérification d'équilibre syntaxique par tokenizer dédié sur chaque fichier avant livraison,
  aucune exécution réelle possible dans cet environnement.

### 2026-09-26 (suite) — comblement des trous de couverture account_budgets
- **Trouvaille en cours de route, corrigée** : `AccountBudgetFirestore` utilisait `FirebaseFirestore.instance` /
  `FirebaseAuth.instance` en dur — signalé dans mon tout premier audit ("DI incomplète") mais jamais corrigé dans
  les phases précédentes. C'est la cause directe des 15,1 % de couverture sur ce fichier : impossible à tester
  isolément sans un vrai Firebase. Rendu injectable (constructeur `{FirebaseFirestore? firestore, FirebaseAuth?
  auth}`), même pattern que `ExpenseFirestore`. Rétrocompatible (params optionnels, aucun site d'appel cassé).
- Nouveau `test/services/providers/firestore/accounts_budget_firestore_test.dart` : premier test de ce fichier
  utilisant `fake_cloud_firestore` (déjà une dépendance du projet), exerçant la vraie logique de requête/écriture
  (`get`, `setRevenue` en merge, `getMostRecentWithRevenue`, `deleteByAccountId` avec `source`/`awaitAck`).
- Nouveau `test/services/budget/account_budgets_service_mutations_test.dart` : complète le test de revalidation
  existant avec les mutations (`setRevenue` non bloquant + persistance en tâche de fond + invalidation du cache
  d'héritage de revenu, `deleteByAccountId` best-effort local vs `purgeByAccountId` serveur pour le cleanup durable).
- **Deux bugs trouvés et corrigés dans mes propres tests avant livraison**, tous deux via une vérification
  d'équilibre syntaxique dédiée (accolades/parenthèses, en excluant correctement chaînes et commentaires par un
  vrai tokenizer une passe, après que deux tentatives de vérification plus rapides aient donné de fausses alertes
  ou, pire, un faux négatif) :
  1. `_RecordingProvider` surchargeait `get()` au lieu de `getMostRecentWithRevenue()` — la méthode réellement
     appelée par `getMostRecentRevenue`. Sans correction, le test aurait tenté de joindre un vrai singleton
     Firebase non initialisé.
  2. Une apostrophe non échappée dans un nom de test (`"... account's own documents"`) aurait cassé la chaîne
     littérale à la compilation — repéré uniquement grâce au tokenizer dédié après que deux vérifications plus
     rapides (comptage brut, puis regex naïve d'exclusion de chaînes) se soient trompées dans les deux sens sur ce
     cas précis.
- Non fait : `category_expenses_provider.dart`/`categories_settings_provider.dart`/`profile_settings_provider.dart`
  n'ont toujours que le scénario de dispose testé, pas les autres branches catch/finally (succès, erreurs
  classées réseau vs autre, etc.).

### 2026-09-26 — retour utilisateur : analyze propre, tests verts, couverture régénérée
- L'utilisateur a corrigé `flutter analyze` et les tests cassés par mon travail, puis régénéré `coverage_report.json/log`.
  `flutter test` est confirmé **entièrement vert**.
- Diff vérifié fichier par fichier contre ma dernière livraison :
  - **Une vraie erreur de ma part, corrigée par l'utilisateur** : en phase 3, une expression régulière trop large
    appliquée sur plusieurs fichiers de test à la fois (destinée à retirer `syncManager`/`syncQueue` des faux
    `ExpensesService`, qui n'en ont plus besoin) a aussi supprimé ces paramètres de faux `AccountsService`/
    `CategoriesService`/`ProfileService` présents **dans les mêmes fichiers**, qui en ont toujours besoin. ~10
    fichiers de test cassés, tous corrigés par l'utilisateur en réinjectant `testSyncManager`/`testSyncQueue`.
  - Deux corrections plus fines et indépendantes de mon erreur, bien trouvées : `AuthService.signOut()` appelle un
    `GoogleSignIn` réel non mockable dans `profile_session_signout_test.dart` (fixé avec un `_FakeAuthService`) ;
    un deadlock potentiel entre le verrou de `testSyncQueue` partagée et la zone `fakeAsync` d'un widget test dans
    `accounts_tab_test.dart` (fixé avec une `SyncQueue()` locale).
  - Le reste : nettoyages triviaux (`const`, imports inutilisés, `required this.x`, normalisation `dart format`).
- Couverture : 64,2 % → 64,7 % (global). Détail par fichier revu : `accounts_service.dart` 28 %→56,8 %,
  `sync_bootstrap_provider.dart` absent→73,3 %, moteur de sync (`sync_queue`/`sync_manager`/`local_cache`) 95-98 %,
  `deletion_cleanup_service.dart` 75 %. Mais asymétrie relevée : `categories_service.dart` seulement 38,6 % (pas
  d'équivalent à `accounts_service_mutations_test.dart`), `profile_service.dart` 33,3 %, `sync_error_classifier.dart`
  0 %, et les branches ajoutées par les gardes `ref.mounted` (phase 5) non exercées.
- **Comblé dans la foulée** (voir tests ci-dessous) : `categories_service_mutations_test.dart` (symétrique aux
  comptes), `profile_service_mutations_test.dart` (dont un test bout-en-bout du scénario P0-3 — onboarding puis
  préférences hors-ligne — à travers `ProfileService` réel, pas seulement au niveau `SyncQueue`),
  `sync_error_classifier_test.dart` (test direct de `isPermanentSyncError`, jusque-là seulement exercé
  indirectement via un classificateur bouchonné), `ref_mounted_dispose_regression_test.dart` (4 scénarios de
  dispose pendant un `await` en cours, un par notifier corrigé en phase 5 : `CategoryExpenses.loadMore`,
  `AccountsSettings.loadAccounts`, `CategoriesSettings.loadCategories`, `ProfileSettings.changePassword`).
- Non fait : pas de test symétrique pour `account_budgets_service.dart`/`providers/firestore/accounts_budget.dart`
  (15-44 % de couverture) ni pour `category_expenses_provider.dart`/`categories_settings_provider.dart`/
  `profile_settings_provider.dart` au-delà du seul scénario de dispose — à traiter si vous le souhaitez.

_(complété au fil des étapes)_

### Phase 1 — Moteur de sync ✅
- `sync_queue.dart` : fusion des payloads (update+update, create+update), quarantaine des blobs/entrées illisibles
  (`offline.pending_sync.v2.corrupt.<ts>`, 3 conservés), champs `permanent`/`lastError`, `allForOwner`, `backoffFor`,
  `applyBatch(permanentFailures:)`, suppression de `SyncQueue.instance`.
- `sync_manager.dart` : boucle de drain unique (`_drain`) avec passe finale (`_dirty`), `flush(retryPermanent:)`,
  retry planifié sur la plus proche `nextAttemptAt` future (pas de boucle active sur les ops bloquées),
  état « stuck » limité à l'utilisateur courant, `dispose()` sûr.
- Nouveau `sync_error_classifier.dart` (Postgrest 22/23/42, FirebaseException ciblées, FormatException/TypeError).
- `sync_manager_provider.dart` : `ref.onDispose`, `ref.watch` des dépendances. **`sync_manager_provider.g.dart`
  doit être régénéré** (`build_runner`) car le corps du provider a changé.
- `sync_issue_banner.dart` : le retry manuel rejoue aussi les ops permanentes.
- Tests : `sync_queue_merge_and_recovery_test.dart`, `sync_manager_flush_loop_test.dart` (nouveaux) ;
  les 3 tests qui utilisaient `SyncQueue.instance` utilisent `SyncQueue()`.
- Non couvert par un test automatique : la connectivité réelle ; le test de retry planifié attend ~2 s en temps réel.

### Phase 2 — Services Supabase et LocalCache ✅
- `local_cache.dart` : verrou interne, `updateAccounts` / `updateCategories` (lecture-modification-écriture atomique,
  `null` = ne rien écrire), décodage impossible → quarantaine `<clé>.corrupt` + `null` (plus de `[]`).
- Nouveau `local_cache_provider.dart` : instance unique injectée dans comptes, catégories, profil.
- `accounts_service.dart` / `categories_service.dart` / `profile_service.dart` : **enqueue d'abord, cache ensuite**
  (miroir « best effort »), erreur d'enqueue **propagée** ; revalidation = merge + écriture cache atomiques ;
  merge des ops en attente pur, filtré par `ownerUserId`, deletes toujours appliqués (comptes) / par id (catégories).
- Avatar : payload `_local_picture_name` (nom relatif, résolu dans le dossier documents), ancien `_local_picture_path`
  toujours lu ; l'upload est ignoré si le compte ne référence plus ce fichier ; copie locale supprimée après upload
  (aussi dans `AccountImageHelper` en cas de succès direct).
- `ProfileService.signOut` : flush borné (15 s) puis déconnexion **sans bloquer** ; les ops restent durables et
  scopées par owner (`analytics: logout_with_pending_sync`). (Cela réalise aussi L1.)
- `user_profiles.dart` : `updateProfile` lève `ProfileNotProvisionedException` si aucune ligne n'est modifiée.
- Tests : `accounts_service_mutations_test.dart` (nouveau), `local_cache_test.dart`, `logout_sync_contract_test.dart`
  et `supabase_providers_test.dart` adaptés.
- Les providers annotés modifiés (`accounts_service_provider`, `categories_service_provider`, `profile_providers`,
  `sync_manager_provider`) exigent un `build_runner` (hash des `.g.dart`).

### Phase 5 — Riverpod / MVVM ✅
- **Correction du périmètre R1** : `undebited_expenses_provider.dart` avait en réalité déjà un garde équivalent
  (`_disposed`, vérifié après chaque `await` avant chaque `state=`) — la « 0 garde » du premier audit venait d'un
  grep littéral sur `ref.mounted` qui ne détectait pas ce pattern maison. Aucune modification nécessaire sur ce
  fichier ; corrigé dans les 4 autres : `category_expenses_provider.dart` (5 méthodes : `loadMore`, `saveEditing`,
  `deleteOccurrence`, `_deleteRecurring`, `toggleDebited`), `settings/accounts/accounts_settings_provider.dart`
  (`loadAccounts`, `removeAccount`/`_cleanupDeletedAccount`, `createAccount`, `updateAccount`),
  `settings/categories/categories_settings_provider.dart` (5 méthodes), `settings/profile/profile_settings_provider.dart`
  (5 méthodes).
- **R2** : `CategoryExpenses._syncFromExternalChanges` comparait avec `!=` (opérateur `==` d'`Expense` basé sur l'id
  seul → toujours faux dans ce contexte → aucune modification externe n'était jamais propagée). Remplacé par
  `!identical(...)` : `ExpensesSession.getExpenseById` renvoie l'instance réellement stockée en state, donc l'identité
  détecte correctement un remplacement, sans faux positif en régime stable.
- **R3** : `AccountsSession.load` ne triait pas alors que `setAccounts`/`updateLocal` trient par nom — la liste se
  réordonnait après la première revalidation en arrière-plan. `load()` route maintenant par `setAccounts` (une seule
  logique de tri). Test `accounts_session_test.dart` adapté (il documentait l'ancien bug comme comportement voulu).
- **R4** : réduit au correctif déjà fait en phase 2 (partage du `LocalCache` entre les dépendances de repli de
  `ProfileService`). La refonte complète (rendre tous les paramètres obligatoires, retirer les constructions par
  défaut) est repoussée en **X3** : c'est un changement de signature public qui casserait potentiellement plusieurs
  sites d'appel de test sans pouvoir être vérifié par compilation ici — risque jugé disproportionné par rapport au
  gain de fiabilité (la production ne passe déjà jamais par ces branches de repli, `profile_providers.dart` fournit
  systématiquement tous les paramètres).
- `sync_manager_provider.dart` : commentaire périmé corrigé (`SyncStatusNotifier` est déjà consommé par
  `sync_issue_banner.dart`, ce n'était plus « un futur widget »).

### Phase 6 — Tests, docs, CI (partiel — T4 à votre charge)
- `ARCHITECTURE.md` : section sync enrichie (classification des erreurs, cleanup durable, logout non bloquant,
  écritures Firestore non attendues). Le passage sur « pas de seconde file pour les dépenses » n'a pas eu besoin
  d'être changé : il décrivait déjà le comportement voulu, c'était le **code** qui le contredisait (corrigé phase 3).
- `STATUS.md` : section « Offline-first — état après l'audit » ajoutée, renvoi vers `AUDIT_PLAN.md`.
- `QUALITY.md` : section 0 ajoutée, listant les nouveaux tests offline-first et leur non-exécution locale.
- **T4 reste entièrement à faire chez vous** (voir la checklist en tête de ce fichier) : `build_runner`, `dart format`,
  `dart analyze`, `flutter test`. Rien de tout ce plan n'a été compilé ni exécuté.

### Phase 3 — Dépenses Firestore ✅
- `expense_sync_handler.dart` réécrit : `create/update/delete` **non attendus** (le Future Firestore ne se résout qu'à
  l'ack serveur) ; un rejet asynchrone efface l'état optimiste et notifie `ExpensesService.rejectedWrites`.
  `handlePendingSync` ne sert plus qu'à **drainer les ops `expenses` héritées** (un timeout = remis à la file native).
- `recurring_expense_persistence.dart` : le split reste **un seul batch atomique** Firestore, plus de rejeu en 2 ops.
- `expenses_service.dart` : constructeur sans `syncManager`/`syncQueue` ; `deleteExpense` ne bloque plus hors-ligne ;
  cache vide → lecture `Source.serverAndCache` (réponse immédiate hors-ligne), `releaseConfirmed` seulement pour une
  vraie réponse serveur.
- `sync_bootstrap_provider.dart` : abonnement à `rejectedWrites` → rechargement du compte dans `ExpensesSession`.
- Nouveau `test/helpers/offline_expense_firestore.dart` : fake fidèle au SDK (écriture locale immédiate, Future en
  attente jusqu'à l'ack, lecture serveur en échec hors-ligne, rejet possible).
- Tests : `expense_offline_writes_test.dart` (nouveau), `recurring_expense_persistence_test.dart` (réécrit),
  `integration_test/offline_crud_roundtrip_test.dart` (réécrit), `offline_sync_recovery_test.dart` et
  `offline_logout_recovery_test.dart` adaptés, ~9 faux `ExpensesService` migrés, `PendingWriteExpenseFirestore`
  corrigé (create non acquitté = Future pendant, pas `null`).
- ⚠ Les tests existants qui s'appuyaient implicitement sur l'ancien fallback (échec d'écriture → op en queue)
  ont été adaptés à la lecture du code, pas exécutés : à valider en priorité.

### Phase 4 — Logout et cascades ✅ (L1 réalisé en phase 2)
- Nouveau `services/cleanup/deletion_cleanup_service.dart` : opération durable `cleanup` (type `account` / `category`),
  enfilée par `AccountsService`/`CategoriesService` **après confirmation serveur** de la suppression (jamais avant,
  pour ne pas nettoyer un compte dont la suppression pourrait encore échouer).
- `ExpenseFirestore.deleteByAccountId/deleteByCategoryId` et `AccountBudgetFirestore.deleteByAccountId` acceptent
  `source` (le nettoyage durable interroge le **serveur**, pas seulement le cache local) et `awaitAck: false`
  (suppression locale immédiate, non bloquante hors-ligne) ; découpage en lots de 400 (limite Firestore de 500
  écritures/batch).
- `StorageSupabase.deleteFolder(throwOnFailure:)` : le nettoyage durable détecte l'échec et réessaie au lieu de
  l'avaler silencieusement.
- `ExpensesService`/`AccountBudgetsService` exposent désormais deux méthodes : `deleteByAccountId`
  (best-effort local, non bloquant, appelé au moment de la suppression) et `purgeByAccountId` (serveur, utilisé par
  le nettoyage durable).
- `accounts_settings_provider.dart` : le nettoyage immédiat ne fait plus `deleteAccountFolder` en direct (délégué au
  nettoyage durable) ; les deux appels restants ne bloquent plus l'écran hors-ligne.
- `sync_bootstrap_provider.dart` enregistre le handler `cleanup`.
- Tests : `deletion_cleanup_service_test.dart` (nouveau, y compris reprise après échec partiel),
  `sync_bootstrap_provider_test.dart` (nouveau, régression composition root), `accounts_settings_provider_test.dart`
  adapté (signature de `deleteAccountFolder`).