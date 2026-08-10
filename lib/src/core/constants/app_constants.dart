class AppConstants {
  // Cache validity durations
  static const Duration cacheValidityShort = Duration(minutes: 5);
  static const Duration cacheValidityMedium = Duration(minutes: 50);
  static const Duration cacheValidityLong = Duration(days: 1);

  // Supabase bucket names
  static const String bucketAccounts = 'accounts-pictures';
  static const String bucketConfig = 'config-files';

  // Cache keys
  static const String cacheCategoryIcons = 'cached_category_icons';

  // File names
  static const String categoryIconsFileName = 'category_icons.json';

  // Form keys
  static const String loginFormTypeKey = 'LoginDefaultFormType';

  // Preference keys
  static const String themeKey = 'theme_mode';
  static const String localeKey = 'app_locale';
  static const String currencyKey = 'app_currency';

  // Supported currencies
  static const List<String> supportedCurrencies = ['EUR', 'USD', 'GBP'];

  // Default values
  static const String defaultLocale = 'fr';
  static const String defaultCurrency = 'EUR';
  static const int defaultIconCode = 0xf624;
}