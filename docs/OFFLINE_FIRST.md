# Offline-first — contrat actuel

Budgly privilégie toujours la donnée locale utilisable. Une donnée distante ne doit pas bloquer l'affichage lorsqu'une version locale est disponible.

## Ownership

| Donnée | Local | Distant | Sync |
|---|---|---|---|
| Profile | `ProfileStore` + `LocalCache` | Supabase | `SyncQueue` |
| Accounts | `AccountsStore` + `LocalCache` | Supabase | `SyncQueue` |
| Categories | `CategoriesStore` + `LocalCache` | Supabase | `SyncQueue` |
| Expenses | `ExpensesStore` + cache Firestore | Firestore | Firestore offline |
| Budgets | `AccountBudgetsStore` + cache Firestore | Firestore | Firestore offline |
| Category icons | assets embarqués | Supabase optionnel | aucun |

## Lecture

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

## Écriture Supabase

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

## Écriture Firestore

Les dépenses et budgets utilisent directement la persistance offline native de Firestore. Il n'existe pas de seconde queue applicative pour Firestore.

## Overview

`OverviewRepository` coordonne uniquement les chargements multi-services de l'écran : initialisation, refresh, préchargement d'autres comptes et période de dépenses. Il ne remplace pas les services et ne possède pas d'état UI.

## Startup

Le démarrage attend uniquement l'infrastructure nécessaire au premier arbre Flutter. Les opérations de synchronisation, analytics et enrichissement non bloquants sont déclenchées après `runApp()`.

## Règles pour `unawaited()`

Un `unawaited()` est acceptable uniquement si :

- l'opération est réellement non bloquante ;
- ses erreurs sont gérées dans la fonction appelée ;
- son résultat n'est pas requis pour poursuivre l'action utilisateur courante.

## Ce qui a été supprimé

- loaders génériques ;
- cache générique de période Overview ;
- métriques Firestore dédiées ;
- couche de session dédiée devenue redondante ;
- système d'erreur UI non alimenté ;
- dépendances inutilisées liées aux anciennes implémentations.
