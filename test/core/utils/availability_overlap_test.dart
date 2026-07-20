import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/utils/availability_overlap.dart';

void main() {
  group('AvailabilityOverlap', () {
    test('uses half-open interval semantics for minute ranges', () {
      expect(
        AvailabilityOverlap.intervalsOverlapHalfOpenMinutes(60, 120, 120, 180),
        isFalse,
      );
      expect(
        AvailabilityOverlap.intervalsOverlapHalfOpenMinutes(60, 121, 120, 180),
        isTrue,
      );
    });

    test('detects weekly overlaps only on the same day', () {
      expect(
        AvailabilityOverlap.weeklyAnyPairOverlaps([
          (dayPg: 1, startMin: 60, endMin: 120),
          (dayPg: 1, startMin: 90, endMin: 180),
        ]),
        isTrue,
      );
      expect(
        AvailabilityOverlap.weeklyAnyPairOverlaps([
          (dayPg: 1, startMin: 60, endMin: 120),
          (dayPg: 2, startMin: 90, endMin: 180),
        ]),
        isFalse,
      );
    });

    test('detects specific datetime overlaps', () {
      final start = DateTime.utc(2026, 1, 1, 10);
      expect(
        AvailabilityOverlap.specificNewOverlaps(
          start.add(const Duration(minutes: 30)),
          start.add(const Duration(hours: 2)),
          [(start: start, end: start.add(const Duration(hours: 1)))],
        ),
        isTrue,
      );
    });

    test('maps database overlap exceptions to user-facing messages', () {
      expect(
        AvailabilityOverlap.messageForException(
          Exception('OVERLAP_AVAILABILITY_WEEKLY'),
        ),
        AvailabilityOverlap.userMessageWeekly,
      );
      expect(
        AvailabilityOverlap.messageForException(
          Exception('OVERLAP_AVAILABILITY_SPECIFIC'),
        ),
        AvailabilityOverlap.userMessageSpecific,
      );
      expect(
        AvailabilityOverlap.messageForException(Exception('other')),
        isNull,
      );
    });
  });
}
