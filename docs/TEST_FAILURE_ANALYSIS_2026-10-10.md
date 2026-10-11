# Analyse des échecs de tests — 2026-10-10

## Source de vérité

Le rapport fourni le 10 octobre 2026 à 12:33:09 décrit le checkpoint antérieur aux corrections de tests ci-dessous :

- tests unitaires/widgets : 1 239 découverts, 1 202 réussis, 37 en échec ; code de sortie 1 ;
- intégration : aucun test rapporté, code de sortie 1. Cette ligne ne signifie pas « 0 échec » au sens de validation : la suite a échoué avant de rapporter des tests. Le rapport JSON ne contient pas la sortie console qui permettrait de distinguer une erreur de build, d'initialisation ou de sélection d'appareil.

Ces chiffres sont l'observation du run fourni, pas le résultat du code après les corrections de cette révision. Flutter/Dart ne sont pas disponibles dans l'environnement de préparation : aucune correction ci-dessous n'est déclarée validée par exécution.

## Regroupement des 37 échecs observés

1. **19 ProviderException provenant de `FirebaseAuth.instance` / autres singletons backend.** Les nouveaux chemins `ProfileSession.build()` lisent le flux d'authentification, et les tests doivent injecter une vraie source simulée au lieu de retomber implicitement sur le singleton Firebase. Certains tests de construction de services doivent aussi fournir des clients backend de test (Firebase Auth mock, Fake Firestore, SupabaseClient de test).
2. **9 erreurs de widgets dont le rapport n'a pas conservé l'exception interne.** Le JSON ne permet pas de confirmer leur cause. Le harnais `pumpApp` fournit maintenant un `ProviderScope`, et `CategoryView` n'observe plus la session de profil quand il n'a pas besoin des préférences de formatage. Il faut rerun pour vérifier si cela résout ces cas ; ne pas conclure à partir du résumé seul.
3. **6 tests du provider de revenus.** Ils dépendent de `ProfileSession` et sont probablement impactés par l'erreur Firebase de construction ; à réévaluer après les tests ciblés, plutôt que changer leurs attentes métier.
4. **1 test de navigation initiale.** Le test lisait la configuration de `GoRouter` avant l'installation de la route initiale. Le test installe maintenant la route de départ et attend sa résolution avant de vérifier la redirection.
5. **1 test de sign-out.** La séquence de reset vide toutes les sessions avant d'appeler `ProfileService.signOut`; les tests doivent donc fournir les services dont `clear()` invalide les caches. Le container de test fournit maintenant ces services.
6. **1 test de changement de nom.** L'ancien scénario combinait un profil `u1` à une identité Firebase déconnectée. Le test utilise désormais un utilisateur simulé authentifié dont l'UID correspond au profil, conformément au garde-fou de production.

## Corrections préparées

- Les doubles `AuthService` utilisés par les tests qui construisent `ProfileSession` exposent explicitement `authStateChanges` comme un flux vide ; le test qui vérifie le sign-out Firebase externe conserve, lui, le vrai flux simulé.
- Ajout de `test/helpers/test_backend_client_overrides.dart` pour construire les services à partir de clients de test, sans exiger Firebase ou Supabase initialisé.
- Les tests `ProfileSession` qui simulent une déconnexion externe injectent tous les services dont le reset invalide les caches.
- `pumpApp` installe un `ProviderScope` avec les clients Firebase Auth, Firestore, Supabase et Google Sign-In de test afin que les widgets `ConsumerWidget` soient testés dans un environnement Riverpod isolé, sans singleton backend réel. Les écrans qui fournissent déjà un `UncontrolledProviderScope` conservent leur container propre.
- `CategoryView` reçoit explicitement devise/locale/décimales depuis `CategoryExpenses` et n'observe `ProfileSession` que si l'affichage du seuil exige encore ces préférences.
- Le test `app_router_test` installe la route initiale avant d'assert la route finale.
- `tool/test_pyramid.dart` accepte `--device-id <id>` dans les modes `integration` et `full`, et le rapport attire maintenant l'attention sur une suite d'intégration qui quitte avec un code non nul sans rapporter de tests. `docs/QUALITY.md` et `docs/DEVELOPMENT.md` documentent la commande explicite.

## Validation à faire localement

```powershell
dart format lib test integration_test tool
flutter analyze
flutter test --coverage test
flutter devices
dart run tool/test_pyramid.dart integration --device-id <device-id>
```

Pour la suite complète :

```powershell
dart run tool/test_pyramid.dart full --device-id <device-id>
```

Ne pas considérer les 37 erreurs comme résolues tant que les sorties réelles après ces changements ne confirment pas la suite verte. Si des widgets échouent encore avec « See exception logs above », conserver aussi la sortie console complète de ces tests ciblés, car le rapport JSON fourni a omis la cause interne.


## Mise à jour après le run du 2026-10-10 15:31

Le run suivant a révélé 126 échecs unit/widget et 13/13 tests d'intégration réussis. L'analyse des 126 échecs les regroupe en deux causes, et non 126 régressions indépendantes :

- 125 erreurs de teardown sont dues au timer périodique `GoTrueClient.startAutoRefresh` créé par `SupabaseClient` dans `test/helpers/test_backend_client_overrides.dart`. Le client de test désactive maintenant `AuthClientOptions(autoRefreshToken: false)` et est disposé avec `addTearDown`.
- Le test `app_router_test.dart` consultait le `routerDelegate` sans attacher GoRouter à un `Router`. Il utilise maintenant `MaterialApp.router` dans un test widget et attend le règlement initial des redirects avant de vérifier la route.

Cette correction est basée sur l'analyse des traces ; le correctif doit être confirmé en lançant le run complet avec Flutter/Dart sur l'environnement de développement.

## Correctif du gel de la suite (2026-10-10)

Le gel du processus observé après `+462` ne venait pas d'un test précis mais du teardown de `test/helpers/test_backend_client_overrides.dart`. `SupabaseClient` crée un `YAJsonIsolate`, et `YAJsonIsolate.dispose()` attend un échange de ports entre isolates (`_createdIsolate.future`) que la zone `FakeAsync` de `flutter_test` ne délivre jamais. Le `await supabaseClient.dispose()` bloquait donc le processus indéfiniment, pour tout test `testWidgets` utilisant `pumpApp`, pas seulement `app_router_test`.

- La libération du client Supabase de test est désormais fire-and-forget (`unawaited(supabaseClient.dispose())`). Le client reste confiné aux tests, sans auto-refresh ni réseau réel ; aucune attente de teardown n'est nécessaire.
- `test/core/navigation/app_router_test.dart` injecte maintenant les délégués de localisation et utilise des `pump()` bornés au lieu de `pumpAndSettle()`, qui ne se stabilisait jamais à cause de l'indicateur de chargement indéfini de la page Overview.

Vérification locale de cette révision : `flutter analyze` sans erreur ; `flutter test` → `1239` tests réussis, aucun échec, code de sortie 0. Les tests d'intégration (`integration_test/`) n'ont pas été relancés dans cette session (pas d'appareil disponible) ; ils n'utilisent pas la zone `FakeAsync` et ne sont pas concernés par ce correctif.

