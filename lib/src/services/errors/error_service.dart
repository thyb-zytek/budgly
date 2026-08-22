import 'package:flutter/material.dart';

class ErrorService extends ChangeNotifier {
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  static ErrorService get instance => _instance;

  bool _hasError = false;
  bool get hasError => _hasError;

  void reportError() {
    if (!_hasError) {
      _hasError = true;
      notifyListeners();
    }
  }

  void clearError() {
    if (_hasError) {
      _hasError = false;
      notifyListeners();
    }
  }
}
