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

  ViewState get viewState => _state;
  Object? get error => _error;
  bool get isLoading => _state == ViewState.loading;
  bool get hasError => _state == ViewState.error;
  bool get isDisposed => _isDisposed;

  @protected
  void setLoading([bool loading = true]) {
    _setState(loading ? ViewState.loading : ViewState.success);
  }

  @protected
  void setSuccess() {
    _setState(ViewState.success);
  }

  @protected
  void setError(Object error) {
    _error = error;
    _setState(ViewState.error);
  }

  @protected
  void resetState() {
    _error = null;
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
