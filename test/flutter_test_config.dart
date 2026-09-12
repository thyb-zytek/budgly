import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';

import 'helpers/test_bootstrap.dart';

/// Test-wide bootstrap run before every test file under [test/].
///
/// BudglySpacing relies on `flutter_screenutil_plus` (`.w`), which needs a
/// static configuration before any widget builds. The design width matches the
/// default test surface (360 logical px) so `.w` yields the raw authored
/// value (scale 1.0) and keeps existing tests and goldens deterministic
/// regardless of the surface size used by an individual test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await TestBootstrap.ensureInitialized();
  ScreenUtilPlus.configure(
    data: const MediaQueryData(size: Size(360, 740)),
    designSize: const Size(360, 690),
    minTextAdapt: false,
    splitScreenMode: false,
  );
  try {
    await testMain();
  } finally {
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    TestBootstrap.resetSharedPreferences();
  }
}