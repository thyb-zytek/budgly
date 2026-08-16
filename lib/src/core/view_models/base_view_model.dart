import 'package:flutter/material.dart';

class BaseViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool _isDisposed = false;

  bool get isLoading => _isLoading;
  bool get isDisposed => _isDisposed;

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
