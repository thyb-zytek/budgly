import 'dart:io';

import 'package:budgly/src/core/theme/design_tokens.dart';
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
    final isFilePicture = picture != null &&
        (isLocalPicture ||
            picture!.startsWith('/') ||
            picture!.startsWith('file://'));
    File? pictureFile;
    if (picture != null) {
      if (picture!.startsWith('file://')) {
        try {
          pictureFile = File(Uri.parse(picture!).toFilePath());
        } catch (e) {
          // If URI parsing fails, try using the path directly after removing file:// prefix
          final path = picture!.replaceFirst('file://', '');
          if (path.isNotEmpty) {
            pictureFile = File(path);
          }
        }
      } else if (picture!.startsWith('/')) {
        pictureFile = File(picture!);
      }
    }
    final effectiveBorderColor = borderColor ?? backgroundColor;
    final innerRadius =
        effectiveBorderColor == null ? size / 2 : size / 2 - borderWidth;

    final foregroundImage = picture == null
        ? null
        : isFilePicture
            ? FileImage(pictureFile!)
            : NetworkImage(picture!) as ImageProvider;
    Widget avatar = CircleAvatar(
      radius: innerRadius,
      backgroundColor: backgroundColor,
      foregroundImage: foregroundImage,
      onForegroundImageError: foregroundImage == null ? null : (exception, stackTrace) {},
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
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: avatar),
            ),
          ),
        ),
        if (canRemove && onRemove != null)
          Positioned(
            top: -2,
            right: -2,
            child: Material(
              color: theme.colorScheme.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: Padding(
                  padding: EdgeInsets.all(BudglySpacing.sm),
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
              child: Padding(
                padding: EdgeInsets.all(BudglySpacing.sm),
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
