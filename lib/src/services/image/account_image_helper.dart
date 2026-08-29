import 'dart:io';
import 'dart:async';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/image/image_service.dart';

class ImageProcessResult {
  final String fileName;
  final File file;
  ImageProcessResult(this.fileName, this.file);
}

class AccountImageHelper {
  static Future<ImageProcessResult?> prepareImage(
    String? picture, {
    bool isLocal = true,
  }) async {
    if (picture == null || !isLocal) return null;

    final fileName =
        "${DateTime.now().millisecondsSinceEpoch}_${picture.split('/').last}";
    final file = await ImageService.persistFile(picture, fileName);

    return file != null ? ImageProcessResult(fileName, file) : null;
  }

  static Future<Account> uploadAndLinkImage(
    AccountsService accountsService,
    Account account,
    ImageProcessResult image,
  ) async {
    try {
      await accountsService.uploadPicture(
        image.file,
        account.id!,
        image.fileName,
      );
      final url = await accountsService.getSignedUrl(
        image.fileName,
        account.id!,
      );
      return account.copyWith(pictureUrl: url);
    } catch (e, stackTrace) {
      // Degrade gracefully — the account is still created/updated without a
      // picture — but the failure must not disappear silently, so it is
      // reported (e.g. an oversized/unsupported file rejected by
      // validateUploadConstraints, or a network/storage error).
      AppLogger.error('Failed to upload account picture', e, stackTrace);
      unawaited(accountsService.queuePictureUpload(account, image.file));
      // Keep the persisted local file as the avatar until storage becomes
      // available again. The account metadata already carries its picture
      // filename, so a later account refresh can replace this local URL.
      return account.copyWith(pictureUrl: image.file.path);
    }
  }
}
