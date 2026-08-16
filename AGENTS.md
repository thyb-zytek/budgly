# AGENTS.md

## Project

Flutter mobile app (Android + iOS only) — budget tracking. Package name `budgly`, Dart SDK `^3.12.2`, `flutter_lints`.

## Backend split (critical)

Auth and data live on **different backends**; per-feature the data provider differs:

- **Firebase Auth** = identity: email/password + Google Sign-In (`lib/src/core/auth/`, `lib/src/services/auth.dart`).
- **Supabase** = `user_profiles`, `accounts`, `categories`, and storage (`services/providers/supabase/`).
- **Cloud Firestore (legacy, still in use)** = `expenses`, budgets (`services/providers/firestore/`, models under `lib/src/models/budget/` and `lib/src/models/expense/`).

Each `services/*.dart` singleton orchestrates a provider + a `stores/*.dart` ChangeNotifier cache. To change a feature's backend, check which provider its service imports.

Supabase auth is a bridge: `main.dart` initializes Supabase with the Firebase ID token via `accessToken`, so Supabase RLS `auth.jwt() ->> 'sub'` equals the **Firebase UID**. RLS in `supabase_migrations/` enforces per-user access (profiles/accounts by `user_id`, categories via their account).

## Setup / secrets

- `assets/.env` is required at runtime — `SUPABASE_URL` and `SUPABASE_KEY` (main throws if missing). It is gitignored (`*/.env`), so check a teammate or Supabase project; do not commit it.
- `lib/firebase_options.dart` is gitignored — regenerate with FlutterFire CLI (`flutterfire configure`).
- Google Sign-In needs platform config: `android/app/google-services.json` (gitignored) / iOS `GoogleService-Info.plist`.
- Supabase schema/storage policies live in `supabase_migrations/` (001 tables + RLS, 002 buckets `accounts-pictures`, `config-files`). Apply changes via the Supabase CLI — there is no local DB.
- Storage picture paths are `$userId/$accountId/$fileName`; account picture URLs are fetched as signed URLs.

## Commands

- `flutter pub get` — runs l10n generation (`generate: true` in pubspec).
- `flutter analyze` — lint is `flutter_lints` with relaxations: `prefer_const_constructors*`, `use_key_in_widget_constructors`, `avoid_print` are all disabled. `print` is used on purpose.
- `flutter gen-l10n` — run after editing ARB files; generates `lib/l10n/app_localizations*.dart`.
- `dart run flutter_launcher_icons` — regenerate launcher icons from `assets/images/logo.png`.
- **Tests**: `test/period_test.dart` covers the `Period` model (requires `initializeDateFormatting` for `fr_FR`/`en_US` in `setUpAll`). `flutter test` must stay green.

## Conventions

- **Localization**: `flutter_intl` with ARB files in `lib/l10n/` (`intl_en.arb` template, `intl_fr.arb`). Default locale is `fr` (`AppConstants.defaultLocale`). When adding UI strings, add to both ARB files and regenerate.
- **State**: services (singletons, in-memory caches with validity from `AppConstants` — 5min short / 50min medium / 1 day long) → stores (ChangeNotifier) → ViewModels (`shared/view_models/base_view_model.dart`). Views listen via `ListenableBuilder`/`ChangeNotifier`.
- **Navigation**: go_router via `NavigationHelper` in `lib/src/core/routers/navigation_helper.dart` — routes: `/login`, `/tutorial`, and a shell with `/overview` + `/settings`; sign-in redirect and tutorial/overview branching live there.
- **Commit messages**: gitmoji-prefixed (`✨ ♻️ 📦 🎨 🗑️ …`), atomic. Full rules in `.devin/commit_guidelines.md` (French).
- **Font**: Saira variable font family (regular + italic) declared in pubspec; OFL license registered in `main.dart`.
