import 'dart:math' as math;

/// Parses a user-entered monetary amount.
///
/// Returns the exact value typed by the user (full precision): the rounding
/// to the configured decimals is a display concern handled by
/// [normalizeAmount]/`formatCurrency`, never a storage concern.
double? parseAmount(String value) {
  final amount = double.tryParse(value.trim().replaceAll(',', '.'));
  if (amount == null || amount <= 0) return null;
  return amount;
}

double normalizeAmount(double amount, {int decimalPlaces = 2}) {
  final places = decimalPlaces.clamp(0, 2);
  final factor = math.pow(10, places).toDouble();
  return (amount * factor).ceil() / factor;
}