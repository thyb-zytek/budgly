import 'package:budgly/src/models/category/category_icon.dart';

class AppConstants {

  static const String bucketAccounts = 'accounts-pictures';

  static const String cacheCategoryIcons = 'cached_category_icons';


  static const String loginFormTypeKey = 'LoginDefaultFormType';

  static const String themeKey = 'theme_mode';
  static const String localeKey = 'app_locale';
  static const String currencyKey = 'app_currency';
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

  static const CategoryIcon defaultCategoryIcon = CategoryIcon(
    iconName: 'category_rounded',
    iconCode: 0xf624,
    iconPack: 'MaterialIcons',
    labels: {'en': 'Category', 'fr': 'Catégorie'},
  );
}
