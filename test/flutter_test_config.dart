import 'dart:async';

import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';

import 'helpers/test_bootstrap.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await TestBootstrap.ensureInitialized();
  try {
    await testMain();
  } finally {
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    TestBootstrap.resetSharedPreferences();
  }
}
