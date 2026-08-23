import 'package:budgly/src/models/category/category_icon.dart';

class AppConstants {
  static const Duration cacheValidityShort = Duration(minutes: 5);
  static const Duration cacheValidityMedium = Duration(minutes: 50);
  static const Duration cacheValidityLong = Duration(days: 1);

  static const String bucketAccounts = 'accounts-pictures';
  static const String bucketConfig = 'config-files';

  static const String cacheCategoryIcons = 'cached_category_icons';

  static const String categoryIconsFileName = 'category_icons.json';

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

  static const CategoryIcon defaultCategoryIcon = CategoryIcon(
    iconName: 'category_rounded',
    iconCode: 0xf624,
    iconPack: 'MaterialIcons',
    labels: {'en': 'Category', 'fr': 'Catégorie'},
  );
}
