import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared deterministic bootstrap for Flutter tests.
///
/// `flutter_test_config.dart` calls this before each test file. Keeping the
/// setup in one helper makes standalone tests and future test entry points
/// use exactly the same platform/locale assumptions.
class TestBootstrap {
  static Future<void> ensureInitialized() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // SharedPreferences has no native plugin implementation in `flutter test`.
    // Install the in-memory mock before any test/library code can request the
    // singleton (testExecutable runs before the individual test main).
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('en_US');
  }

  static void resetSharedPreferences() {
    SharedPreferences.setMockInitialValues({});
  }
}

