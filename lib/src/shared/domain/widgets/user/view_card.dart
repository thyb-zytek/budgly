import 'package:flutter/material.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/l10n/app_localizations.dart';

class UserCard extends StatelessWidget {
  final User user;
  const UserCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(BudglySpacing.lg),
        child: Row(
          spacing: BudglySpacing.lg,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primary,
              foregroundImage:
                  user.avatarUrl == null
                      ? null
                      : NetworkImage(user.avatarUrl!.toString()),
              onForegroundImageError:
                  user.avatarUrl == null ? null : (exception, stackTrace) {},
              child:
                  user.profile != null
                      ? Text(
                        user.profile!.fullName.characters.first.toUpperCase(),
                        style: theme.textTheme.headlineLarge!.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                      : const Icon(Icons.person, size: 30),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BudglySpacing.xs,
                children: [
                  Text(
                    user.profile?.fullName ?? tr.user,
                    style: theme.textTheme.headlineMedium,
                  ),
                  Text(
                    user.email ?? tr.emailNotAvailable,
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
    );
  }
}
