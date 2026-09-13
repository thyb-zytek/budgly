# Roadmap Budgly

Roadmap consolidé à partir des issues ouvertes sur GitHub (aucun milestone n'étant
défini, le découpage suit les dépendances fonctionnelles et la valeur produit).

## Dépendances clés entre issues

```
#11 (onboarding/guest) ── indépendant, base acquisition
#15 (FI-1 périodes/stats) ── fondation de #16 → #19
#20 (bubble + UX FI) ── définit l'UX de #15-19 + action rapide
#22 (Free/Premium) ── a de la valeur seulement quand #15-19 existent
#21 (Forecast) ── s'appuie sur #14 (fermée), #15, et la Summary Card
```

## S1 — Acquisition : onboarding + mode invité

- **#11** Refonte du tutorial : parcours interactif pré-auth, guest mode local,
  prompt d'inscription à la 1re dépense, migration guest → compte.

Pourquoi en premier : débloque l'usage sans compte, améliore l'activation (le
point de friction n°1 du funnel).

## S2 — Fondation Financial Insights

- **#15** FI-1 sélecteurs période cible/référence + stats globales comparatives
  (`FinancialInsightsCalculator` réutilisable).
- **#20** Floating Expense Bubble + hiérarchie UX du module Insights (résumé →
  évolutions → analyse → détails).

Pourquoi ensemble : la calculator de #15 est le socle de #16-19, et #20 fixe
l'UX progressive qui évite le « scroll infini » de #16.

## S3 — Insights avancés (valeur Premium)

- **#16** FI-2 statistiques dérivées (taux d'épargne, ratios, poids des catégories).
- **#17** FI-3 analyse factuelle des évolutions et ratios.
- **#18** FI-4 évolution des dépenses récurrentes.
- **#19** FI-5 benchmark Budgly par thème (côté Supabase, `category_benchmarks`).

Pourquoi : construire les features analytiques *avant* la monétisation — ce sont
elles qui justifient le Premium selon la philosophie de #22 (« comprendre ses
finances »).

## S4 — Forecast (projection)

- **#21** Financial Forecast : montant restant projeté + budget hebdo dans la
  Summary Card, hypothèses modifiables, percentiles (P25/P50/P75), offline-first.

Pourquoi : s'appuie sur la règle de période de #14 (fermée) et sur les agrégats
de #15 ; enrichit l'Overview sans nouvelle page.

## S5 — Monétisation : plans Free / Premium

- **#22** Système d'entitlements (`SubscriptionPlan`/`SubscriptionEntitlements`),
  limites (1/5 comptes, 5/15 catégories, 50/mois, historique 3 mois/3 ans),
  `TopBanner` générique + upsell, formulaire d'abonnement (RevenueCat à
  arbitrer), publicités via `hasAds`, downgrade sans perte de données, migration
  Supabase `007`.

Pourquoi en dernier : chaque feature Premium est déjà livrée et démontrable, ce
qui donne du sens à l'upsell et au comparatif Free/Premium.

## Notes transverses

- #21 et #22 (historique 3 ans) dépendent du gating d'historique
  (`OverviewViewModel.minPeriod`) → cohérence à garder entre la limite
  `historyMonths` (#22) et l'historique utilisé par le Forecast (#21).
- Les issues #15-19 étant dédiées « Insights/Premium », vérifier en S5 que les
  gates d'entitlement (périodes custom, comparaisons, trends) s'appliquent bien
  dessus — c'est listé dans les critères de #22.
- Chaque issue impose `dart analyze` + tests + l10n EN/FR ; rien de bloquant
  entre eux.