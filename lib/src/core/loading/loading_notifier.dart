import 'package:flutter/foundation.dart';

/// Reusable reference-counted loading state for application stores.
mixin LoadingNotifier on ChangeNotifier {
  bool _isLoading = false;
  int _loadingCount = 0;

  bool get isLoading => _isLoading;

  void beginLoading() {
    _loadingCount++;
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
  }

  void endLoading() {
    if (_loadingCount > 0) _loadingCount--;
    if (_loadingCount != 0 || !_isLoading) return;
    _isLoading = false;
    notifyListeners();
  }

  void setLoading(bool loading) {
    if (loading) {
      beginLoading();
      return;
    }
    _loadingCount = 0;
    if (!_isLoading) return;
    _isLoading = false;
    notifyListeners();
  }
}
