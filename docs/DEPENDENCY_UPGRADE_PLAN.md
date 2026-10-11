# Plan prudent de mise à jour des dépendances

## Objectif

Mettre à jour Budgly sans mélanger les migrations de dépendances majeures avec les correctifs de fiabilité du socle. Aucun package n'est forcé via `dependency_overrides`, et les versions ne sont pas changées dans le checkpoint de durcissement.

## Lecture du `flutter pub outdated` fourni le 10 octobre 2026

| Package | Résultat observé | Interprétation / décision |
|---|---|---|
| `go_router` | 17.5.0 courant et upgradable, 18.0.2 resolvable/latest | Seul package direct signalé comme contraint par `pubspec.yaml` (`^17.4.0`). Le passage 17 → 18 est une migration majeure distincte. Garder 17.5.0 jusqu'à une branche de migration dédiée. |
| `cross_file` | 0.3.5+5 resolvable ; 0.4.0 latest | Ne pas forcer. 0.4.0 modifie les API de construction de `XFile` et retire `XFile.fromData`. Mettre à jour le package parent qui contraint la version et adapter les usages dans une PR distincte. |
| `equatable` | 2.1.0 resolvable ; 3.0.0 latest | Ne pas forcer. La 3.0 change certains comportements d'égalité et retire `EquatableMixin`; il faut d'abord identifier les packages dépendants et les usages directs. |
| `material_color_utilities` | 0.13.0 resolvable ; 0.13.1 latest | Écart de patch probablement lié aux contraintes du graphe SDK/packages. Ne pas ajouter de `dependency_override`; laisser le graphe compatible choisir la version. |
| `test_api` | 0.7.12 resolvable ; 0.7.15 latest | Transitive du couple Flutter/test. Ne pas forcer indépendamment de `flutter_test`; réévaluer après upgrade Flutter coordonnée. |
| `cli_util` | 0.4.2 resolvable ; 0.6.0 latest | Écart majeur transitif. 0.6 change la nullabilité de `sdkPath`; actualiser le package parent, pas le package transitif seul. |
| `pub_api_client` | 3.2.0 resolvable ; 4.0.0 latest | Écart majeur transitif. Identifier le parent avec `flutter pub deps`; ne pas imposer 4.x à un parent qui attend 3.x. |
| `cupertino_ui`, `material_ui` | absents du lock actuel mais résolvables | Ces packages apparaissent comme candidats dans la résolution, notamment dans le graphe proposé par `go_router` 18. Ne pas les ajouter directement sauf si le code de l'application les importe. |

`Resolvable` est la meilleure version que Pub peut choisir avec les contraintes déclarées et le graphe courant ; `Latest` n'est pas une instruction de forcer cette version.

## Phase D1 — mise à jour compatible, sans changement de contraintes

Créer un commit propre/une branche avant de commencer :

```bash
git switch -c chore/dependencies-compatible
flutter --version
dart --version
flutter pub outdated
flutter pub upgrade --dry-run
```

Si le dry-run montre uniquement des mises à jour compatibles avec les contraintes actuelles, lancer :

```bash
flutter pub upgrade
```

Puis inspecter `pubspec.lock` et `git diff`. Cette étape peut mettre à jour les versions transitive/patch résolubles, mais n'élargit pas automatiquement les contraintes majeures du `pubspec.yaml`.

Validation de ce seul changement :

```bash
dart run build_runner build --delete-conflicting-outputs
dart format lib test integration_test tool
flutter analyze
flutter test
flutter test integration_test -d <device>
```

En cas d'échec, isoler la première dépendance changée qui introduit la régression ; revenir au lockfile précédent si nécessaire. Ne pas réparer plusieurs changements majeurs en même temps.

## Phase D2 — migration dédiée de `go_router` 17 → 18

À faire sur une autre branche/PR, seulement après validation de D1 :

1. Lire le changelog de `go_router` 18.x et de ses dépendances UI migrées.
2. Modifier uniquement la contrainte de `go_router` à la version 18 choisie (par exemple `^18.0.2` si elle est toujours compatible et stable lors de cette opération).
3. Lancer `flutter pub get`, puis examiner les changements de `pubspec.lock` et les erreurs de compilation.
4. Rechercher et valider tous les usages de `GoRouter`, `ShellRoute`, `StatefulShellRoute`, navigation imbriquée, redirections, transitions et tests de navigation.
5. Exécuter formatage, analyse, tests unitaires/widget et intégration ; effectuer les deux tests manuels navigation/auth avant fusion.
6. Si l'effort révèle une régression ou un coût excessif, revenir à 17.5.0 et garder la migration isolée. Il n'y a aucun impératif à adopter la majeure le même jour que le durcissement de la base.

## Phase D3 — dépendances transitives majeures

Pour chaque package (`cross_file`, `equatable`, `cli_util`, `pub_api_client`) :

```bash
flutter pub deps --style=compact
flutter pub outdated
```

Identifier la chaîne qui impose la contrainte. Mettre à jour le package direct parent dans une branche séparée, lire son changelog, puis laisser Pub résoudre son graphe. Ne pas ajouter le package transitif comme dépendance directe uniquement pour contourner une contrainte et ne pas utiliser `dependency_overrides` pour forcer une version incompatible.

## Baseline à conserver

Les migrations de dépendances doivent rester sur la version de toolchain validée par le projet : Flutter 3.47.5 / Dart 3.13.4, selon les fichiers et l'environnement validé par Budgly. Ne pas mettre à jour Flutter dans la même PR que `go_router` 18 ou qu'une rupture de transitive.

## Définition de terminé

- Le diff `pubspec.lock` est compris package par package.
- Les notes de version des packages majeurs changés sont lues.
- Les fichiers générés sont reconstruits localement.
- Analyse/tests/intégration sont verts.
- Les parcours de connexion, navigation imbriquée, sync offline et préférences sont vérifiés.
- Aucun override de dépendance n'est utilisé pour masquer une incompatibilité.

## Sources amont à consulter au moment de la migration

- `go_router` changelog : https://pub.dev/packages/go_router/changelog
- `cross_file` changelog : https://pub.dev/packages/cross_file/changelog
- `equatable` changelog : https://pub.dev/packages/equatable/changelog
- `cli_util` changelog : https://pub.dev/packages/cli_util/changelog
- Dart Pub / upgrades : https://dart.dev/tools/pub/cmd/pub-upgrade
