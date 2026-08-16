# Budgly — Architecture & structure du code

> Application Flutter de suivi de budget (Android + iOS uniquement). Ce document décrit la structure de `lib/`, la hiérarchisation du code et l'écart avec l'objectif produit final.

## 1. Vue d'ensemble

| Élément | Valeur |
|---|---|
| Package | `budgly` (Flutter, Dart SDK `^3.12.2`) |
| Cibles | Android + iOS |
| Identité | **Firebase Auth** (email/password + Google Sign-In) |
| Données | **Supabase** (`user_profiles`, `accounts`, `categories`, storage) |
| Données (legacy) | **Cloud Firestore** (`expenses`, budgets `account_budgets`/`category_budgets`) |
| Localisation | `flutter_intl`, ARB (`intl_en.arb` / `intl_fr.arb`), locale par défaut **fr** |

### Double backend (point critique)

Le pont Firebase → Supabase se fait dans `main.dart` : Supabase est initialisé avec `accessToken: () => currentUser?.getIdToken()`. En RLS, `auth.jwt() ->> 'sub'` vaut donc le **Firebase UID** ; les tables Supabase stockent `user_id` = UID Firebase.

Chaque feature a un backend différent. Pour savoir où vit une donnée, regarder quel provider importe son service :

| Feature | Backend | Fichiers |
|---|---|---|
| Comptes, catégories, profil | Supabase | `services/providers/supabase/` |
| Dépenses | Firestore | `services/providers/firestore/expenses.dart` |
| Budgets (revenu / par catégorie) | Firestore | `services/providers/firestore/accounts_budget.dart`, `categories_budget.dart` |

## 2. Hiérarchie de `lib/src/`

```
lib/
├── main.dart                        # boot : env, Firebase, Supabase, session, runApp
├── firebase_options.dart            # généré (gitignored), CLI FlutterFire
├── l10n/                            # ARB + app_localizations*.dart générés
└── src/
    ├── core/                        # infrastructure
    │   ├── auth/                    # session/état auth, Google Sign-In
    │   ├── constants/               # AppConstants (durées de cache, clés, bucket)
    │   ├── error/ + exceptions/     # ErrorService, ErrorHandler
    │   ├── extensions/              # HexColor, CurrencyIcon
    │   ├── loading/                 # ProgressiveLoader
    │   ├── logging/                 # AppLogger
    │   ├── routers/                 # NavigationHelper (go_router)
    │   └── theme/                   # thème M3, styles boutons/inputs, snackbar, bottom sheet
    ├── models/                      # domaines purs, par feature :
    │   ├── account/  category/  expense/  budget/  user/
    │   └── (chaque dossier contient <entité>.dart + <entité>_editing_data.dart)
    ├── pages/                       # écrans + ViewModels :
    │   ├── login/  tutorial/  overview/  settings/  error/
    │   └── (view.dart + view_model.dart + widgets/, un dossier par onglet Settings)
    ├── services/                    # singletons (orchestration)
    │   └── providers/               # backends
    │       ├── firestore/  supabase/
    ├── shared/                      # réutilisable
    │   ├── view_models/             # BaseViewModel
    │   └── widgets/                 # sélecteurs, inputs, tabs, etc.
    └── stores/                      # caches ChangeNotifier (singletons)
```

### Flux des données

```
view.dart (ListenableBuilder)
   │
   ▼
view_model.dart  ── étend BaseViewModel (chargement + gestion d'erreurs)
   │
   ▼
services/*.dart (singletons, cache en mémoire)
   │  └── stores/*.dart (ChangeNotifier)  ← cache consultable par l'UI
   ▼
providers/{firestore,supabase}/*.dart
   ▼
Firebase Auth / Supabase / Cloud Firestore
```

Les **services** orchestrent un provider + un store ; les **VMs** écoutent les services (pas les providers directement) ; les **views** écoutent les VMs.

## 3. Modèles de domaine

### Comptes & catégories

- `Account` (`models/account/account.dart`) : `id`, `userId`, `name`, `picture`, `pictureUrl`, `color`. Un utilisateur a **1 ou N comptes**.
- `Category` (`models/category/category.dart`) : `id`, `name`, `color`, `icon`/`iconCode`, `accountId` (FK → compte). **Chaque compte a ses propres catégories**.

### Dépenses (one-shot vs récurrentes)

- `Expense` (`models/expense/expense.dart`) : `id`, `accountId`, `categoryId`, `name`, `amount`, `debitDate`, `recurrence`, `isDebited`, timestamps.
- `RecurrenceType` (`models/expense/recurrence.dart`) : enum `none | daily | weekly | monthly | yearly | bimonthly | trimonthly | halfyearly | biyearly`.
  - **One-shot** = `recurrence: none`, portée par la période de sa création.
  - **Récurrente** = `recurrence` différent de `none` (tous les X mois/…).
- **Suivi banque** : `isDebited` (booléen, défaut `false`) — l'icône `check` dans la liste de l'overview le reflète.
- `ExpenseEditingData` (`models/expense/expense_editing_data.dart`) : état du formulaire (contrôleurs) avant création.

### Budgets & période

- `Period` (`models/budget/period.dart`) : `year`, `month` ; helpers `startOfMonth/endOfMonth/contains/addMonths`.
- `AccountBudget` (`models/budget/account_budget.dart`) : `accountId`, `year`, `month`, `revenue` → **revenu saisi pour la période**.
- `CategoryBudget` (`models/budget/category_budget.dart`) : `categoryId`, `accountId`, `year`, `month`, `amount` (budget par catégorie).

### Utilisateur

- `User` (`models/user/user.dart`) : identité Firebase (uid, email, vérifié).
- `UserProfile` (`models/user/user_profile.dart`) : profil Supabase (nom, avatar, couleur, `theme_mode`, `currency`, `language`).

## 4. Services & providers

Singletons `services/*.dart` et leur backend + durée de cache (`AppConstants` : court 5 min / moyen 50 min / long 1 jour) :

| Service | Backend | Cache |
|---|---|---|
| `auth.dart` | Firebase Auth + seed `user_profiles` | — |
| `accounts.dart` | Supabase `accounts` + storage `accounts-pictures` | 50 min |
| `categories.dart` | Supabase `categories` (join `account`) | 5 min / compte |
| `expenses.dart` | Firestore `users/{uid}/expenses` | 5 min / compte |
| `accounts_budget.dart` | Firestore `users/{uid}/account_budgets` | flag `hasLoaded` |
| `categories_budget.dart` | Firestore `users/{uid}/category_budgets` | flag `hasLoaded` |
| `profile.dart` | Supabase `user_profiles` + SharedPreferences (préférences : thème/locale/devise) | — |
| `category_icons.dart` | Storage `config-files` (`category_icons.json`) | 1 jour |
| `image.dart` | image_picker + image_cropper | — |
| `errors.dart` | flag `hasError` → écran « service indisponible » | — |

Providers :
- **Supabase** : `client.dart` (getter `Supabase.instance.client`), `accounts.dart`, `categories.dart` (select avec `account:accounts(*)`), `user_profiles.dart` (pattern update-puis-insert, gestion PGRST116/303, refresh JWT), `storage.dart` (upload clé `$userId/$accountId/$fileName`, URLs signées ~1 h).
- **Firestore** : `expenses.dart` (`where accountId`, `orderBy debitDate desc`), `accounts_budget.dart` / `categories_budget.dart` (doc `${accountId}_${year}_$month`, `set(merge:true)`).

## 5. Stores (caches ChangeNotifier)

Singletons dans `stores/` : `AccountsStore`, `CategoriesStore` (map par compte), `ExpensesStore` (map par compte), `ProfileStore`, `AccountBudgetsStore` / `CategoryBudgetsStore` (clés `${id}_${year}_$month`). Gèrent l'état (`isLoading`, `hasLoaded`) et notifient l'UI.

## 6. Pages & parcours

- **Login** (`pages/login/`) : machine à états `AuthState`/`AuthForm` — signup / signin / reset password / vérification email (polling 5 s) / Google Sign-In. À l'auth : chargement des comptes → `/overview` s'il y en a, sinon `/tutorial`.
- **Tutorial** (`pages/tutorial/`) : placeholder (à remplacer par un vrai onboarding).
- **Overview** (`pages/overview/`) : le cœur de l'app.
  - `AccountSummary` (SliverPersistentHeader) : sélecteur de compte, **donut par catégorie** avec au centre le **revenu éditable** + le **restant**, stats revenu / dépenses / restant, légende des catégories.
  - Liste des dépenses de la période (icône check si `isDebited`).
  - FAB → `ExpenseForm` (bottom sheet) : compte, catégorie, nom, montant, date de débit, **options avancées = récurrence + date de débit**.
  - `PeriodSelector` existe mais n'est **pas branché** sur la période courante.
- **Settings** (`pages/settings/`) : `SwipeTabs` — Comptes (CRUD), Catégories (icônes + couleurs), Préférences (thème/locale/devise), Profil (nom, mot de passe, déconnexion).
- **Erreur** : écran global « service indisponible » piloté par `ErrorService`.

## 7. Routage

`NavigationHelper` (`core/routers/navigation_helper.dart`) construit le `GoRouter` :
- `/login`, `/tutorial`, et un shell `StatefulShellRoute.indexedStack` (`/overview` + `/settings`, barre basse `BottomNavBar`).
- `refreshListenable: AuthSessionNotifier` ; redirect : sans user → `/login` ; user non vérifié → reste sur login ; sinon `/overview` ou `/tutorial` selon l'existence de comptes.

## 8. Widgets partagés (`shared/`)

`BaseViewModel` (loading + `ErrorHandler`), `Selector<T>` générique, `TextInput` (`InputType`), `TabSwitcher` / `SwipeTabs`, `ColorWheel`, `Avatar`, `AccountSelector` / `CategorySelector`, `CategoryIcon`, `UserCard` / `UserDetails`, `BottomNavBar`, `AppLoadingIndicator` (spinner centré), `EmptyState` (icône + titre + sous-titre).

Helpers UI centralisés : `showAppBottomSheet` (`core/theme/bottom_sheet.dart`), `showAppSnackBar` (`core/theme/snackbar.dart`), extension `CurrencyIcon` (`core/extensions/currency.dart`).

## 9. Conventions

- **État** : services (singletons, cache en mémoire avec validité `AppConstants`) → stores (ChangeNotifier) → ViewModels (`BaseViewModel`). L'UI écoute via `ListenableBuilder` / `ChangeNotifier`.
- **Localisation** : ajouter les chaînes dans `intl_en.arb` + `intl_fr.arb`, puis `flutter gen-l10n`.
- **Lint** : `flutter_lints` assoupli (`prefer_const_constructors*`, `use_key_in_widget_constructors`, `avoid_print` désactivés). `flutter analyze`.
- **Commits** : gitmoji (`✨ ♻️ 📦 🎨 🗑️ …`), atomiques — voir `.devin/commit_guidelines.md`.
- **Migrations** : schéma/Rls Supabase dans `supabase_migrations/` (001 tables + RLS, 002 buckets `accounts-pictures` + `config-files`) ; appliquer via la CLI Supabase (pas de DB locale).

## 10. Écarts avec l'objectif produit final

L'objectif final : comptes → catégories par compte → dépenses one-shot (période = 1 mois) ou récurrentes (tous les X mois) → suivi débité/non débité vs compte bancaire → total dépenses et restant vs revenu de la période.

| Attendu | État du code |
|---|---|
| Comptes multiples + catégories par compte | ✅ Fait (Supabase) |
| Dépense one-shot sur la période de création | ✅ Partiellement : `debitDate` défini, filtre par `debitDate` |
| Dépenses récurrentes (tous les X mois) | ⚠️ Stocké (`recurrence`) mais **aucune matérialisation** des occurrences futures ; l'overview ne filtre que par `debitDate` |
| Suivi débité / non débité (`isDebited`) | ⚠️ Champ + icône dans la liste, mais **aucune UI pour basculer** la valeur ; pas d'édition/suppression de dépense |
| Revenu par période + restant | ✅ Fait (donut au centre : revenu éditable, restant) ; navigation de période (`PeriodSelector`) à câbler |
| Total dépenses / restant | ✅ Affiche via `AccountSummary` |
| Budget par catégorie (`CategoryBudget`) | ⚠️ Modèle/provider/store existent, **aucune page ne les exploite** |
| Connexion API bancaire (futur) | ❌ Aucun SDK ; `isDebited` reste manuel |
| Onboarding | ❌ Tutorial = placeholder |

Couverture de test limitée : seul `test/period_test.dart` existe (tests unitaires du modèle `Period`).
