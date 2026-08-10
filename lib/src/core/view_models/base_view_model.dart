import 'package:flutter/material.dart';
import 'package:budgly/src/core/error/error_handler.dart';

class BaseViewModel extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  bool get isDisposed => _isDisposed;

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void setError(String? error) {
    if (_errorMessage != error) {
      _errorMessage = error;
      if (error != null) {
        ErrorHandler.logWarning(error);
      }
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<T> withLoading<T>(Future<T> Function() operation) async {
    setLoading(true);
    clearError();
    try {
      return await operation();
    } catch (error, stackTrace) {
      ErrorHandler.handleAsyncError(error, stackTrace);
      setError(error.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<T> withSilentLoading<T>(Future<T> Function() operation) async {
    setLoading(true);
    try {
      return await operation();
    } catch (error, stackTrace) {
      ErrorHandler.handleAsyncError(error, stackTrace);
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    clearError();
    super.dispose();
  }
}