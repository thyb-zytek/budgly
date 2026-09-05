# Budgly

Application Flutter de suivi budgétaire personnel.

## Documentation

La documentation du projet se trouve dans [`docs/README.md`](docs/README.md).

Elle couvre notamment :

- l'architecture MVVM et les responsabilités des couches ;
- la stratégie offline-first et la synchronisation ;
- les dépenses récurrentes ;
- les tests et la couverture ;
- l'analytics PostHog ;
- les conventions de développement.

## Démarrage rapide

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

Pour lancer l'application, crée `assets/.env` à partir de `assets/.env.example` puis exécute :

```bash
flutter run
```
