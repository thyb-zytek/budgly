import 'dart:io';

import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String initial;
  final String? picture;
  final bool isLocalPicture;
  final double size;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const Avatar({
    Key? key,
    required this.initial,
    this.picture,
    this.isLocalPicture = false,
    this.size = 45,
    this.onTap,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          style: theme.textTheme.titleLarge!.copyWith(
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    )
    );
  }
}
