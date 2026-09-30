import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/settings/accounts/tab.dart';
import 'package:budgly/src/pages/settings/categories/tab.dart';
import 'package:budgly/src/pages/settings/preferences/tab.dart';
import 'package:budgly/src/pages/settings/profile/tab.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:budgly/src/shared/ui/widgets/tabs/swipe_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider).track('settings_opened');
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    return SwipeTabs(
      tabs: [
        Text(tr.accounts),
        Text(tr.categories),
        Text(tr.preferences),
        Text(tr.profile),
      ],
      children: const [
        AccountsTab(),
        CategoriesTab(),
        PreferencesTab(),
        ProfileTab(),
      ],
    );
  }
}
