// String helpers for UI (dates, durations, money) — keep widgets dumb

// Title case each whitespace-separated word (nav labels, list rows, buttons)
String formatTitleCaseWords(String text) {
  if (text.isEmpty) return text;
  return text
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

(String, String) splitDisplayDateTime(String value) {
  for (final sep in [' • ', ' · ']) {
    final i = value.indexOf(sep);
    if (i >= 0) {
      return (
        value.substring(0, i).trim(),
        value.substring(i + sep.length).trim(),
      );
    }
  }
  return (value.trim(), '');
}

// Compact duration for booking timers (e.g. 2H 15M)
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
