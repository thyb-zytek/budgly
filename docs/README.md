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

Après la phase 4, le projet privilégie une architecture MVVM pragmatique, un offline-first explicite et le minimum d’abstractions nécessaires. Les détails sont dans `ARCHITECTURE.md`.

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
- Toujours exécuter `flutter analyze` avant de commit

**Fichiers exclus du commit :**
- `firebase.json`, `supabase/` (config locale)
- `lib/l10n/app_localizations*.dart` (générés)
- `pubspec.lock`
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

### Architecture offline-first

Voir `docs/ARCHITECTURE.md` et `docs/OFFLINE_FIRST.md`. `docs/REFACTOR_AUDIT.md` décrit les refactors réalisés et les prochaines zones de travail.

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
flutter analyze

# Lancer les tests
flutter test

# Générer les icons d'app
dart run flutter_launcher_icons

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
├── docs/                        # ARCHITECTURE, OFFLINE_FIRST, ANALYTICS, TEST_COVERAGE, MANUAL_TEST_PLAN, etc.
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
- `ARCHITECTURE.md` — architecture et responsabilités actuelles
- `OFFLINE_FIRST.md` — contrat offline-first
- `ANALYTICS.md` — événements PostHog autorisés
- `TEST_COVERAGE.md` — inventaire des tests et priorités
- `REFACTOR_AUDIT.md` — état des refactors et prochaines zones de travail
