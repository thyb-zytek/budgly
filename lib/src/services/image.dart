import 'dart:io';

import 'package:app/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageService {
  static Future<String?> _pickImageFromGallery() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      return result.files.single.path!;
    }
    return null;
  }

  static Future<String?> _cropToCircle(
      BuildContext context, String path) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
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
  }

  static Future<String?> pickAndCropImage(BuildContext context) async {
    final path = await _pickImageFromGallery();
    if (path == null) return null;
    return await _cropToCircle(context, path);
  }

  static Future<File?> persistFile(String filepath, String fileName) async {
    final file = File(filepath);
    if (!await file.exists()) return null;

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    return file.copy(path);
  }
}
