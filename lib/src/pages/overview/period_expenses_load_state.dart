import 'package:budgly/src/models/expense/expense.dart';

/// Coordinates in-flight/loaded state for one Overview period.
///
/// It intentionally does not know how expenses are fetched or how results are
/// rendered; the ViewModel remains responsible for applying a result to the
/// currently selected account/period.
class PeriodExpensesLoadState {
  String? loadedKey;
  String? loadingKey;
  Future<List<Expense>>? _inFlight;

  bool isLoaded(String key) => loadedKey == key;

  Future<List<Expense>> load(
    String key,
    Future<List<Expense>> Function() loader,
  ) async {
    if (loadingKey == key && _inFlight != null) {
      return _inFlight!;
    }

    loadingKey = key;
    final future = loader();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
        loadingKey = null;
      }
    }
  }

  void markLoaded(String key) => loadedKey = key;

  void invalidate() {
    loadedKey = null;
  }
}
