# AGENTS.md

## Project

Budgly is an Android and iOS Flutter budget-tracking application. It uses Dart
`^3.12.2` and `flutter_lints`.

## Architecture

The app follows pragmatic MVVM and is offline-first:

```text
View -> ViewModel -> Service -> Store / Provider -> Local cache / backend
```

- Views render state and do not access backends directly.
- ViewModels own screen state and orchestration. Check `isDisposed` before
  notifying after async work.
- Services own domain logic, local-first loading, synchronization, and
  provider access.
- Stores are singleton `ChangeNotifier` caches and must remain backend-agnostic.
- Show cached data immediately when available; refresh remotely in the
  background with `unawaited()` when the refresh does not block the UI.

See `docs/architecture.md` for the complete startup, routing, and sync model.

## Backend boundaries

Authentication and application data are intentionally split:

- Firebase Auth provides identity (email/password and Google Sign-In).
- Supabase owns profiles, accounts, categories, account-picture storage, and
  offline mutation replay through `SyncQueue`.
- Cloud Firestore still owns expenses and budgets. Its native persistent cache
  provides offline reads and writes, so do not enqueue Firestore mutations in
  `SyncQueue`.

The Firebase ID token bridges into Supabase, so its RLS subject is the Firebase
UID. Before changing persistence, confirm the feature's service and provider;
do not move a feature between backends accidentally.

## Startup and navigation

- Keep routing and cold-start UI local-only. Route guards must not perform
  network calls, reload data, or await Supabase.
- Startup awaits only essential infrastructure before `runApp()`; remote
  refreshes and analytics initialization happen afterward.
- `AuthSessionNotifier` and `ProfileService` drive router redirects. If a
  Firebase user exists while the local profile is still hydrating, wait for the
  next profile notification rather than fetching in a guard.

## Localization and UI

- The default locale is French. Add every user-visible string to both
  `lib/l10n/intl_en.arb` and `lib/l10n/intl_fr.arb`, then regenerate l10n.
- Preserve the Saira font setup declared in `pubspec.yaml`.
- Keep widgets focused on presentation; place reusable domain widgets under
  `lib/src/shared/domain/` and reusable UI primitives under `lib/src/shared/ui/`.

## Secrets and generated configuration

- `assets/.env` must contain `SUPABASE_URL` and `SUPABASE_KEY`. Never commit it.
- Firebase platform configuration and `lib/firebase_options.dart` are generated
  or environment-specific; regenerate them with FlutterFire when needed rather
  than hand-writing secrets.
- Apply database/storage policy changes through the Supabase CLI using
  `supabase_migrations/`; there is no local database to edit.

## Commands

- `flutter pub get` -- install dependencies and generate localizations.
- `flutter analyze` -- run static analysis.
- `flutter test` -- run the test suite.
- `flutter gen-l10n` -- regenerate localization output after ARB changes.
- `dart run flutter_launcher_icons` -- regenerate launcher icons after changing
  the source asset.

Run analysis and the relevant tests after changing Dart code. Do not edit files
under `build/` or generated localization output by hand.

## Change discipline

- Preserve existing worktree changes unless the task explicitly includes them.
- Keep changes small and feature-scoped; update/add tests for changed behavior.
- Keep commit messages atomic and gitmoji-prefixed, following
  `.devin/commit_guidelines.md`.
