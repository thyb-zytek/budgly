import 'dart:io';

import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String initial;
  final String? picture;
  final bool isLocalPicture;
  final double size;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool showShadow;
  final bool canRemove;
  final VoidCallback? onRemove;

  const Avatar({
    super.key,
    required this.initial,
    this.picture,
    this.isLocalPicture = false,
    this.size = 45,
    this.onTap,
    this.backgroundColor,
    this.showShadow = false,
    this.canRemove = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showShadow)
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withAlpha(30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _buildAvatarContent(theme),
          )
        else
          _buildAvatarContent(theme),
        if (canRemove)
          Positioned(
            top: -2,
            right: -2,
            child: _RoundIconButton(
              icon: Icons.close_rounded,
              background: theme.colorScheme.surface,
              foreground: theme.colorScheme.error,
              onPressed: onRemove!,
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarContent(ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
      width: size,
      height: size,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: backgroundColor,
        foregroundImage:
            picture == null ? null : isLocalPicture ? FileImage(File(picture!)) : NetworkImage(picture!),
        child: Text(
          initial,
          style: size < 100 ? theme.textTheme.titleLarge!.copyWith(
            color: theme.colorScheme.onPrimary,
          ) : theme.textTheme.displayMedium!.copyWith(
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
      )
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  const _RoundIconButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: foreground),
        ),
      ),
    );
  }
}
