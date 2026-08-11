import 'package:budgly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class EmptyCategories extends StatelessWidget {
  final String accountName;
  
  const EmptyCategories({super.key, required this.accountName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          Container(
            padding: EdgeInsets.all(24).copyWith(bottom: 40),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.category_rounded,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            tr.noCategoryFound,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            tr.addCategoriesToAccount(accountName),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}