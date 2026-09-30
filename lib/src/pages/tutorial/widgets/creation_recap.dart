import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/pages/tutorial/tutorial_provider.dart';
import 'package:budgly/src/shared/ui/widgets/layout/avatar.dart';
import 'package:flutter/material.dart';

class CreationRecap extends StatelessWidget {
  final TutorialState state;
  final String accountName;
  const CreationRecap({
    super.key,
    required this.state,
    required this.accountName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final picture = state.accountPicture;
    final initial = accountName.isNotEmpty ? accountName[0].toUpperCase() : 'C';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(BudglySpacing.lg),
            child: Row(
              spacing: 16,
              children: [
                Avatar(
                  initial: initial,
                  backgroundColor: state.accountColor,
                  picture: picture,
                  isLocalPicture:
                      picture != null && !picture.startsWith('http'),
                  size: 48,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accountName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        tr.tutorialCategoryCount(
                          state.createdCategories.length,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.createdCategories.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              left: BudglySpacing.xxl,
              top: BudglySpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: state.createdCategories.map((category) {
                final color = category.color ?? theme.colorScheme.primary;
                return Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: category.icon != null
                          ? Icon(
                              category.icon!.toIconData(),
                              size: 16,
                              color: color,
                            )
                          : Icon(
                              Icons.category_rounded,
                              size: 16,
                              color: color,
                            ),
                    ),
                    Expanded(
                      child: Text(
                        category.name ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
