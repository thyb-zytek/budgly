import 'dart:io';

import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String initial;
  final String? picture;
  final bool isLocalPicture;
  final double size;
  final VoidCallback? onTap;
  final Color? backgroundColor;
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
    this.canRemove = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: CircleAvatar(
              radius: size / 2,
              backgroundColor: backgroundColor,
              foregroundImage: picture == null
                  ? null
                  : isLocalPicture
                  ? FileImage(File(picture!))
                  : NetworkImage(picture!),
              child: Text(
                initial,
                style: size < 100
                    ? theme.textTheme.titleLarge!.copyWith(
                        color: theme.colorScheme.onPrimary,
                      )
                    : theme.textTheme.displayMedium!.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
              ),
            ),
          ),
        ),
        if (canRemove)
          Positioned(
            top: -2,
            right: -2,
            child: Material(
              color: theme.colorScheme.surface,
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: Colors.black26,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove!,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}