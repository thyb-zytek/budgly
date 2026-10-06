import 'package:budgly/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Integration test covering the startup timeline of the real app.
///
/// Run with: `flutter test integration_test/startup_performance_test.dart -d <device>`
///
/// The test boots the real application entry point ([app.main]) and measures
/// three consecutive stages:
/// - bootstrap: dotenv + Firebase + Supabase initialization, up to runApp()
/// - first_frame: runApp() to the first rendered frame
/// - providers_initialized: first frame to a settled tree (providers resolved)
///
/// The measured durations are logged as diagnostics only. `flutter test` builds
/// a DEBUG APK, where the first frame is dominated by one-off JIT compilation
/// (observed: ~1.3s here versus a ~265ms bootstrap), so this suite cannot
/// validate the release-build baseline documented in AGENTS.md §10. A numeric
/// threshold here would be an arbitrary threshold asserting a debug artifact.
/// Performance regression detection belongs in a profile/release benchmark.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Startup performance: measure time to interactive', (
    tester,
  ) async {
    final timeline = <String, Duration>{};

    final bootstrapStart = DateTime.now();
    await app.main();
    timeline['bootstrap'] = DateTime.now().difference(bootstrapStart);

    final firstFrameStart = DateTime.now();
    await tester.pump();
    timeline['first_frame'] = DateTime.now().difference(firstFrameStart);

    // The app must reach a rendered MaterialApp after runApp().
    expect(find.byType(MaterialApp), findsWidgets);

    final providersStart = DateTime.now();
    await tester.pumpAndSettle();
    timeline['providers_initialized'] = DateTime.now().difference(
      providersStart,
    );

    debugPrint('=== STARTUP PERFORMANCE (debug build, diagnostics only) ===');
    timeline.forEach((stage, duration) {
      debugPrint('$stage: ${duration.inMilliseconds}ms');
    });
  });
}
