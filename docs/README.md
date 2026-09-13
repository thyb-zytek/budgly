# Budgly - Vue d'ensemble

## Description

**Budgly** est une application Flutter de suivi budgétaire personnel (v1.1.0+1). Elle permet de gérer des comptes, catégories, dépenses (ponctuelles et récurrentes) et des budgets/revenus mensuels par compte.

**Stack technique :**
- **Frontend** : Flutter (Dart SDK ^3.12.2)
- **Auth** : Firebase Auth (email + Google Sign-In)
- **Base de données** : Cloud Firestore (dépenses, budgets) + Supabase PostgreSQL (comptes, catégories, profils)
- **Stockage fichiers** : Supabase Storage
- **Analytics** : PostHog
- **Offline** : cache local SharedPreferences pour Supabase + persistance offline native Firestore + SyncQueue pour les mutations Supabase
- **Routing** : go_router
- **Locales** : FR (défaut) + EN

---

## État du projet

Après la phase 6, le projet privilégie une architecture MVVM pragmatique, un offline-first explicite et le minimum d’abstractions nécessaires. Les détails sont dans `ARCHITECTURE.md`.

## Guidelines

### Git

Les commits suivent les conventions **gitmoji** ([carloscuesta/gitmoji](https://github.com/carloscuesta/gitmoji)).

**Format :**
```
<gitmoji> <titre max 50 caractères>

<description détaillée (optionnelle)>
```

**Gitmojis principaux :**

| Emoji | Usage |
|-------|-------|
| ✨ | Nouvelle fonctionnalité |
| 🐛 | Correction de bug |
| ♻️ | Refactorisation |
| 🎨 | Structure/format du code |
| 💄 | UI et style |
| 🔧 | Fichiers de config |
| 📦 | Packages/compilés |
| 🔥 | Suppression de code |
| ✅ | Tests |
| 🌐 | Internationalisation |
| 🩹 | Fix mineur non-critique |
| 👔 | Logique métier |
| 🗃️ | Changements BDD |
| 🚑️ | Hotfix critique |

**Règles :**
- Commits **atomiques** (une seule fonctionnalité par commit)
- Ne jamais inclure de signatures Devin dans les messages
- Toujours exécuter `dart analyze` avant de commit (voir § Commandes Flutter — seul
  `dart analyze` remonte les diagnostics de `riverpod_lint`)

**Fichiers exclus du commit :**
- `firebase.json`, `supabase/` (config locale)
- `lib/l10n/app_localizations*.dart` (générés)
- `**/*.g.dart` (générés par `riverpod_generator`/`build_runner`, migration en
  cours — voir issue M0 ; régénérés via `dart run build_runner build`, y compris
  en CI avant `dart analyze`/`flutter test`)
- `assets/.env` (secrets)
- `android/app/google-services.json`, `lib/firebase_options.dart`

### Tests

```bash
# Lancer tous les tests
flutter test

# Lancer un fichier spécifique
flutter test test/period_test.dart

# Lancer avec couverture
flutter test --coverage
```

Les tests couvrent la logique pure : math de récurrence, Period, calculators, queue de sync, parsing de montants.

### Analytics PostHog

- Les événements sont trackés via `AnalyticsService.instance.track()`
- **Allowlist stricte** : seuls les événements listés dans `_allowedEvents` sont autorisés
- **Filtrage PII** : les clés sensibles (`amount`, `name`, `email`, `merchant`, etc.) sont automatiquement supprimées
- Voir `docs/ANALYTICS.md` pour la liste complète des événements

### CI

Le workflow `.github/workflows/main.yml` se déclenche sur `push` vers
`master`, sur `pull_request` vers `master`, et sur un cron hebdomadaire de
"keep-alive" (évite la dérive de dépendances sur un repo peu actif).

- Le job `test` (`dart analyze` + `flutter test`) tourne sur toute PR
  avant merge — la branche `master` doit être protégée en conséquence côté
  réglages GitHub (statut requis avant merge).
- Le job `build` (APK release) ne tourne **pas** sur les pull requests
  (inutile de builder un APK à chaque PR, et les secrets ne sont pas
  garantis disponibles en contexte PR) — seulement sur push `master`,
  `workflow_dispatch` et le cron.
- Les deux jobs exécutent `dart run build_runner build` avant toute autre
  étape, car les fichiers générés par `riverpod_generator` (`*.g.dart`) ne
  sont pas commités (voir ci-dessus).
- L'analyse passe par `dart analyze`, **pas** `flutter analyze`. Depuis
  `riverpod_lint` 3.x (plugin `analysis_server_plugin` déclaré dans le champ
  top-level `plugins:` de `analysis_options.yaml`), `flutter analyze` souffre
  d'un bug connu qui sort avant que les diagnostics des plugins soient
  reportés (flutter/flutter#28327). `dart analyze` les remonte correctement ;
  si `flutter analyze` est corrigé, on pourra y revenir.

### Guideline de développement

`DEVELOPMENT_FEATURE_GUIDELINE.md` définit les requirements à respecter pour développer et valider une nouvelle fonctionnalité : architecture, offline-first, UI/UX, tests, analytics, performance et Definition of Done.

### Architecture offline-first

Voir `docs/ARCHITECTURE.md` pour l'architecture MVVM pragmatique et le contrat offline-first.

### Mise à jour des docs

Les docs sont dans `docs/`. Les fichiers générés à ne pas commit :
- `lib/l10n/app_localizations*.dart`

---

## Navigation et commandes

### Prérequis

- Flutter SDK (chemin selon ton setup, ex: `C:\flutter\bin` ou via FVM)
- Dart SDK ^3.12.2
- Un émulateur ou appareil connecté
- Fichier `assets/.env` (copier depuis `assets/.env.example`)

### Variables d'environnement

Créer `assets/.env` :
```
SUPABASE_URL=
SUPABASE_KEY=
POSTHOG_API_KEY=phc_your_project_key
POSTHOG_HOST=https://eu.i.posthog.com
```

### Commandes Flutter

```bash
# Installer les dépendances
flutter pub get

# Lancer en dev
flutter run

# Analyser le code (AVANT chaque commit)
# `dart analyze` (et non `flutter analyze`) : seul `dart analyze` charge le
# plugin riverpod_lint et remonte ses diagnostics (voir § CI).
dart analyze

# Lancer les tests
flutter test

# Générer les icons d'app
dart run flutter_launcher_icons

# Générer le code Riverpod (providers @riverpod)
dart run build_runner build

# ... en mode watch pendant le dev
dart run build_runner watch

# Générer la localisation
flutter gen-l10n

# Build release Android
flutter build apk --release

# Build release iOS
flutter build ios --release
```

### Structure des répertoires

```
budgly/
├── lib/
│   ├── l10n/                    # ARB + générés
│   └── src/
│       ├── app.dart
│       ├── main.dart
│       ├── core/                # auth, navigation, theme/design_tokens, extensions, validation, errors, view_models
│       ├── models/              # account, category, expense, budget, user, period
│       ├── pages/               # overview, category_expenses, login, tutorial, settings (+ view_model, ui_state, widgets)
│       ├── services/            # accounts, categories, expenses, budget, profile, auth, analytics, offline (SyncQueue/LocalCache), calculators
│       ├── shared/              # domain/widgets (account, category, expense) + ui/widgets (forms, inputs, layout, feedback)
│       └── stores/              # AccountsStore, CategoriesStore, ExpensesStore, AccountBudgetsStore, ProfileStore
├── assets/                      # images, fonts/saira, .env, icons/category_icons.json
├── docs/                        # README, ARCHITECTURE, ANALYTICS, TEST_COVERAGE, MANUAL_TEST_PLAN, etc.
├── supabase_migrations/         # Migrations SQL
├── test/                        # unit + widget (models, services, pages, shared, stores, period)
├── android/                     # Gradle 9.1 / KGP, build.gradle.kts
└── ios/                         # Config iOS
```

### Path Flutter (Windows)

Selon ton installation :
- **FVM** : `fvm flutter <command>`
- **Install classique** : `C:\flutter\bin\flutter <command>`
- **VS Code** : Le terminal intégré détecte généralement le SDK automatiquement


### Documentation technique
- `ARCHITECTURE.md` — architecture et responsabilités actuelles + contrat offline-first
- `DEVELOPMENT_FEATURE_GUIDELINE.md` — exigences de développement et Definition of Done des nouvelles fonctionnalités
- `ANALYTICS.md` — événements PostHog autorisés
- `CRASHLYTICS.md` — activation et vérification de Firebase Crashlytics
- `MANUAL_TEST_PLAN.md` — campagne manuelle minimale
- `MODELE_ECONOMIQUE.md` — modèle économique de lancement
- `TEST_COVERAGE.md` — inventaire des tests, contrats offline et priorités
