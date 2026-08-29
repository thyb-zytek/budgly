import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/pages/tutorial/view_model.dart';
import 'package:budgly/src/shared/ui/widgets/layout/avatar.dart';
import 'package:flutter/material.dart';

class CreationRecap extends StatelessWidget {
  final TutorialViewModel viewModel;

  const CreationRecap({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(BudglySpacing.lg),
            child: Row(
              spacing: 16,
              children: [
                Avatar(
                  initial: viewModel.accountInitial,
                  backgroundColor: viewModel.accountColor,
                  picture: viewModel.accountPicture,
                  isLocalPicture: viewModel.isLocalPicture,
                  size: 48,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewModel.accountNameController.text,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        tr.tutorialCategoryCount(
                          viewModel.createdCategories.length,
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

        if (viewModel.createdCategories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: BudglySpacing.xxl, top: BudglySpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: viewModel.createdCategories.map((category) {
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
                          ? Icon(category.icon!.toIconData(), size: 16, color: color)
                          : Icon(Icons.category_rounded, size: 16, color: color),
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
