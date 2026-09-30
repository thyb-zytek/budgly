import 'package:budgly/src/models/category/category_icon.dart';

class AppConstants {
  static const String bucketAccounts = 'accounts-pictures';

  static const String cacheCategoryIcons = 'cached_category_icons';

  static const String loginFormTypeKey = 'LoginDefaultFormType';

  // Local preference cache keys are scoped per Firebase uid (RL-01 §1.3):
  // they are only ever a fast local mirror of `UserProfile`'s preference
  // fields, never an independent source of truth, so they must not leak
  // between accounts sharing a device nor survive as stale global state once
  // nobody is signed in.
  static const String _themeKeyPrefix = 'theme_mode_';
  static const String _localeKeyPrefix = 'app_locale_';
  static const String _currencyKeyPrefix = 'app_currency_';
  static const String _amountDecimalPlacesKeyPrefix = 'amount_decimal_places_';
  static String themeKey(String uid) => '$_themeKeyPrefix$uid';
  static String localeKey(String uid) => '$_localeKeyPrefix$uid';
  static String currencyKey(String uid) => '$_currencyKeyPrefix$uid';
  static String amountDecimalPlacesKey(String uid) =>
      '$_amountDecimalPlacesKeyPrefix$uid';

  static const String tutorialStepKeyPrefix = 'tutorial_step_';
  static const String tutorialCompletedKeyPrefix = 'tutorial_completed_';

  static String tutorialStepKey(String uid) => '$tutorialStepKeyPrefix$uid';
  static String tutorialCompletedKey(String uid) =>
      '$tutorialCompletedKeyPrefix$uid';

  static const List<String> supportedCurrencies = ['EUR', 'USD', 'GBP'];

  static const String defaultLocale = 'fr';
  static const String defaultCurrency = 'EUR';

  static const int maxFutureExpenseDays = 365 * 5;

  /// Timeout applied to outbound network calls (Supabase/Firestore reads and
  /// writes). Centralized here instead of being repeated as a magic
  /// `Duration(seconds: 8)` literal across every provider/service.
  static const Duration networkTimeout = Duration(seconds: 8);

  static const int maxUploadSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const List<String> allowedUploadExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  static final CategoryIcon defaultCategoryIcon = CategoryIcon(
    iconName: 'category_rounded',
    iconCode: 0xf624,
    iconPack: 'MaterialIcons',
    labels: {'en': 'Category', 'fr': 'Catégorie'},
  );
}
