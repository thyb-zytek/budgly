import 'package:intl/intl.dart';

class Period {
  final int year;
  final int month; // 1-12

  const Period({required this.year, required this.month});

  factory Period.fromDate(DateTime date) => Period(year: date.year, month: date.month);
  factory Period.current() => Period.fromDate(DateTime.now());

  DateTime get startOfMonth => DateTime(year, month, 1);
  DateTime get endOfMonth => DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));

  bool contains(DateTime date) => !date.isBefore(startOfMonth) && !date.isAfter(endOfMonth);

  Period addMonths(int delta) {
    final total = year * 12 + (month - 1) + delta;
    final newYear = total ~/ 12;
    final newMonth = (total % 12) + 1;
    return Period(year: newYear, month: newMonth);
  }

  Period get previous => addMonths(-1);
  Period get next => addMonths(1);

  int get _ordinal => year * 12 + month;
  bool isBefore(Period other) => _ordinal < other._ordinal;
  bool isAfter(Period other) => _ordinal > other._ordinal;

  /// Ex: "Décembre 2023" (première lettre capitalisée).
  String label(String localeName) {
    final formatted = DateFormat.yMMMM(localeName).format(startOfMonth);
    if (formatted.isEmpty) return formatted;
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  /// Compte le nombre de weekends restants dans le mois.
  /// Un weekend est défini par la présence d'un Samedi. 
  /// Si "today" tombe un dimanche, ce weekend en cours est pris en compte.
  int remainingWeekends({DateTime? now}) {
    final today = now ?? DateTime.now();
    if (!contains(today)) return 0;

    int count = 0;
    
    if (today.weekday == DateTime.sunday) {
      count++;
    }

    DateTime current = today;
    while (!current.isAfter(endOfMonth)) {
      if (current.weekday == DateTime.saturday) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    
    return count;
  }

  @override
  bool operator ==(Object other) => other is Period && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}