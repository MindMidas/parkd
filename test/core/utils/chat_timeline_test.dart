import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/utils/chat_timeline.dart';

void main() {
  group('shouldShowChatTimestamp', () {
    test('stamps the first message in a conversation', () {
      expect(
        shouldShowChatTimestamp(
          current: DateTime(2026, 8, 1, 13, 0),
          previous: null,
        ),
        isTrue,
      );
    });

    test('stays hidden for a quick back and forth', () {
      expect(
        shouldShowChatTimestamp(
          current: DateTime(2026, 8, 1, 13, 5),
          previous: DateTime(2026, 8, 1, 13, 0),
        ),
        isFalse,
      );
    });

    test('reappears once the group gap elapses', () {
      expect(
        shouldShowChatTimestamp(
          current: DateTime(2026, 8, 1, 13, 20),
          previous: DateTime(2026, 8, 1, 13, 0),
        ),
        isTrue,
      );
    });

    test('always stamps a new day even if minutes apart', () {
      expect(
        shouldShowChatTimestamp(
          current: DateTime(2026, 8, 2, 0, 5),
          previous: DateTime(2026, 8, 1, 23, 58),
        ),
        isTrue,
      );
    });
  });

  group('chatTimestampLabel', () {
    final now = DateTime(2026, 8, 1, 13, 30);

    test('shows only the time for today', () {
      final label = chatTimestampLabel(DateTime(2026, 8, 1, 9, 5), now: now);
      expect(label, startsWith('9:05'));
      expect(label, endsWith('AM'));
    });

    test('prefixes yesterday', () {
      final label = chatTimestampLabel(DateTime(2026, 7, 31, 9, 5), now: now);
      expect(label, startsWith('Yesterday'));
    });

    test('uses the weekday within the last week', () {
      final label = chatTimestampLabel(DateTime(2026, 7, 28, 9, 5), now: now);
      expect(label, startsWith('Tuesday'));
    });

    test('includes the year for older messages', () {
      final label = chatTimestampLabel(DateTime(2025, 7, 28, 9, 5), now: now);
      expect(label, contains('2025'));
    });
  });

  group('isChatBubbleTail', () {
    test('last message in the list is a tail', () {
      expect(
        isChatBubbleTail(
          senderId: 'a',
          sentAt: DateTime(2026, 8, 1, 13, 0),
          nextSenderId: null,
          nextSentAt: null,
        ),
        isTrue,
      );
    });

    test('a reply from the other person ends the run', () {
      expect(
        isChatBubbleTail(
          senderId: 'a',
          sentAt: DateTime(2026, 8, 1, 13, 0),
          nextSenderId: 'b',
          nextSentAt: DateTime(2026, 8, 1, 13, 1),
        ),
        isTrue,
      );
    });

    test('consecutive messages from one sender stay grouped', () {
      expect(
        isChatBubbleTail(
          senderId: 'a',
          sentAt: DateTime(2026, 8, 1, 13, 0),
          nextSenderId: 'a',
          nextSentAt: DateTime(2026, 8, 1, 13, 1),
        ),
        isFalse,
      );
    });

    test('a later message from the same sender starts a new run', () {
      expect(
        isChatBubbleTail(
          senderId: 'a',
          sentAt: DateTime(2026, 8, 1, 13, 0),
          nextSenderId: 'a',
          nextSentAt: DateTime(2026, 8, 1, 14, 0),
        ),
        isTrue,
      );
    });
  });
}
