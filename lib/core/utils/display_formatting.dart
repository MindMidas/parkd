import 'package:intl/intl.dart';

import '../models/reservation_row.dart';

// title case each whitespace-separated word
String formatTitleCaseWords(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

(String, String) splitDisplayDateTime(String value) {
  const sep = ' · ';
  final i = value.indexOf(sep);
  if (i >= 0) {
    return (
      value.substring(0, i).trim(),
      value.substring(i + sep.length).trim(),
    );
  }
  return (value.trim(), '');
}

// compact duration for booking timers (2H 15M)
String formatDurationCompact(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes <= 0) return '0M';

  final days = duration.inDays;
  final hours = duration.inHours % 24;
  final minutes = totalMinutes % 60;
  final parts = <String>[];

  if (days > 0) parts.add('${days}D');
  if (hours > 0) parts.add('${hours}H');
  if (minutes > 0) parts.add('${minutes}M');

  return parts.join(' ');
}

String formatUsdAmount(double amount) => '\$${amount.toStringAsFixed(2)}';

String formatDriverReservationWhenLabel(ReservationRow r) {
  final d = DateFormat('MMM d').format(r.startTime.toLocal());
  final t = DateFormat('h:mm a').format(r.startTime.toLocal());
  return '$d · $t';
}
