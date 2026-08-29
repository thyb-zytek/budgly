# Budgly — Audit de simplification et état de l'architecture

## État de référence

Cette documentation décrit l'état du projet après les phases 1 à 4 de simplification.

> Les archives de travail utilisées pour certains refactors peuvent ne pas contenir le dossier `test/`. Les commandes `flutter analyze` et `flutter test` restent la validation locale de référence.

## Architecture actuelle

```text
UI / Pages
   │
   ├── ViewModelSelector / ViewModelFeedback
   │
   ▼
ViewModels
   │
   ├── état UI local
   ├── orchestration des actions utilisateur
   └── projections nécessaires à l'écran
   │
   ├───────────────┐
   ▼               ▼
Repositories     Services
   │               │
   │               ├── Firestore / Supabase
   │               ├── Stores locaux
   │               ├── offline/sync
   │               └── analytics
   ▼
Data sources / Stores
```

### Règle d'architecture

Pas de repository/use-case supplémentaire simplement pour déplacer du code. Une abstraction n'est ajoutée que si elle retire une responsabilité réelle ou mutualise une logique métier utilisée à plusieurs endroits.

## Phases réalisées

### Phase 1 — nettoyage

Suppression du code mort historique :

- `LoadingNotifier`
- `ProgressiveLoader`
- `OverviewPeriodCache`
- `CacheController`
- `FirestoreMetrics`
- `SessionDataService`
- ancien `ErrorService` / `ServiceUnavailableScreen`
- méthodes et widgets devenus orphelins

Les anciens widgets de formulaire d'expense ont également été retirés lorsqu'ils n'étaient plus référencés.

### Phase 2 — Expense Editor

La création et l'édition utilisent désormais :

- `ExpenseEditorSheet`
- `ExpenseFormFields`
- `ExpenseAdvancedOptions`
- `ExpenseFormController`

Le widget commun reste présentational. Les opérations métier restent dans les ViewModels.

### Phase 3 — Overview

`OverviewRepository` centralise l'orchestration des chargements propres à l'écran Overview :

- chargement initial ;
- préchargement des autres comptes ;
- refresh de la période ;
- chargement de la période d'expenses ;
- chargement du revenu en arrière-plan ;
- récupération du revenu hérité.

Il ne possède pas d'état UI.

### Phase 4 — Expenses / Category Expenses

#### `ExpenseOccurrenceCalculator`

La projection des dépenses vers les occurrences visibles et leur ordre d'affichage sont centralisés. Cela évite que Overview et Category Expenses implémentent deux variantes de la même règle.

#### `CategoryExpensesViewModel`

Simplifications réalisées :

- suppression des getters/méthodes simples qui ne faisaient que déléguer au `ExpenseFormController` ;
- séparation des notifications `ExpensesService` / `ProfileService` ;
- mémoïsation des occurrences paginées ;
- invalidation du cache dérivé lors des mutations.

#### `ExpensesService`

Le cache de période et les requêtes en vol sont regroupés dans un composant privé `_ExpensePeriodData` afin de garder la politique de cache interne au service.

Lors d'une modification, le cache de l'ensemble du compte est invalidé plutôt que de tenter de maintenir plusieurs caches période/catégorie cohérents. Le store local reste la source optimiste immédiate.

## Analytics

- Crashlytics = erreurs techniques.
- PostHog = événements produit.
- `expense_load_failed` est émis par `ExpensesService`.
- Le tracking automatique des erreurs PostHog n'est pas utilisé.

## Code volontairement conservé

Les éléments suivants ne doivent pas être supprimés uniquement pour réduire le nombre de fichiers :

- `ViewModelSelector`
- `SyncManager`
- `SyncQueue`
- `LocalCache`
- `ExpenseSummaryCalculator`
- `ExpenseOccurrenceCalculator`
- `RecurringExpenseVersioning`
- `OverviewRepository`
- `ExpenseFormController`

Ils correspondent à des responsabilités identifiables.

## Prochaine étape

Après validation manuelle de la Phase 4 :

1. mesurer les rebuilds réels ;
2. mesurer le coût des projections de données ;
3. vérifier les parcours offline/synchronisation ;
4. ne poursuivre un refactor que si un problème concret est identifié.
