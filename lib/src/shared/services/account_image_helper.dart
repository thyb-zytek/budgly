import 'dart:io';

import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts.dart';
import 'package:budgly/src/services/image.dart';

class ImageProcessResult {
  final String fileName;
  final File file;
  ImageProcessResult(this.fileName, this.file);
}

class AccountImageHelper {
  static Future<ImageProcessResult?> prepareImage(String? picture, {bool isLocal = true}) async {
    if (picture == null || !isLocal) return null;

    final fileName = "${DateTime.now().millisecondsSinceEpoch}_${picture.split('/').last}";
    final file = await ImageService.persistFile(picture, fileName);

    return file != null ? ImageProcessResult(fileName, file) : null;
  }

  static Future<Account> uploadAndLinkImage(
    AccountsService accountsService,
    Account account,
    ImageProcessResult image,
  ) async {
    try {
      await accountsService.uploadPicture(image.file, account.id!, image.fileName);
      final url = await accountsService.getSignedUrl(image.fileName, account.id!);
      return account.copyWith(pictureUrl: url);
    } catch (_) {
      return account;
    }
  }
}
