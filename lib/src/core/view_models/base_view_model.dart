import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:flutter/foundation.dart';

enum ViewState {
  idle,
  loading,
  success,
  error,
}

abstract class BaseViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  Object? _error;
  bool _isDisposed = false;

  AppUserMessage? _pendingUserMessage;

  ViewState get viewState => _state;
  Object? get error => _error;
  bool get isLoading => _state == ViewState.loading;
  bool get hasError => _state == ViewState.error;
  bool get isDisposed => _isDisposed;
  AppUserMessage? get pendingUserMessage => _pendingUserMessage;

  @protected
  void setLoading([bool loading = true]) {
    if (loading) {
      _error = null;
      _pendingUserMessage = null;
      _setState(ViewState.loading);
      return;
    }
    if (_state != ViewState.error) {
      _setState(ViewState.success);
    }
  }

  @protected
  void setSuccess() {
    _setState(ViewState.success);
  }

  @protected
  void setError(Object error, {StackTrace? stackTrace, AppUserMessage? userMessage}) {
    _error = error;
    _pendingUserMessage = userMessage ?? AppUserMessage.error(classifyError(error));
    AppLogger.error(runtimeType.toString(), error, stackTrace);
    _setState(ViewState.error);
  }

  @protected
  void setSuccessMessage(AppUserMessage message) {
    _pendingUserMessage = message;
    // Loading operations already notify when they transition back to success.
    // Avoid a second rebuild for the same state change.
    if (_state != ViewState.loading && !_isDisposed) {
      notifyListeners();
    }
  }

  void consumeUserMessage() {
    _pendingUserMessage = null;
  }

  @protected
  void resetState() {
    _error = null;
    _pendingUserMessage = null;
    _setState(ViewState.idle);
  }

  void _setState(ViewState value) {
    if (_state == value && value != ViewState.error) return;
    _state = value;
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
