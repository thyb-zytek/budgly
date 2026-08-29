# Tests — état actuel

> État après Phase 5 — offline et édition.

## Inventaire

- **48 fichiers de tests Dart**
- **514 appels `test()` / `testWidgets()` détectés** (`flutter test` : 514/514)

Le nombre est volontairement donné comme un inventaire statique : il ne remplace pas le résultat de `flutter test`, qui reste la source de vérité pour les tests exécutables.

## Couverture fonctionnelle actuelle

### Models

Tests présents pour :

- comptes ;
- budgets ;
- catégories et icônes ;
- dépenses ;
- données d'édition d'expense ;
- récurrence ;
- profil/utilisateur ;
- périodes et occurrences.

### Core

Tests présents pour :

- `BaseViewModel` ;
- extensions montant/couleur/devise ;
- validation upload ;
- messages utilisateur.

### Services

Tests présents pour :

- calculateur de résumé des dépenses ;
- catégories/icônes ;
- cache local ;
- synchronisation ;
- queue offline ;
- versioning des dépenses récurrentes ;
- refresh du profil.

### Stores

Tests présents pour :

- comptes ;
- catégories ;
- dépenses ;
- budgets.

## État après les phases 1 à 4

Les tests associés au code mort supprimé doivent disparaître avec celui-ci. Les tests fonctionnels et unitaires existants restent la référence de validation locale.

Les responsabilités nouvellement mutualisées doivent être couvertes en priorité :

- `ExpenseFormController` ;
- `ExpenseOccurrenceCalculator` ;
- `OverviewRepository` ;
- `ExpensesService` pour le cache, les mutations et les récurrences ;
- `CategoryExpensesViewModel` pour pagination, édition et occurrences.

## Avant la Phase 5

Exécuter localement :

```bash
flutter analyze
flutter test
```

Puis effectuer la campagne de tests manuels décrite dans `MANUAL_TEST_PLAN.md`.
