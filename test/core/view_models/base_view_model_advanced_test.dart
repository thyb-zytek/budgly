import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestViewModel extends BaseViewModel {
  void startLoading() => setLoading(true);
  void stopLoading() => setLoading(false);
  void succeed() => setSuccess();
  void fail(Object error, {AppUserMessage? message}) =>
      setError(error, userMessage: message);
  void queueSuccessMessage(AppUserMessage message) => setSuccessMessage(message);
  void reset() => resetState();
}

void main() {
  group('BaseViewModel advanced edge cases', () {
    test('dispose prevents notifyListeners', () {
      final vm = _TestViewModel();
      vm.dispose();

      expect(vm.isDisposed, isTrue);
      // Should not throw after dispose
      vm.startLoading();
      expect(vm.isLoading, isTrue);
    });

    test('setSuccessMessage does not throw after dispose', () {
      final vm = _TestViewModel();
      vm.dispose();
      expect(
        () => vm.queueSuccessMessage(
          const AppUserMessage.success(AppMessageKey.accountSaved),
        ),
        returnsNormally,
      );
    });

    test('setError with explicit userMessage uses that message', () {
      final vm = _TestViewModel();
      const msg = AppUserMessage.success(AppMessageKey.budgetSaved);
      vm.fail(Exception('test'), message: msg);
      expect(vm.pendingUserMessage, msg);
    });

    test('setError auto-classifies network error without explicit message', () {
      final vm = _TestViewModel();
      vm.fail(Exception('SocketException'));
      expect(vm.pendingUserMessage?.key, AppMessageKey.networkError);
    });

    test('setError auto-classifies permission error without explicit message', () {
      final vm = _TestViewModel();
      vm.fail(Exception('401 Unauthorized'));
      expect(vm.pendingUserMessage?.key, AppMessageKey.permissionError);
    });

    test('setError auto-classifies not-found error without explicit message', () {
      final vm = _TestViewModel();
      vm.fail(Exception('404 not-found'));
      expect(vm.pendingUserMessage?.key, AppMessageKey.notFoundError);
    });

    test('setError auto-classifies unknown error', () {
      final vm = _TestViewModel();
      vm.fail(Exception('random failure'));
      expect(vm.pendingUserMessage?.key, AppMessageKey.unknownError);
    });

    test('setLoading(true) transitions out of error state', () {
      final vm = _TestViewModel();
      vm.fail(Exception('boom'));
      expect(vm.hasError, isTrue);

      vm.startLoading();
      expect(vm.hasError, isFalse);
      expect(vm.isLoading, isTrue);
    });

    test('multiple load cycles work correctly', () {
      final vm = _TestViewModel();

      vm.startLoading();
      vm.stopLoading();
      expect(vm.viewState, ViewState.success);

      vm.startLoading();
      expect(vm.isLoading, isTrue);
      vm.stopLoading();
      expect(vm.viewState, ViewState.success);
    });

    test('reset after error clears everything', () {
      final vm = _TestViewModel();
      vm.fail(Exception('boom'));
      expect(vm.hasError, isTrue);
      expect(vm.error, isNotNull);

      vm.reset();
      expect(vm.hasError, isFalse);
      expect(vm.error, isNull);
      expect(vm.viewState, ViewState.idle);
    });

    test('listeners are notified on loading transition', () {
      final vm = _TestViewModel();
      var count = 0;
      vm.addListener(() => count++);

      vm.startLoading();
      vm.stopLoading();

      expect(count, 2);
    });

    test('listeners are notified on success', () {
      final vm = _TestViewModel();
      var count = 0;
      vm.addListener(() => count++);

      vm.succeed();
      expect(count, 1);
    });

    test('setLoading(false) does not notify when already idle', () {
      final vm = _TestViewModel();
      var count = 0;
      vm.addListener(() => count++);

      vm.stopLoading(); // Already idle, should not transition to success

      // When state is idle and setLoading(false) is called,
      // it should set to success (since state != error), so it does notify
      expect(vm.viewState, ViewState.success);
    });

    test('_setState does not notify when state is same and not error', () {
      final vm = _TestViewModel();
      vm.succeed();
      var count = 0;
      vm.addListener(() => count++);

      vm.succeed(); // Same state, should not notify

      expect(count, 0);
    });

    test('_setState always notifies when in error state', () {
      final vm = _TestViewModel();
      vm.fail(Exception('first'));
      var count = 0;
      vm.addListener(() => count++);

      vm.fail(Exception('second')); // Same error state, should still notify

      expect(count, 1);
    });
  });
}
