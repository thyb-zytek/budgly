import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Copies a picked image into the app's documents directory under a stable
/// name.
///
/// Pure filesystem I/O, no UI dependency — unlike the former
/// `services/image/ImageService`, which also owned `BuildContext`/`Theme`/l10n
/// (see `shared/ui/widgets/image/account_image_picker.dart` for that half).
class LocalImageStore {
  static Future<File?> persistFile(String filepath, String fileName) async {
    final file = File(filepath);
    if (!await file.exists()) return null;

    final directory = await getApplicationDocumentsDirectory();
    final destination = '${directory.path}/$fileName';
    return file.copy(destination);
  }
}
