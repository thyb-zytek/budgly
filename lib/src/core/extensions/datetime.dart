import 'package:intl/intl.dart';

extension DateTimeExtension on DateTime {
  String formatMonthYear(String localeName) {
    try {
      return DateFormat.yMMMM(localeName).format(this);
    } catch (e) {
      return '${month.toString().padLeft(2, '0')}/$year';
    }
  }
}
