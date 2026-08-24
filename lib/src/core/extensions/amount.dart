import 'dart:math' as math;

/// Parses and normalizes a user-entered monetary amount.
///
/// [decimalPlaces] controls the precision used by the app. Values are
/// rounded toward the next representable value (ceiling) at that precision.
double? parseAmount(String value, {int decimalPlaces = 2}) {
  final amount = double.tryParse(value.trim().replaceAll(',', '.'));
  if (amount == null || amount <= 0) return null;
  return normalizeAmount(amount, decimalPlaces: decimalPlaces);
}

double normalizeAmount(double amount, {int decimalPlaces = 2}) {
  final places = decimalPlaces.clamp(0, 2);
  final factor = math.pow(10, places).toDouble();
  return (amount * factor).ceil() / factor;
}
