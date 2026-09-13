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
@riverpod
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

Ce pattern doit être réutilisé chaque fois qu'une page migrée dépend d'un
service/store pas encore converti, plutôt que de migrer ce service en
avance de phase.

## Granularité des rebuilds : `.select()`

Remplace `ViewModelSelector` : `ref.watch(provider.select((s) => s.champ))`.
Chaque section de vue qui n'a besoin que d'un sous-ensemble de l'état
s'enveloppe dans son propre `Consumer(...)` plutôt que de regarder l'état
complet au niveau de la page — sinon toute la page rebuild à chaque
changement, comme avant `ViewModelSelector`.

## Cycle de vie : `autoDispose` par défaut

Les providers générés par `@riverpod` sont `autoDispose` par défaut (pas de
`keepAlive: true` sauf besoin explicite). Pour un `Notifier` qui s'abonne à
un service externe (`ChangeNotifier` legacy), le nettoyage de l'abonnement se
fait via `ref.onDispose(...)` dans `build()`, jamais dans une méthode
`dispose()` écrite à la main (Riverpod ne l'appelle pas).

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
- Les tests widgets (page entière) devront envelopper le widget testé dans
  un `ProviderScope` — harnais partagé (`pump_app.dart`) à adapter dans
  l'issue M6, pas fait par page.

## Ce qui n'a pas changé dans ce pilote

- `ProfileService` et `ProfileStore` restent des singletons `.instance`
  inchangés — seule leur *exposition* à cette page passe par le pont
  Riverpod. Leur migration réelle est hors périmètre de M1.
- `docs/ARCHITECTURE.md` (ancienne infra MVVM) reste valable pour toutes les
  pages non encore migrées.
