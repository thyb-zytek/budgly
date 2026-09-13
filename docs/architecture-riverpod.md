# Architecture Riverpod (migration en cours)

Ce document décrit le patron établi lors du pilote de migration (issue M1,
page `settings/preferences`) et à répliquer sur le reste de l'app dans les
issues suivantes (M2 à M7). Il complète `docs/ARCHITECTURE.md`, qui décrit
encore l'ancienne infra MVVM tant que la migration n'est pas terminée.

## Codegen : `riverpod_generator`

Choix retenu : **codegen avec `@riverpod`**, pas de providers manuels. Chaque
provider est déclaré via une annotation, le fichier `*.g.dart` associé est
généré par `build_runner`.

```dart
part 'xxx_provider.dart.g.dart'; // convention : voir plus bas

@riverpod
class Xxx extends _$Xxx {
  @override
  XxxState build() { ... }
}
```

## Fichiers générés (`*.g.dart`) : **non commités**

Décision prise en M0, reconfirmée ici : les `*.g.dart` sont dans
`.gitignore` et régénérés par CI avant `analyze`/`test`/`build`
(`dart run build_runner build --delete-conflicting-outputs`). En local,
utiliser le mode watch pendant le dev :

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Convention de nommage

- Le fichier qui remplaçait un `view_model.dart` s'appelle
  **`preferences_provider.dart`** (nom de la feature, suffixe `_provider`),
  pas `view_model.dart` — le renommage est volontaire, il signale qu'on a
  changé de mécanisme, pas seulement de nom de classe.
- Un `Notifier` de feature s'appelle simplement par le nom de la feature
  (`Preferences`, pas `PreferencesViewModel` ni `PreferencesNotifier`) : le
  générateur produit déjà `preferencesProvider`, le suffixe serait redondant.
- L'état exposé par un `Notifier`, quand ce n'est pas un type primitif, est
  une classe immuable dédiée : `PreferencesState`. Elle implémente `==` /
  `hashCode` (nécessaire pour que `.select()` évite les rebuilds inutiles
  quand la valeur sélectionnée n'a pas changé au sens de l'égalité de
  valeur).

## Pattern « pont » pour les services legacy non encore migrés

Le cas `settings/preferences` illustre une situation qui va se répéter
ailleurs : une page qu'on veut migrer dépend d'un service qui, lui, reste en
`.instance` (`ProfileService`, ici) parce qu'il est partagé par bien plus que
cette seule page et que sa migration complète appartient à une issue dédiée
(M3).

Plutôt que d'attendre M3 pour migrer quoi que ce soit, on introduit un
**provider-pont** minimal :

```dart
@Riverpod(keepAlive: true)
ProfileService profileService(Ref ref) => ProfileService.instance;
```

- Les `Notifier` de la page dépendent de ce provider (`ref.watch`/`ref.read`)
  plutôt que d'appeler `XxxService.instance` directement.
- En test, on override **ce seul provider**
  (`profileServiceProvider.overrideWithValue(fake)`) au lieu de subclasser le
  service ou de manipuler un singleton global — le test reste isolé même si
  le service, lui, ne l'est pas encore.
- Quand le service concerné est migré (M3), seule l'implémentation du
  provider-pont change ; les `Notifier` qui en dépendent n'ont rien à
  changer.
- Un tel pont, une fois qu'il dépasse le périmètre d'une seule page (c'est le
  cas de `ProfileService`, consommé par plusieurs futures pages), est promu
  dans un emplacement partagé plutôt que déclaré localement dans la page qui
  l'a introduit en premier — voir `lib/src/core/riverpod/profile_providers.dart`
  (promu depuis `settings/preferences` en issue M1b).

Ce pattern doit être réutilisé chaque fois qu'une page migrée dépend d'un
service pas encore converti, plutôt que de migrer ce service en avance de
phase.

## Pattern « miroir » pour les stores legacy non encore migrés (issue M2)

Variante du pont ci-dessus, pour les **stores** (`ChangeNotifier`
`.instance`) plutôt que les services. Constat en migrant M2 : contrairement
à `ProfileStore` (consommé directement par plusieurs pages/services),
`AccountsStore`, `CategoriesStore`, `ExpensesStore` et `AccountBudgetsStore`
n'ont chacun qu'un seul consommateur dans `lib/` — leur service respectif.
Ils sont donc bien plus isolés, mais leur service, lui, reste un singleton
`.instance` non migré (issue M3) : on ne peut donc pas simplement faire
dépendre le service du nouveau provider (le service n'est pas
`ref`-aware).

La solution : un **Notifier miroir**, `keepAlive`, qui republie un instantané
immuable de l'état du store, sans toucher au store lui-même ni à son
service :

```dart
@Riverpod(keepAlive: true)
class AccountsSession extends _$AccountsSession {
  AccountsStore get _store => AccountsStore.instance;

  @override
  AccountsSessionState build() {
    _store.addListener(_onStoreChanged);
    ref.onDispose(() => _store.removeListener(_onStoreChanged));
    return _readState();
  }
  // ...
}
```

- Fichier colocalisé avec le store qu'il miroite :
  `lib/src/stores/accounts_provider.dart` à côté de
  `lib/src/stores/accounts.dart` (pas dans `core/riverpod/`, réservé aux
  cas — comme le profil — qui dépassent un seul store).
- Si le store n'expose pas déjà d'accesseur global sur sa collection interne
  (cas d'`ExpensesStore` et `AccountBudgetsStore`, qui n'exposaient que des
  lookups par clé), on ajoute un **getter en lecture seule** minimal
  (`Map.unmodifiable(...)` / `Set.unmodifiable(...)`) — un ajout pur, aucune
  méthode existante n'est modifiée.
- **Pas de `==`/`hashCode` custom** sur ces états miroirs quand ils
  contiennent des collections potentiellement grandes (`ExpensesStore` en
  particulier) : l'état est un nouvel objet à chaque mutation de toute façon,
  et le store ne remplace que la sous-collection réellement modifiée (une
  seule entrée de map, une seule liste) — donc `ref.watch(provider.select((s)
  => s.xxxByAccount[id]))` sur un compte non touché reste `identical` à
  l'ancienne valeur sans comparaison profonde. Documenté avec un test dédié
  (`"unrelated ... is unaffected by another ... changing"`) dans chaque
  fichier de test de provider miroir.
- Un `Notifier` migré (issue M4) qui a besoin des données d'un store encore
  non migré dépend de son *miroir* (`ref.watch(accountsSessionProvider)`),
  jamais du store directement.

Quand le service concerné migre à son tour (M3), le miroir peut soit
disparaître au profit d'un `Notifier` de store « réel » (si le service migré
peut légitimement dépendre de `ref`), soit rester tel quel si le store
continue d'avoir d'autres consommateurs non-Riverpod à ce moment-là — à
trancher au cas par cas dans l'issue M3.

### ⚠️ Ne pas se fier au dossier pour lister les stores à migrer

En migrant M2, un store a été raté dans le premier passage :
`AuthSessionNotifier` (`lib/src/core/auth/auth_session.dart`) — un
`ChangeNotifier` singleton `.instance`, structurellement identique aux
autres, mais rangé sous `core/auth/` plutôt que `stores/`, donc absent d'un
simple `ls lib/src/stores/`. Il n'a été trouvé qu'en cherchant
`extends ChangeNotifier` sur tout `lib/` :

```bash
grep -rln "extends ChangeNotifier" lib --include=*.dart
```

**Pour toute issue de migration (M3 y compris), partir de ce grep plutôt que
d'une liste de fichiers établie par dossier** — le même angle mort peut se
reproduire pour les services.

Ce cas particulier illustre aussi une variante du pattern miroir : quand le
`ChangeNotifier` legacy n'expose aucune donnée mutable observable
directement (ici, `AuthSessionNotifier` ne fait que relayer un flux Firebase
Auth, sans getter propre), le miroir n'a rien de significatif à republier —
on expose alors un simple compteur de révision (`int`, incrémenté à chaque
notification), suffisant pour que `ref.watch` déclenche un rebuild au bon
moment. Et comme `.instance` de ce notifier n'est pas déclenchable
manuellement dans un test (il est câblé sur le vrai flux Firebase sauf si un
`auth` différent est injecté au constructeur, chose impossible après coup
sur le singleton), le miroir passe par un **provider-pont sur le notifier
lui-même** (`authSessionProvider`) plutôt que d'appeler
`AuthSessionNotifier.instance` en dur — c'est ce qui le rend testable avec
`firebase_auth_mocks` via `overrideWithValue`.

## Services (issue M3) : pont simple vs miroir, selon que le service porte son propre état

Même diagnostic qu'en M2 : chaque service (`AccountsService`,
`CategoriesService`, `ExpensesService`, `AccountBudgetsService`,
`AuthService`, `AnalyticsService`, `CategoryIconsService`, `SyncManager`)
reste consommé par plusieurs ViewModels non migrés (5 à 14 call sites selon
le service) — leur réécriture complète appartient à M4/M5, pas à M3.

Deux cas se distinguent, déterminés en cherchant lesquels étendent
`ChangeNotifier` (`grep -rln "extends ChangeNotifier" lib/src/services`) :

**Service « plat » (pas de `ChangeNotifier`) → pont simple, sans écouteur.**
C'est le cas d'`AccountsService`, `CategoriesService`,
`AccountBudgetsService`, `AuthService`, `AnalyticsService`,
`CategoryIconsService` : ils ne portent aucun état propre au-delà du store
qu'ils encapsulent (déjà miroité en M2) ou d'effets de bord sans état
observable (analytics, auth). Le provider est alors un simple
pass-through, sans `build()` ni écouteur à nettoyer :

```dart
@Riverpod(keepAlive: true)
AccountsService accountsService(Ref ref) => AccountsService.instance;
```

**Service `ChangeNotifier` → miroir, comme pour un store.** C'est le cas
d'`ExpensesService` et de `SyncManager`. Le miroir ne republie que ce qui est
*propre au service* (pas déjà couvert par le miroir du store sous-jacent) :
pour `ExpensesService`, seul `creationRevision` n'a pas d'équivalent dans
`expensesSessionProvider` (issue M2) ; pour `SyncManager`, `isSyncing`,
`hasStuckOperations` et `stuckOperationsCount` n'ont pas d'équivalent
ailleurs. Pas de duplication de données déjà mirorées côté store.

**Piège de test à connaître** : certains stores/services (`ExpensesStore`,
`SyncManager`) n'exposent **qu'un constructeur privé** (`ClassName._()`),
contrairement à d'autres qui acceptent un constructeur public injectable
(`AccountsService({store, ...})`). Dans ce cas, impossible de construire une
instance isolée pour un test — il faut réutiliser le singleton `.instance`
partagé et s'appuyer sur les helpers d'isolation existants
(`clearAllTestStores()`, `manager.resetForTest()`), exactement comme le
faisaient déjà les tests historiques de ces classes avant la migration.
`AnalyticsService` va plus loin : son unique constructeur est privé
(`AnalyticsService._()`), donc son test ne peut même pas vérifier
l'« override par un fake », seulement le pass-through vers le singleton —
documenté explicitement dans le test plutôt que masqué.

## Granularité des rebuilds : `.select()`

Remplace `ViewModelSelector` : `ref.watch(provider.select((s) => s.champ))`.
Chaque section de vue qui n'a besoin que d'un sous-ensemble de l'état
s'enveloppe dans son propre `Consumer(...)` plutôt que de regarder l'état
complet au niveau de la page — sinon toute la page rebuild à chaque
changement, comme avant `ViewModelSelector`.

## Cycle de vie : `autoDispose` par défaut, `keepAlive` pour les ponts/miroirs

Les providers générés par `@riverpod` sont `autoDispose` par défaut (pas de
`keepAlive: true` sauf besoin explicite) — c'est le cas de `Preferences`,
propre à une page. En revanche, tout provider-pont ou provider-miroir qui
expose un état **partagé par plusieurs pages** (`profileServiceProvider`,
`profileSessionProvider`, `accountsSessionProvider`, etc.) est déclaré
`@Riverpod(keepAlive: true)` : il doit vivre pour toute la durée de l'app,
pas seulement tant qu'un widget l'observe, sans quoi le listener posé sur le
`ChangeNotifier` legacy serait détaché puis rattaché à chaque fois qu'aucune
page ne regarde momentanément ce provider.

Pour un `Notifier` qui s'abonne à un service/store externe (`ChangeNotifier`
legacy), le nettoyage de l'abonnement se fait dans tous les cas via
`ref.onDispose(...)` dans `build()`, jamais dans une méthode `dispose()`
écrite à la main (Riverpod ne l'appelle pas).

## Tests

- Plus de `injectedViewModel` : les tests unitaires de `Notifier`
  s'écrivent avec `ProviderContainer(overrides: [...])`, sans widget à
  monter.
  ```dart
  final container = ProviderContainer(
    overrides: [profileServiceProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  ```
- **Ne jamais disposer un même `ProviderContainer` deux fois** (dans
  `addTearDown` et manuellement dans le corps du test) — créer un container
  local dédié si un test a besoin de contrôler explicitement le moment du
  `dispose()`.
- Pour vérifier qu'un `Notifier` réagit bien à un changement externe,
  `container.listen(provider, (previous, next) => ...)` après un premier
  `container.read(provider)` qui force l'exécution de `build()`.
- Pour un provider-miroir de store, un test dédié vérifie qu'une sélection
  sur une clé/un compte non affecté reste `identical` après une mutation sur
  une autre clé (garantie de non-rebuild inutile en l'absence de `==` custom
  — voir le pattern miroir ci-dessus).
- Les tests widgets (page entière) devront envelopper le widget testé dans
  un `ProviderScope` — harnais partagé (`pump_app.dart`) à adapter dans
  l'issue M6, pas fait par page.

## Ce qui n'a pas changé depuis M1

- `ProfileService`/`ProfileStore`, les 4 stores migrés en M2, et les 8
  services migrés en M3 (`AccountsService`, `CategoriesService`,
  `ExpensesService`, `AccountBudgetsService`, `AuthService`,
  `AnalyticsService`, `CategoryIconsService`, `SyncManager`) restent des
  singletons `.instance` inchangés dans leur logique interne — seule leur
  *exposition* passe par un pont ou un miroir Riverpod. Leur migration
  réelle (suppression du singleton) est hors périmètre tant que leurs
  appelants (ViewModels non migrés, `main.dart`, `app.dart`,
  `app_router.dart`, `route_guards.dart`) n'ont pas eux-mêmes bougé — c'est
  le travail de M4/M5.
- `ExpensesStore` et `AccountBudgetsStore` ont chacun reçu deux petits
  getters en lecture seule (`Map.unmodifiable`/`Set.unmodifiable`) pour que
  leur miroir Riverpod puisse lire l'état complet — ajouts purs, aucune
  méthode existante modifiée.
- `docs/ARCHITECTURE.md` (ancienne infra MVVM) reste valable pour toutes les
  pages non encore migrées.
