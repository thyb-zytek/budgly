import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/services/errors.dart';
import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:flutter/material.dart';

class ServiceUnavailableScreen extends StatelessWidget {
  const ServiceUnavailableScreen({super.key});

  void _reloadApp() {
    ErrorService.instance.clearError();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                    child: BudglyButton(
                      text: tr.reloadApp,
                      leadingIcon: Icons.refresh,
                      onPressed: _reloadApp,
                      type: ButtonType.primary,
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
