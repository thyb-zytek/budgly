import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestViewModel extends BaseViewModel {
  void startLoading() => setLoading(true);
  void stopLoading() => setLoading(false);
  void succeed() => setSuccess();
  void fail(Object error) => setError(error);
  void queueSuccessMessage(AppUserMessage message) => setSuccessMessage(message);
  void reset() => resetState();
}

void main() {
  group('BaseViewModel loading/error state', () {
    test('starts idle', () {
      final vm = _TestViewModel();
      expect(vm.viewState, ViewState.idle);
      expect(vm.isLoading, isFalse);
      expect(vm.hasError, isFalse);
    });

    test('setLoading(true) then setLoading(false) ends in success', () {
      final vm = _TestViewModel();
      vm.startLoading();
      expect(vm.isLoading, isTrue);
      vm.stopLoading();
      expect(vm.isLoading, isFalse);
      expect(vm.viewState, ViewState.success);
    });

    test(
      'a typical try/catch/finally shape ends in error, not success — '
      'the finally-block setLoading(false) must not clobber the error',
      () {
        final vm = _TestViewModel();
        vm.startLoading();
        vm.fail(Exception('boom'));
        vm.stopLoading(); // simulates the `finally { setLoading(false); }`
        expect(vm.hasError, isTrue);
        expect(vm.viewState, ViewState.error);
      },
    );

    test('starting a new loading cycle clears a previous error', () {
      final vm = _TestViewModel();
      vm.fail(Exception('boom'));
      expect(vm.hasError, isTrue);

      vm.startLoading();
      expect(vm.hasError, isFalse);
      expect(vm.isLoading, isTrue);
    });

    test('setError stores the raw error for callers that need it', () {
      final vm = _TestViewModel();
      final error = Exception('boom');
      vm.fail(error);
      expect(vm.error, same(error));
    });

    test('setError without an explicit message auto-classifies the error', () {
      final vm = _TestViewModel();
      vm.fail(Exception('SocketException: failed'));
      expect(vm.pendingUserMessage?.key, AppMessageKey.networkError);
      expect(vm.pendingUserMessage?.type, isNotNull);
    });

    test('notifies listeners on setError even when already in error state', () {
      final vm = _TestViewModel();
      vm.fail(Exception('first'));

      var notified = false;
      vm.addListener(() => notified = true);
      vm.fail(Exception('second'));

      expect(notified, isTrue);
    });
  });

  group('BaseViewModel.pendingUserMessage', () {
    test('is null by default', () {
      final vm = _TestViewModel();
      expect(vm.pendingUserMessage, isNull);
    });

    test('setSuccessMessage queues a message without touching viewState', () {
      final vm = _TestViewModel();
      vm.queueSuccessMessage(const AppUserMessage.success(AppMessageKey.accountSaved));
      expect(vm.pendingUserMessage?.key, AppMessageKey.accountSaved);
      expect(vm.viewState, ViewState.idle);
    });

    test('loading + success message emits once when loading finishes', () {
      final vm = _TestViewModel();
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.startLoading();
      vm.queueSuccessMessage(const AppUserMessage.success(AppMessageKey.accountSaved));
      vm.stopLoading();

      expect(notifications, 2);
      expect(vm.pendingUserMessage?.key, AppMessageKey.accountSaved);
    });

    test('consumeUserMessage clears the pending message', () {
      final vm = _TestViewModel();
      vm.queueSuccessMessage(const AppUserMessage.success(AppMessageKey.accountSaved));
      vm.consumeUserMessage();
      expect(vm.pendingUserMessage, isNull);
    });
  });

  group('BaseViewModel.resetState', () {
    test('clears both the error and the view state', () {
      final vm = _TestViewModel();
      vm.fail(Exception('boom'));
      vm.reset();
      expect(vm.hasError, isFalse);
      expect(vm.error, isNull);
      expect(vm.viewState, ViewState.idle);
    });
  });
}
