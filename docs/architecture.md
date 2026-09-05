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

## Contrat offline-first

Budgly privilégie toujours la donnée locale utilisable. Une donnée distante ne doit pas bloquer l'affichage lorsqu'une version locale est disponible.

### Ownership

| Donnée | Local | Distant | Sync |
|---|---|---|---|
| Profile | `ProfileStore` + `LocalCache` | Supabase | `SyncQueue` |
| Accounts | `AccountsStore` + `LocalCache` | Supabase | `SyncQueue` |
| Categories | `CategoriesStore` + `LocalCache` | Supabase | `SyncQueue` |
| Expenses | `ExpensesStore` + cache Firestore | Firestore | Firestore offline |
| Budgets | `AccountBudgetsStore` + cache Firestore | Firestore | Firestore offline |
| Category icons | assets embarqués | Supabase optionnel | aucun |

### Flot de lecture

```text
UI
  ↓
ViewModel
  ↓
Service
  ↓
Store / Firestore cache (+ _periodData)
  ↓
UI immédiatement si possible
  ↓
refresh distant en arrière-plan
```

Les services dédupliquent les requêtes concurrentes lorsqu'un même chargement est déjà en cours.

**Revenu :** `AccountBudgetsService.getMostRecentRevenue` est offline-first : store → `Source.cache` → marche arrière 60 mois en `get(..., Source.cache)` → `Source.server`. Un changement de période hors-ligne en `2027-02` hérite ainsi de `2026-11` même sans query 60 docs en cache.

**Dépenses (Overview) :** `ExpensesService._periodData` est mis à jour de façon optimiste (`optimisticUpdateExpense`) pour les edits non-récurrents même compte/période, et invalidé pour les récurrents. `OverviewViewModel._onExpensesChanged` reconstruit immédiatement `periodOccurrences` depuis le Store filtré si le cache période est vide, puis relance un `loadSelectedPeriodExpenses(forceRefresh:true)` en arrière-plan.

### Écriture Supabase

```text
mutation
  ↓
Store local
  ↓
LocalCache
  ↓
SyncQueue
  ↓
Supabase
```

L'utilisateur n'attend pas le round-trip réseau pour voir sa mutation locale.

### Écriture Firestore

Les dépenses et budgets utilisent directement la persistance offline native de Firestore. Il n'existe pas de seconde queue applicative pour Firestore.

### Overview

`OverviewRepository` coordonne uniquement les chargements multi-services de l'écran : initialisation, refresh, préchargement d'autres comptes et période de dépenses. Il ne remplace pas les services et ne possède pas d'état UI.

### Startup

Le démarrage attend uniquement l'infrastructure nécessaire au premier arbre Flutter (`dotenv` + Firebase + SharedPreferences → Supabase init → `runApp()`). Les opérations de synchronisation, analytics et enrichissement non bloquants sont déclenchées après `runApp()`.

Le Firebase `currentUser` est utilisé pour le routing initial. Un refresh auth/profil distant peut invalider la session plus tard, mais il n'est pas un prérequis au premier frame.

### Règles `unawaited()`

Un `unawaited()` est acceptable uniquement si :

- l'opération est réellement non bloquante ;
- ses erreurs sont gérées dans la fonction appelée ;
- son résultat n'est pas requis pour poursuivre l'action utilisateur courante.

### Ce qui a été supprimé

- loaders génériques ;
- cache générique de période Overview ;
- métriques Firestore dédiées ;
- couche de session dédiée devenue redondante ;
- système d'erreur UI non alimenté ;
- dépendances inutilisées liées aux anciennes implémentations (`flutter_iconpicker`, `flutter_localization`).

## Règle de simplification

Avant d'ajouter une abstraction, vérifier :

1. Est-elle utilisée à plusieurs endroits ?
2. Retire-t-elle une responsabilité réelle ?
3. Réduit-elle la duplication ?
4. Rend-elle les tests plus simples ?
5. Peut-on obtenir le même résultat avec une méthode ou un calculator existant ?

Si la réponse est non, ne pas ajouter la couche.
