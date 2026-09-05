# Budgly — stratégie et pyramide de tests

## Objectif

La suite vise à rendre les régressions métier et les parcours critiques détectables automatiquement afin que les campagnes manuelles restent courtes et ciblées.

La source de vérité d'exécution reste `flutter test` / `flutter test --coverage`. Les chiffres ci-dessous sont un inventaire statique du workspace livré avec cette archive.

## Inventaire actuel

- **118 fichiers** `*_test.dart` sous `test/` et `integration_test/`.
- **1048 appels** `test()` / `testWidgets()` détectés statiquement.
- **170 groupes** `group()` détectés statiquement.
- **4 parcours d'intégration** ciblés, couvrant offline/reconnexion, logout et reprise du parcours utilisateur.

## Pyramide

### 1. Domain / unit — volume maximal

Couvre notamment :

- modèles `Account`, `Category`, `Expense`, `ExpenseOccurrence`, `Period` ;
- récurrences et règles de bornage ;
- versioning d'une dépense récurrente ;
- calcul des occurrences et des statistiques ;
- invariants financiers ;
- extensions montant/devise/couleur ;
- validation ;
- résilience et contrats de données.

Ces tests doivent rester déterministes, rapides et indépendants du réseau.

### 2. Services / stores / ViewModels

Couvre notamment :

- CRUD et propagation vers les stores ;
- cache local corrompu et fallback ;
- source de vérité cache après erreur réseau ;
- mutations offline create/update/delete ;
- conservation de l'état local lors d'un snapshot serveur obsolète ;
- coalescence des mutations et ordre FIFO ;
- backoff et retry forcé ;
- dépendance account → category ;
- suppression/recréation en cas de conflit ;
- logout bloqué tant que les mutations critiques ne sont pas synchronisées ;
- reprise de l'onboarding ;
- pagination et tri des dépenses ;
- versioning des séries récurrentes.

### 3. Widget / feature

Couvre les interactions utilisateur à forte valeur :

- sélecteurs account/category/récurrence ;
- propagation d'édition de dépense ;
- formulaires et dropdowns ;
- bannière de synchronisation et action `Réessayer` ;
- lifecycle/timers ;
- Overview et composants critiques ;
- goldens ciblés mobile/tablette et light/dark.

Les tests de widgets privilégient des cibles stables (`Key`, semantics, types) plutôt que des positions écran fragiles.

### 4. Integration

Les tests d'intégration restent peu nombreux mais traversent plusieurs couches :

1. création offline → queue → reconnexion → serveur ;
2. update/delete offline → reconnexion → état serveur final ;
3. logout avec mutation en attente ;
4. reprise d'un utilisateur dans le bon parcours.

Ils ne remplacent pas tous les tests unitaires : ils vérifient que les couches assemblées respectent leurs contrats.

## Contrats offline garantis par les tests

Budgly utilise plusieurs couches d'état local : stores en mémoire, cache `SharedPreferences` pour comptes/catégories/profil, et cache persistant Firestore pour dépenses/revenus. Les tests de cette zone vérifient la **propagation** et non seulement la persistance.

### Contrat de mutation

Toute mutation utilisateur doit être visible immédiatement dans la source de vérité locale et notifier les consommateurs actifs sans rechargement applicatif.

```text
create/update/delete/debit
        |
        v
 local store + loaded period projections
        |
        +--> current screen
        +--> other active screen/ViewModel
        +--> modal closes -> underlying screen reflects mutation
        |
        v
 offline persistence / sync
        |
        v
 remote acknowledgement
```

### Scénarios offline couverts

- CRUD cache persistant des comptes, catégories et profil ;
- create/update/delete d'une dépense avec état local optimiste ;
- mutations montant/catégorie/compte/date ;
- propagation débit/undébit ;
- invalidation et re-population des projections compte/période ;
- propagation listener actif sans reload ;
- coalescence et persistance de la queue ;
- retry/backoff et retry explicite contournant le backoff ;
- dépendance de synchronisation compte-avant-catégorie ;
- échec de synchronisation restant visible à l'utilisateur.

### Bannière de synchronisation

`SyncIssueBanner` est montée au niveau supérieur par `BudglyApp`. Les tests vérifient :

1. état masqué quand aucune opération n'est bloquée ;
2. état d'erreur et action `Réessayer` ;
3. état chargement pendant le retry ;
4. retry réussi et drain de la queue ;
5. erreur persistante quand le retry échoue ;
6. apparition de la bannière après une opération bloquée sans reload.

Le retry utilise une passe `forceRetry` explicite afin qu'une action utilisateur ne soit pas bloquée par le backoff exponentiel d'arrière-plan.

### Contrats garantis

1. Après une erreur réseau, l'état local reste affiché.
2. Les mutations offline sont persistées et rejouables.
3. L'ordre d'arrivée est conservé, sauf ordre de dépendance explicite nécessaire à la cohérence (`accounts` avant `categories`).
4. Un snapshot serveur obsolète ne doit pas effacer une mutation locale encore en attente.
5. Une suppression initiée par l'utilisateur est prioritaire.
6. Une entité supprimée côté serveur mais encore modifiée localement est récupérable par recréation lors du replay.
7. Une édition récurrente s'applique à l'occurrence sélectionnée et aux suivantes.
8. Une suppression au milieu d'une série retire l'occurrence ciblée et les suivantes.
9. Un déplacement de dépense conserve sa contribution exactement une fois dans les nouvelles dimensions compte/catégorie.
10. Le retry manuel contourne le backoff.
11. Le logout ne perd aucune mutation critique.
12. Les timers, listeners et singletons utilisés par les tests sont nettoyés.
13. Les snapshots serveur obsolètes n'effacent pas une création locale non acquittée ; des mutations locales consécutives rapides laissent l'état le plus récent visible.

Ces tests sont orientés store/service. Les widget tests doivent valider que les mêmes contrats notifier sont consommés par les écrans et modales visibles.

## Anti-hang

Le bootstrap de test initialise Flutter et `intl` de manière déterministe. Le singleton `SyncManager` expose `resetForTest()` et `stop()` afin que les timers/lifecycle observers ne survivent pas à une suite.

Un garde asynchrone est disponible dans `test/helpers/async_test_guard.dart` et un runner avec timeout est disponible dans `tool/test_pyramid.dart`.

Commandes recommandées :

```bash
# Pyramide rapide : domaine + modèles + unit + premiers services
flutter test test/core test/models test/unit
flutter test test/services/calculators test/services/categories test/services/budget

# Services / offline
flutter test test/services

# Widgets + goldens
flutter test test/widget test/golden

# Tout le test Dart
flutter test

# Couverture
flutter test --coverage

# Intégration
flutter test integration_test

# Runner avec timeout (évite de rester bloqué indéfiniment)
dart run tool/test_pyramid.dart fast
dart run tool/test_pyramid.dart services
dart run tool/test_pyramid.dart widgets
dart run tool/test_pyramid.dart all
dart run tool/test_pyramid.dart integration
```

## Ce qui reste raisonnablement manuel

La campagne manuelle ne doit plus refaire les invariants métier déjà couverts. Elle doit se concentrer sur :

- installation réelle et première ouverture sur appareil ;
- authentification Firebase/Google avec vrais comptes ;
- permissions et comportements OS (photo, clavier, reprise d'activité) ;
- connectivité réelle : passage Wi-Fi/4G, coupure prolongée, reprise réseau ;
- rendu visuel sur quelques appareils/résolutions non représentés par les goldens ;
- Firebase/Supabase/Storage/PostHog réellement configurés ;
- performances perçues et consommation mémoire/batterie sur appareil physique.

Tout nouveau bug métier doit d'abord devenir un test de régression avant ou avec sa correction. Cela évite que la même vérification revienne dans les campagnes manuelles.


## Dernier renforcement de la pyramide

La couche domaine couvre désormais aussi les contrats d'authentification, les routes, les tokens/thèmes, les types d'input, le sélecteur de ViewModel et le calculateur d'occurrences. Une régression de bootstrap a également été ajoutée pour garantir que `LocalCache` ne déclenche pas `SharedPreferences.getInstance()` avant l'installation du mock Flutter.

Le runner expose en plus les niveaux `domain`, `features` et `regression` afin de pouvoir isoler rapidement une couche fautive avant la passe complète.

La passe de septembre 2026 comble le trou services métier identifié dans `coverage.log` (accounts 10 %, auth 5 %) : `test/services/categories/categories_service_test.dart` (10 tests), `test/services/profile/profile_service_test.dart` (12 tests), `test/services/accounts/accounts_service_test.dart` (11 tests via `MockFirebaseAuth` + `FakeAccountSupabase`/`FakeStorageSupabase` — dont coalescence create→update, queue picture, signedUrl) et `test/services/auth/auth_service_test.dart` (15 tests via `MockFirebaseAuth` + `FakeUserProfileSupabase` et `whenCalling(...).thenThrow` pour les branches d'erreur). `firebase_auth_mocks` et `mock_exceptions` ont été ajoutés en `dev_dependencies` pour permettre ce mocking (`pubspec.yaml`). En isolé, les 4 services atteignent 79,4 % / 56,3 % / 74,6 % / 60,8 % de lignes ; en suite complète le chiffre est plus élevé (exercice croisé via les ViewModels).

Côté widget, `lib/src/pages/tutorial/view.dart:14` (0 % → exercé) accepte désormais `injectedViewModel` (`view.dart:14`, `view.dart:23`) afin de pouvoir pomper la page pleine en test. `test/widget/tutorial_page_e2e_test.dart` couvre le parcours plein-page : accueil → suivant → retour (indicateur d'étape, `PageView` 300 ms) et `PopScope` → dialogue de déconnexion (`handlePopRoute` → `Annuler`). Le harnais `MaterialApp` fournit `AppLocalizations` (locale `fr`) et utilise `tester.runAsync` pour laisser le `TutorialViewModel` terminer son `_loadInitialData` ; `view.dart:32` ne dispose plus deux fois le VM injecté (`_ownsViewModel`).

## Renforcement orienté risque

La couverture n'a pas vocation à atteindre artificiellement 100 % des lignes. Les priorités sont :

1. **100 % des règles métier déterministes** : calculs, récurrences, bornes, sérialisation et invariants financiers ;
2. **≥ 90 % des services offline/sync critiques** : queue, replay, conflits, cache et mutations ;
3. **≥ 80 % des ViewModels critiques** : états et transitions métier ;
4. **widgets critiques testés par interaction**, sans chercher à exécuter chaque branche purement visuelle ;
5. **intégration limitée aux parcours transverses** impossibles à garantir avec des unit tests.

Les fichiers générés (`main.dart`, localizations générées, composition root) et les adaptateurs minces vers Firebase/Supabase peuvent rester moins couverts si leur comportement est déjà vérifié indirectement ou par une passe d'intégration.

Les nouveaux tests ajoutés dans cette passe renforcent notamment les cas limites des modèles `Account`, `Period`, du versioning récurrent et des stores. Ils servent aussi de filet contre les régressions silencieuses dans les opérations de mutation et de nettoyage.

### Septembre 2026 — provider Firestore des dépenses

`ExpenseFirestore` dispose maintenant d'une suite dédiée avec `FakeFirebaseFirestore` + `MockFirebaseAuth`. Les tests couvrent la résolution de l'utilisateur, create/update/delete, split d'une série récurrente, filtrage par compte/catégorie/période, chevauchement des récurrences, pagination et suppressions bulk dans le cache.

Le fake Firestore est volontairement utilisé ici : le provider contient de vraies requêtes Firestore et il est plus pertinent de vérifier leur résultat que de mocker chaque appel de l'API. La version `fake_cloud_firestore` utilisée est compatible avec la famille `cloud_firestore` du projet ; après ajout de la dépendance, `flutter pub get` doit être exécuté pour régénérer `pubspec.lock`.

### Septembre 2026 — frontières et cache

Les providers Supabase critiques sont désormais injectables (`SupabaseClient`) afin de permettre des tests contractuels déterministes sans dépendre du singleton global. Les opérations Account, Category et UserProfile disposent de tests via un serveur HTTP local, et Storage couvre au minimum la validation pré-réseau d'un fichier inexistant.

La politique de cache de `ExpensesService` est isolée dans `ExpensePeriodCache` et testée directement (clés, snapshots, créations optimistes, suppressions en attente et déplacements entre périodes).

Les décisions de routing sont testées indépendamment de GoRouter via `RouteGuards.decideRedirect`, et `AuthSessionNotifier` accepte maintenant une instance FirebaseAuth injectée. La résolution de période des routes est également testée directement.
