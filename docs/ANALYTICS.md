# Analytics - Événements PostHog

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
