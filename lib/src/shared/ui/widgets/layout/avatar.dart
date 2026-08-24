import 'dart:io';

import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String initial;
  final String? picture;
  final bool isLocalPicture;
  final double size;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final bool canRemove;
  final VoidCallback? onRemove;
  final bool showEditBadge;

  const Avatar({
    super.key,
    required this.initial,
    this.picture,
    this.isLocalPicture = false,
    this.size = 45,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 2.5,
    this.canRemove = false,
    this.onRemove,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBorderColor = borderColor ?? backgroundColor;
    final innerRadius =
        effectiveBorderColor == null ? size / 2 : size / 2 - borderWidth;

    Widget avatar = CircleAvatar(
      radius: innerRadius,
      backgroundColor: backgroundColor,
      foregroundImage: picture == null
          ? null
          : isLocalPicture
          ? FileImage(File(picture!))
          : NetworkImage(picture!),
      child: Text(
        initial,
        style: size < 100
            ? theme.textTheme.headlineMedium!.copyWith(
                color: theme.colorScheme.onPrimary,
              )
            : theme.textTheme.displayLarge!.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
      ),
    );

    if (effectiveBorderColor != null) {
      avatar = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: effectiveBorderColor,
        ),
        padding: EdgeInsets.all(borderWidth),
        child: avatar,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(child: avatar),
          ),
        ),
        if (canRemove && onRemove != null)
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
                onTap: onRemove,
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
        if (showEditBadge && onTap != null)
          Positioned(
            bottom: -2,
            right: -2,
            child: Material(
              color: theme.colorScheme.primary,
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: Colors.black26,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: size < 60 ? 13 : 16,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
