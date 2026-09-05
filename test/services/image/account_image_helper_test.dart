import 'dart:io';

import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/image/account_image_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../fixtures/builders.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

class _FakeAccountsService extends AccountsService {
  Object? uploadError;
  String? uploadResult;
  String? signedUrl;
  int queueCalls = 0;
  Account? queuedAccount;
  File? queuedFile;

  @override
  Future<String?> uploadPicture(
    File file,
    String accountId,
    String fileName,
  ) async {
    if (uploadError != null) throw uploadError!;
    return uploadResult;
  }

  @override
  Future<String?> getSignedUrl(String path, String accountId) async => signedUrl;

  @override
  Future<void> queuePictureUpload(Account account, File file) async {
    queueCalls++;
    queuedAccount = account;
    queuedFile = file;
  }
}

void main() {
  late Directory sourceDir;
  late Directory docsDir;

  setUp(() async {
    sourceDir = await Directory.systemTemp.createTemp('budgly_image_src_');
    docsDir = await Directory.systemTemp.createTemp('budgly_image_docs_');
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
  });

  tearDown(() async {
    await sourceDir.delete(recursive: true);
    await docsDir.delete(recursive: true);
  });

  group('AccountImageHelper.prepareImage', () {
    test('returns null when no picture is provided', () async {
      expect(await AccountImageHelper.prepareImage(null), isNull);
    });

    test('returns null when the picture is not local', () async {
      final file = File('${sourceDir.path}/avatar.png');
      await file.writeAsString('png-bytes');

      expect(
        await AccountImageHelper.prepareImage(file.path, isLocal: false),
        isNull,
      );
    });

    test('returns null when the source file does not exist', () async {
      expect(
        await AccountImageHelper.prepareImage('${sourceDir.path}/missing.png'),
        isNull,
      );
    });

    test('copies a local picture into the documents folder with a timestamped name', () async {
      final file = File('${sourceDir.path}/avatar.png');
      await file.writeAsString('png-bytes');

      final result = await AccountImageHelper.prepareImage(file.path);

      expect(result, isNotNull);
      expect(result!.fileName, endsWith('_avatar.png'));
      expect(result.fileName, isNot(equals('avatar.png')));
      expect(result.file.path, startsWith(docsDir.path));
      expect(await File(result.file.path).readAsString(), 'png-bytes');
    });
  });

  group('AccountImageHelper.uploadAndLinkImage', () {
    test('links the signed url when upload and signing succeed', () async {
      final service = _FakeAccountsService()
        ..uploadResult = 'uploaded'
        ..signedUrl = 'https://cdn.example/avatar.png';
      final sourceFile = File('${sourceDir.path}/avatar.png');
      await sourceFile.writeAsString('png-bytes');
      final image = ImageProcessResult('avatar.png', sourceFile);
      final account = Fixtures.account(id: 'a1');

      final updated = await AccountImageHelper.uploadAndLinkImage(
        service,
        account,
        image,
      );

      expect(updated.pictureUrl, 'https://cdn.example/avatar.png');
      expect(updated.id, 'a1');
      expect(service.queueCalls, 0);
    });

    test('falls back to the local file and queues the upload when storage fails',
        () async {
      final service = _FakeAccountsService()
        ..uploadError = StateError('offline');
      final sourceFile = File('${sourceDir.path}/avatar.png');
      await sourceFile.writeAsString('png-bytes');
      final image = ImageProcessResult('avatar.png', sourceFile);
      final account = Fixtures.account(id: 'a1');

      final updated = await AccountImageHelper.uploadAndLinkImage(
        service,
        account,
        image,
      );
      await Future<void>.delayed(Duration.zero);

      expect(updated.pictureUrl, sourceFile.path);
      expect(service.queueCalls, 1);
      expect(service.queuedAccount?.id, 'a1');
      expect(service.queuedFile, same(sourceFile));
    });
  });
}