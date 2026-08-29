# Architecture Budgly

## Principes

Budgly utilise une architecture MVVM légère avec des services et quelques abstractions ciblées.

L'objectif n'est pas d'appliquer une Clean Architecture complète, mais de garder chaque couche responsable d'un problème identifiable.

## Couches

### Pages / Views

Responsables de :

- composition des widgets ;
- navigation ;
- interaction utilisateur ;
- présentation des feedbacks.

Elles ne portent pas les opérations Firestore/Supabase.

### ViewModels

Responsables de :

- état propre à l'écran ;
- orchestration des actions utilisateur ;
- déclenchement des services ;
- préparation des données directement nécessaires à l'affichage.

Ils ne doivent pas devenir des services génériques.

### Repositories ciblés

`OverviewRepository` existe parce que l'écran Overview doit coordonner plusieurs services pour une même opération de chargement.

Il ne remplace pas les services métier et ne doit pas devenir un repository générique pour toute l'application.

### Services

Les services portent les opérations métier/data :

- comptes ;
- catégories ;
- dépenses ;
- budgets ;
- profil ;
- authentification ;
- analytics ;
- offline/synchronisation.

### Calculators

Les calculators portent des transformations déterministes sans état UI :

- `ExpenseSummaryCalculator` ;
- `ExpenseOccurrenceCalculator` ;
- `RecurringExpenseVersioning`.

### Stores

Les stores maintiennent l'état local partagé nécessaire à l'application.

## Expense flow

```text
Overview / CategoryExpenses
        │
        ▼
ExpenseEditorSheet
        │
        ▼
ExpenseFormController
        │
        ▼
ViewModel
        │
        ▼
ExpensesService
        ├── ExpenseFirestore
        └── ExpensesStore
```

La création et l'édition utilisent le même éditeur visuel sans fusionner leur logique métier.

## Occurrences

```text
Expenses
   │
   ▼
ExpenseOccurrenceCalculator
   │
   ├── Overview
   └── CategoryExpenses
```

La règle d'expansion et de tri est ainsi unique.

## Offline-first

Les mutations importantes utilisent une mise à jour locale optimiste :

- **Dépenses / budgets (Firestore)** : persistance offline native + `ExpenseFormController`/`AccountBudgetsStore` mis à jour immédiatement. `ExpensesService._periodData` applique `optimisticUpdateExpense` (même compte/période non-récurrent) et invalide sinon ; `OverviewViewModel` reconstruit ses `periodOccurrences` depuis le Store filtré si le cache période est vide.
- **Revenus** : `getMostRecentRevenue` hérite offline via Store → `Source.cache` → marche arrière 60 mois → `Source.server`.
- **Comptes / catégories / profil (Supabase)** : `Store` → `LocalCache` → `SyncQueue`.

Le cache mémoire de période (`_periodData`) et la file offline (`SyncQueue`) restent privés à leurs services.

## Règle de simplification

Avant d'ajouter une abstraction, vérifier :

1. Est-elle utilisée à plusieurs endroits ?
2. Retire-t-elle une responsabilité réelle ?
3. Réduit-elle la duplication ?
4. Rend-elle les tests plus simples ?
5. Peut-on obtenir le même résultat avec une méthode ou un calculator existant ?

Si la réponse est non, ne pas ajouter la couche.
