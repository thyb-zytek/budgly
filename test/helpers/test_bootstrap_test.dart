import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'test_bootstrap.dart';

void main() {
  testWidgets('test bootstrap initializes bindings, assets and French locale data', (tester) async {
    await TestBootstrap.ensureInitialized();

    final license = await rootBundle.loadString('assets/fonts/saira/OFL.txt');
    expect(license, isNotEmpty);
    expect(DateFormat.yMMMM('fr').format(DateTime(2026, 3)), contains('mars'));
  });
}
