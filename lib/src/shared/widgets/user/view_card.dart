import 'package:flutter/material.dart';
import 'package:app/src/models/user/user.dart';
import 'package:app/l10n/app_localizations.dart';

class UserCard extends StatelessWidget {
  final User user;
  const UserCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primary,
              foregroundImage:
                  user.avatarUrl == null
                      ? null
                      : NetworkImage(user.avatarUrl!.toString()),
              child:
                  user.profile != null
                      ? Text(
                        user.profile!.fullName.characters.first.toUpperCase(),
                        style: theme.textTheme.titleLarge!.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                      : const Icon(Icons.person, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.profile?.fullName ?? tr.user,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
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
