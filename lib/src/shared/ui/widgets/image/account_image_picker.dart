import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the system image picker, then an in-app circular cropper.
///
/// Lives in the UI layer, not `services/`: it owns `BuildContext`, `Theme`
/// and localization, which are presentation concerns. The previous home
/// (`services/image/ImageService`) mixed this with a pure filesystem helper
/// (`persistFile`) that has since moved to
/// `services/image/local_image_store.dart` (`LocalImageStore`), which has no
/// UI dependency and legitimately belongs in the services layer.
class AccountImagePicker {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    return image?.path;
  }

  static Future<String?> _cropToCircle(
    BuildContext context,
    String path,
  ) async {
    if (!context.mounted) return null;

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: AppLocalizations.of(context)!.cropImage,
            toolbarColor: Theme.of(context).primaryColor,
            backgroundColor: Theme.of(context).colorScheme.surface,
            showCropGrid: false,
            toolbarWidgetColor: Theme.of(context).colorScheme.onPrimary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            cropStyle: CropStyle.circle,
            activeControlsWidgetColor: Theme.of(context).colorScheme.primary,
          ),
          IOSUiSettings(
            title: AppLocalizations.of(context)!.cropImage,
            aspectRatioLockEnabled: true,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      return croppedFile?.path;
    } catch (e, st) {
      // A null return is indistinguishable from "user cancelled" for the
      // caller, so a genuine cropper failure (missing native activity, denied
      // permission, unreadable file) would otherwise be invisible: the user
      // taps the avatar and nothing happens, with no trace anywhere.
      AppLogger.error('Image crop failed', e, st);
      return null;
    }
  }

  /// Returns the local path of the cropped image, or `null` if the user
  /// cancelled or either step failed.
  static Future<String?> pickAndCropImage(BuildContext context) async {
    try {
      final path = await _pickFromGallery();
      if (path == null || !context.mounted) return null;
      return await _cropToCircle(context, path);
    } catch (e, st) {
      AppLogger.error('Image selection failed', e, st);
      return null;
    }
  }
}
