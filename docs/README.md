# Documentation Budgly

La documentation est volontairement regroupée par thème. Il n'y a plus de documents parallèles pour le même sujet.

| Document | Rôle |
|---|---|
| `STATUS.md` | État des lieux courant et prochains points de validation |
| `ARCHITECTURE.md` | Architecture, DI, state ownership, dates, offline-first |
| `DEVELOPMENT.md` | Règles de développement et Definition of Done |
| `REFACTORING.md` | Plan de refactorisation et état du chantier technique |
| `PRODUCT.md` | Vision, fonctionnalités, roadmap, modèle économique et décisions produit |
| `QUALITY.md` | Tests, campagne manuelle, performance et startup |
| `OBSERVABILITY.md` | PostHog et Crashlytics |

## Règle de maintenance

`STATUS.md` est le point d'entrée pour connaître l'état actuel. Lorsqu'un refactor modifie l'état du projet, mettre à jour `STATUS.md` et `REFACTORING.md`. Lorsqu'une règle de développement change, mettre à jour `DEVELOPMENT.md`. Les détails spécifiques doivent être ajoutés au document thématique existant plutôt que de créer un nouveau document isolé.
