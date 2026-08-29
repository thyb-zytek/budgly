import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyError advanced edge cases', () {
    test('network keyword takes precedence over permission', () {
      expect(
        classifyError(Exception('network unauthorized access')),
        AppMessageKey.networkError,
      );
    });

    test('network keyword takes precedence over not-found', () {
      expect(
        classifyError(Exception('network connection not-found')),
        AppMessageKey.networkError,
      );
    });

    test('permission keyword takes precedence over not-found', () {
      expect(
        classifyError(Exception('permission not-found')),
        AppMessageKey.permissionError,
      );
    });

    test('403 is classified as permission', () {
      expect(
        classifyError(Exception('error 403 forbidden')),
        AppMessageKey.permissionError,
      );
    });

    test('404 is classified as not-found', () {
      expect(
        classifyError(Exception('error 404 not found')),
        AppMessageKey.notFoundError,
      );
    });

    test('RLS keyword triggers permission', () {
      expect(
        classifyError(Exception('new row violates row-level security')),
        AppMessageKey.permissionError,
      );
    });

    test('rls keyword is case insensitive', () {
      expect(
        classifyError(Exception('RLS policy violation')),
        AppMessageKey.permissionError,
      );
    });

    test('unauthorized keyword triggers permission', () {
      expect(
        classifyError(Exception('Request Unauthorized')),
        AppMessageKey.permissionError,
      );
    });

    test('forbidden keyword triggers permission', () {
      expect(
        classifyError(Exception('Access Forbidden')),
        AppMessageKey.permissionError,
      );
    });

    test('notfound (no hyphen) triggers not-found', () {
      expect(
        classifyError(Exception('EntityNotfoundException')),
        AppMessageKey.notFoundError,
      );
    });

    test('not found (with space) triggers not-found', () {
      expect(
        classifyError(Exception('Entity not found')),
        AppMessageKey.notFoundError,
      );
    });

    test('empty string falls back to unknown', () {
      expect(
        classifyError(Exception('')),
        AppMessageKey.unknownError,
      );
    });

    test('object with short description falls back to unknown', () {
      expect(
        classifyError('oops'),
        AppMessageKey.unknownError,
      );
    });

    test('connection keyword triggers network', () {
      expect(
        classifyError(Exception('connection refused')),
        AppMessageKey.networkError,
      );
    });

    test('mixed case SocketException triggers network', () {
      expect(
        classifyError(Exception('SOCKETEXCEPTION: reset')),
        AppMessageKey.networkError,
      );
    });
  });

  group('AppUserMessage additional equality', () {
    test('different keys with same type are not equal', () {
      const a = AppUserMessage.error(AppMessageKey.networkError);
      const b = AppUserMessage.error(AppMessageKey.permissionError);
      expect(a, isNot(b));
    });

    test('not equal to non-AppUserMessage', () {
      const a = AppUserMessage.error(AppMessageKey.networkError);
      expect(a, isNot('string'));
    });

    test('success and error constructors produce correct types', () {
      const error = AppUserMessage.error(AppMessageKey.networkError);
      const success = AppUserMessage.success(AppMessageKey.accountSaved);
      expect(error.type.name, 'error');
      expect(success.type.name, 'success');
    });
  });
}
