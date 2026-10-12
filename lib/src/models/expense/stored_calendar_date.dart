import 'package:cloud_firestore/cloud_firestore.dart';

// Persistence format of a business (calendar) date in Firestore.
//
// A business date is a calendar day: only its year/month/day matter, never a
// time of day or the timezone of the device that wrote it. It is stored as a
// Timestamp at 00:00:00 UTC of that day, so every device reads the same day
// whatever its timezone (an expense entered in Paris on 1 March is still
// 1 March on a phone in New York).
//
// Documents written before this format stored "local midnight" instead, which
// is a different instant depending on the writer's timezone. They are still
// decoded correctly by calendarDateFromTimestamp, see its comment.

/// Encodes the calendar day of [date] (its time of day is ignored).
Timestamp calendarDateToTimestamp(DateTime date) =>
    Timestamp.fromDate(DateTime.utc(date.year, date.month, date.day));

/// Decodes a stored business date to a local-midnight [DateTime], the in-memory
/// representation used everywhere in the app.
///
/// Values written in the current format are exactly midnight UTC. Legacy
/// values are the writer's local midnight, whose UTC time of day reveals on
/// which side of UTC the writer was: from 12:00 to 23:59 UTC the writer was
/// east of UTC (the calendar day is the day *after* the UTC date), before
/// 12:00 UTC it was west (same day). Only writer offsets of about +10 to +14
/// hours or -10 to -12 hours are ambiguous.
DateTime calendarDateFromTimestamp(Timestamp timestamp) {
  final utc = timestamp.toDate().toUtc();
  final secondsOfDay = utc.hour * 3600 + utc.minute * 60 + utc.second;
  return secondsOfDay >= _legacyEastOfUtcThresholdSeconds
      ? DateTime(utc.year, utc.month, utc.day + 1)
      : DateTime(utc.year, utc.month, utc.day);
}

/// Lower bound (inclusive) of a range query that must match every stored
/// format for [firstDay]: legacy values written east of UTC sit up to
/// [_legacyMaxEastOffsetHours] hours before the UTC midnight of their day.
/// Callers must still filter the decoded dates, see [calendarDateFromTimestamp].
Timestamp calendarDateQueryStart(DateTime firstDay) => Timestamp.fromDate(
  DateTime.utc(
    firstDay.year,
    firstDay.month,
    firstDay.day,
  ).subtract(const Duration(hours: _legacyMaxEastOffsetHours)),
);

/// Upper bound (exclusive) of a range query ending before [endExclusiveDay].
/// Callers must still filter the decoded dates, see [calendarDateFromTimestamp].
Timestamp calendarDateQueryEndExclusive(DateTime endExclusiveDay) =>
    calendarDateToTimestamp(endExclusiveDay);

const int _legacyEastOfUtcThresholdSeconds = 12 * 3600;
const int _legacyMaxEastOffsetHours = 14;
