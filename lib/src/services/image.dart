import 'dart:io';

import 'package:budgly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
    );

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
        aspectRatio: const CropAspectRatio(
          ratioX: 1,
          ratioY: 1,
        ),
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
            activeControlsWidgetColor:
                Theme.of(context).colorScheme.primary,
          ),
          IOSUiSettings(
            title: AppLocalizations.of(context)!.cropImage,
            aspectRatioLockEnabled: true,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      return croppedFile?.path;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> pickAndCropImage(
    BuildContext context,
  ) async {
    try {
      final path = await _pickImageFromGallery();

      if (path == null || !context.mounted) {
        return null;
      }

      return _cropToCircle(context, path);
    } catch (e) {
      return null;
    }
  }

  static Future<File?> persistFile(
    String filepath,
    String fileName,
  ) async {
    final file = File(filepath);

    if (!await file.exists()) {
      return null;
    }

    final directory = await getApplicationDocumentsDirectory();
    final destination = '${directory.path}/$fileName';

    return file.copy(destination);
  }
}