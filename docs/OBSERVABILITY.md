# Budgly — Observabilité

> Source de vérité pour PostHog, Crashlytics et les règles de collecte.

## 1. Analytics PostHog



## Fonctionnement

PostHog est réservé aux événements produit explicites. Le tracking automatique des erreurs est désactivé ; Crashlytics est le canal technique de référence.

- Tous les événements passent par `AnalyticsService.instance.track(eventName, properties)`
- **Allowlist stricte** : seuls les événements listés dans `_allowedEvents` sont envoyés
- **Filtrage PII** : les clés suivantes sont automatiquement supprimées des propriétés :
  `amount`, `name`, `email`, `description`, `merchant`, `transaction`, `financial_data`, `picture`, `picture_url`, `avatar_url`, `full_name`
- Seuls les types `String`, `num`, `bool` et `null` sont autorisés comme valeurs
- En debug, les événements sont loggés via `AppLogger` au lieu d'être envoyés à PostHog
- L'`identify` est lancé après `runApp()` avec le `uid` Firebase afin que PostHog ne bloque pas le premier rendu

---

## Liste des événements

### Application

| Événement | Propriétés |
|-----------|------------|
| `app_started` | — |

### Navigation / Écrans

| Événement | Propriétés |
|-----------|------------|
| `screen_viewed` | `screen` (ex: `"overview"`, `"category_expenses"`) |
| `settings_opened` | — |

### Overview

| Événement | Propriétés |
|-----------|------------|
| `overview_refresh` | — |
| `overview_period_changed` | — |
| `overview_expense_loaded` | — |
| `account_switched` | — |
| `expense_form_opened` | — |
| `revenue_editor_opened` | — |
| `revenue_editor_closed` | — |

### Accounts

| Événement | Propriétés |
|-----------|------------|
| `account_created` | — |
| `account_updated` | — |
| `account_deleted` | — |
| `account_load_failed` | `error` |

### Categories

| Événement | Propriétés |
|-----------|------------|
| `category_created` | — |
| `category_updated` | — |
| `category_deleted` | — |
| `category_load_failed` | `error` |
| `category_expense_tap` | — |

### Expenses

| Événement | Propriétés |
|-----------|------------|
| `expense_created` | `recurring` (bool) |
| `expense_updated` | `recurring` (bool) |
| `expense_deleted` | — |
| `expense_update_failed` | `error` |
| `expense_delete_failed` | `error` |
| `expense_load_failed` | `error` |
| `expense_create_failed` | `error` |
| `expense_page_loaded` | `source` (`"pagination"`) |
| `expense_toggled_debited` | — |
| `recurring_expense_version_changed` | — |
| `recurring_expense_occurrence_modified` | — |
| `expense_single_occurrence_deleted` | — |
| `expense_future_occurrences_deleted` | — |
| `expense_single_occurrence_deleted` | — |
| `expense_future_occurrences_deleted` | — |

### Budget / Revenue

| Événement | Propriétés |
|-----------|------------|
| `budget_updated` | — |
| `revenue_set` | — |
| `revenue_load_failed` | `error` |
| `revenue_set_failed` | `error` |

### Profil

| Événement | Propriétés |
|-----------|------------|
| `profile_updated` | — |
| `profile_refresh` | — |

### Authentification

| Événement | Propriétés |
|-----------|------------|
| `login_started` | — |
| `login_completed` | — |
| `login_failed` | `error_code` |
| `signup_started` | — |
| `signup_completed` | — |
| `signup_failed` | `error_code` |
| `google_signin_started` | — |
| `google_signin_completed` | — |
| `google_signin_failed` | `error_code` |
| `password_reset_started` | — |
| `password_reset_completed` | — |
| `password_reset_failed` | `error_code` |
| `email_verification_sent` | — |
| `logout_completed` | — |
| `logout_failed` | — |

### Onboarding / Tutorial

| Événement | Propriétés |
|-----------|------------|
| `onboarding_started` | — |
| `onboarding_step_started` | `step` (int) |
| `onboarding_step_completed` | `step` (int) |
| `onboarding_completed` | — |
| `tutorial_account_created` | — |
| `tutorial_category_created` | — |
| `tutorial_budget_created` | — |

### Sync / Offline

| Événement | Propriétés |
|-----------|------------|
| `sync_started` | `pending_operations` (int) |
| `sync_completed` | — |
| `sync_failed` | `type` (ex: `"accounts"`) |
| `sync_queue_item_failed` | `type`, `operation` |

---

---

## Configuration PostHog

```dart
// Initialisation dans main.dart
AnalyticsService.instance.initialize(
  projectToken: dotenv.env['POSTHOG_API_KEY'],
  host: dotenv.env['POSTHOG_HOST'] ?? 'https://eu.i.posthog.com',
);

// Config PostHog
config.captureApplicationLifecycleEvents = false
config.capturePushNotificationOpened = false
config.capturePushNotificationSubscriptions = false
config.sessionReplay = false
// Le tracking automatique des erreurs reste désactivé.
// Crashlytics est le canal technique de référence.
```

Variables d'environnement requises :
- `POSTHOG_API_KEY` : Clé projet PostHog (format `phc_...`)
- `POSTHOG_HOST` : Host PostHog (défaut : `https://eu.i.posthog.com`)


---

## 2. Firebase Crashlytics



Le code (`main.dart`, `AppLogger`) est déjà câblé pour envoyer les crashs et
les erreurs non-fatales à Crashlytics. Il reste une étape de configuration
côté Firebase/plateformes à faire une seule fois par projet Firebase.

## 1. Activer Crashlytics dans la console Firebase

1. Ouvrir la [console Firebase](https://console.firebase.google.com/) → projet Budgly.
2. Menu **Build → Crashlytics** → cliquer sur **Get started / Activer**.
3. Aucune donnée n'apparaîtra tant qu'un premier crash n'a pas été envoyé
   par l'app (voir étape 4, test).

## 2. Android

1. Vérifier que `android/build.gradle` (niveau projet) déclare le plugin
   Google Services (normalement déjà présent puisque Firebase Auth est en
   place) :
   ```groovy
   buildscript {
     dependencies {
       classpath 'com.google.gms:google-services:...'
       classpath 'com.google.firebase:firebase-crashlytics-gradle:...'
     }
   }
   ```
2. Dans `android/app/build.gradle`, appliquer les deux plugins :
   ```groovy
   apply plugin: 'com.google.gms.google-services'
   apply plugin: 'com.google.firebase.crashlytics'
   ```
3. Pour que les stack traces natives (crashs NDK) soient lisibles, activer
   l'upload automatique des symboles de debug :
   ```groovy
   android {
     buildTypes {
       release {
         firebaseCrashlytics {
           nativeSymbolUploadEnabled true
         }
       }
     }
   }
   ```
4. `google-services.json` doit être à jour (déjà exclu du commit d'après
   `docs/README.md` — le récupérer depuis la console Firebase si besoin).

## 3. iOS

1. `ios/Runner/GoogleService-Info.plist` doit être présent (même remarque
   que pour Android — fichier de config locale, à récupérer sur la
   console Firebase si absent).
2. Ajouter une **Run Script Build Phase** dans Xcode (après "Embed
   Pods Frameworks") qui appelle le script fourni par le pod
   `FirebaseCrashlytics` pour uploader les dSYM :
   ```bash
   "${PODS_ROOT}/FirebaseCrashlytics/run"
   ```
   avec en *Input Files* :
   ```
   ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
   $(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
   ```
3. `flutter pub get` (via CocoaPods) installera le pod nécessaire —
   pas d'étape manuelle côté `Podfile` au-delà d'un `pod install`.

## 4. Vérifier que ça fonctionne

Avant de livrer, provoquer un crash de test en debug/release (à retirer
ensuite) :

```dart
FirebaseCrashlytics.instance.crash(); // crash natif immédiat
// ou, pour une erreur non-fatale :
FirebaseCrashlytics.instance.recordError('test error', StackTrace.current);
```

Le crash apparaît dans la console Firebase sous quelques minutes (parfois
jusqu'à mise en arrière-plan puis relance de l'app pour un crash natif,
Crashlytics envoyant le rapport au démarrage suivant).

## 5. Ce qui est déjà branché côté code

- `main.dart` : `FlutterError.onError` et `PlatformDispatcher.instance.onError`
  envoient toute erreur Flutter/Dart non interceptée à Crashlytics, en plus
  de la config existante.
- La collecte est activée dans tous les modes (debug, profile, release)
  pour que le bouton de test de la console Firebase fonctionne.
- `AppLogger.error(...)` et `AppLogger.warning(...)` — utilisés dans une
  quarantaine de `catch` à travers le code — envoient désormais aussi
  l'information à Crashlytics (`recordError` / `log`) en plus de l'affichage
  console en mode debug. Les appels sont protégés par un `try/catch` interne
  pour ne jamais faire planter un test unitaire qui n'a pas initialisé
  Firebase.

## 6. Ce qui reste à faire (hors scope de ce commit)

- Auditer au cas par cas les ~31 `catch (_)` qui ignoraient l'erreur : leur
  faire appeler `AppLogger.error(...)` avec l'exception réelle plutôt que de
  rester silencieux, pour que Crashlytics ait une trace exploitable
  (actuellement seuls les appels déjà passés par `AppLogger` bénéficient du
  nouveau câblage).
- Ajouter `FirebaseCrashlytics.instance.setUserIdentifier(uid)` au moment du
  login (dans `AuthService`), pour pouvoir filtrer les crashs par
  utilisateur en support.
