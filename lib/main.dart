import 'package:app/firebase_options.dart';
import 'package:app/src/app.dart';
import 'package:app/src/core/routers/base.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsBinding _ = WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/saira/OFL.txt');
    yield LicenseEntryWithLineBreaks(['assets/fonts/saira/'], license);
  });

  Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).then(
    (_) {
      NavigationHelper.instance;

      runApp(const BudglyApp());
    },
  );

}
