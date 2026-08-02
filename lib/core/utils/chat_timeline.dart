import 'package:intl/intl.dart';

// A conversation only gets a timestamp separator when enough time has passed
// that the previous one stops describing the new message.
const Duration chatTimestampGroupGap = Duration(minutes: 15);

bool shouldShowChatTimestamp({
  required DateTime? current,
  required DateTime? previous,
}) {
  if (current == null) return false;
  if (previous == null) return true;
  if (!_isSameDay(current.toLocal(), previous.toLocal())) return true;
  return current.difference(previous).abs() >= chatTimestampGroupGap;
}

String chatTimestampLabel(DateTime when, {DateTime? now}) {
  final local = when.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final time = DateFormat.jm().format(local);

  if (_isSameDay(local, today)) return time;
  if (_isSameDay(local, today.subtract(const Duration(days: 1)))) {
    return 'Yesterday $time';
  }
  if (today.difference(local) < const Duration(days: 7)) {
    return '${DateFormat.EEEE().format(local)} $time';
  }
  if (local.year == today.year) {
    return '${DateFormat.MMMd().format(local)}, $time';
  }
  return '${DateFormat.yMMMd().format(local)}, $time';
}

// Last bubble of a run from one sender, so only it gets the pointed corner.
bool isChatBubbleTail({
  required String senderId,
  required DateTime? sentAt,
  required String? nextSenderId,
  required DateTime? nextSentAt,
}) {
  if (nextSenderId == null) return true;
  if (nextSenderId != senderId) return true;
  return shouldShowChatTimestamp(current: nextSentAt, previous: sentAt);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
