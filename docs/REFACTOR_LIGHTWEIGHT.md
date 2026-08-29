# Refactor léger — règles et état actuel

Budgly privilégie une architecture simple : MVVM + services + stores, avec quelques calculators/repositories ciblés.

## Ce qui a été supprimé

Les anciennes abstractions génériques de chargement/cache et les composants non utilisés ont été retirés :

- `LoadingNotifier`
- `ProgressiveLoader`
- `CacheController`
- `OverviewPeriodCache`
- `FirestoreMetrics`
- `SessionDataService`
- ancien `ErrorService`
- anciens formulaires Expense spécifiques à une page

## Ce qui a été mutualisé

- `ExpenseEditorSheet` pour création/édition ;
- `ExpenseFormController` pour la mécanique du formulaire ;
- `ExpenseOccurrenceCalculator` pour la projection/tri des occurrences ;
- `OverviewRepository` pour l'orchestration spécifique à Overview.

## Règle

Ne pas remplacer une petite duplication par une abstraction plus complexe. Une abstraction doit supprimer une responsabilité ou une duplication mesurable.
