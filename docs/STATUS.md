# État du projet

Dernière validation documentée : **2026-10-13**. Ces résultats sont historiques et n'ont pas été relancés pour
cette révision.

| Vérification | Résultat documenté | Environnement |
|---|---:|---|
| `dart format --output=none --set-exit-if-changed lib test integration_test tool` | 0 fichier à reformater | 2026-10-13 |
| `dart run build_runner build` | aucune sortie écrite | 2026-10-12 |
| `flutter analyze` | 0 problème | 2026-10-13 |
| `flutter test` | 1 367 / 1 367 | 2026-10-13 |
| `flutter test integration_test` | 13 / 13 | 2026-10-12 |
| Couverture | 77,3 % (8 845 / 11 441 lignes) | 2026-10-12 |

Les vérifications locales ont utilisé Flutter 3.47.7 / Dart 3.13.5. La CI épingle Flutter 3.47.5 / Dart 3.13.4 ;
ces résultats ne valident donc pas la toolchain CI. La couverture n'a pas été recalculée après les tests ajoutés
le 2026-10-13. Les runs locaux étaient en Europe/Paris ; le comportement sous un fuseau négatif reste à vérifier.

## Suivis encore ouverts

- Vérifier sur un projet Supabase de staging les politiques RLS/JWT avec deux utilisateurs Firebase distincts.
- Exécuter les parcours de reprise hors ligne et de changement de session sur un vrai runtime, notamment le
  nettoyage différé d'un compte ou d'une catégorie.
- Mesurer le démarrage et les performances sur appareil réel ; aucune mesure runtime n'est documentée.
- Vérifier les dates et changements d'heure dans un fuseau à décalage négatif.
- Évaluer les sujets d'architecture et de dépendances uniquement lorsqu'un besoin concret justifie leur reprise.

Les contrats techniques sont dans [`ARCHITECTURE.md`](ARCHITECTURE.md) et les règles de développement dans
[`DEVELOPMENT.md`](DEVELOPMENT.md). Le code, les tests et la CI restent les sources de preuve pour l'état réel.
