import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/services/errors.dart';
import 'package:flutter/material.dart';

class ServiceUnavailableScreen extends StatelessWidget {
  const ServiceUnavailableScreen({super.key});

  void _reloadApp() {
    ErrorService.instance.clearError();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            spacing: 64,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 16,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 80,
                    color: colorScheme.outlineVariant,
                  ),
                  Text(
                    tr.serviceUnavailableTitle,
                    style: textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Text(
                tr.serviceUnavailableMessage,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: ButtonType.primary.filledStyle(theme),
                      onPressed: _reloadApp,
                      iconAlignment: IconAlignment.start,
                      icon: Icon(
                        Icons.refresh,
                        color: ButtonType.primary.colors(theme).foreground,
                      ),
                      label: Text(
                        tr.reloadApp,
                        style: ButtonType.primary.labelStyle(theme),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
