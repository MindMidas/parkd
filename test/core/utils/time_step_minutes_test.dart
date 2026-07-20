import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/utils/time_step_minutes.dart';

void main() {
  group('TimeStepMinutes', () {
    test('formats minutes as AM/PM labels', () {
      expect(TimeStepMinutes.formatAmPm(0), '12:00 AM');
      expect(TimeStepMinutes.formatAmPm(12 * 60), '12:00 PM');
      expect(TimeStepMinutes.formatAmPm(23 * 60 + 55), '11:55 PM');
    });

    test('adds clamped five-minute steps', () {
      expect(TimeStepMinutes.addSteps(0, -1), 0);
      expect(TimeStepMinutes.addSteps(60, 2), 70);
      expect(TimeStepMinutes.addSteps(23 * 60 + 55, 1), 23 * 60 + 55);
    });

    test('parses and serializes HH:mm values', () {
      expect(TimeStepMinutes.tryParseMinutesFromHhMm('09:15'), 555);
      expect(TimeStepMinutes.tryParseMinutesFromHhMm('09:15:00'), 555);
      expect(TimeStepMinutes.tryParseMinutesFromHhMm('24:00'), isNull);
      expect(TimeStepMinutes.minutesToHhMm(555), '09:15');
    });

    test('parses AM/PM labels', () {
      expect(TimeStepMinutes.tryParseMinutesFromAmPm('12:00 AM'), 0);
      expect(TimeStepMinutes.tryParseMinutesFromAmPm('12:00 PM'), 720);
      expect(TimeStepMinutes.tryParseMinutesFromAmPm('3:05 pm'), 905);
      expect(TimeStepMinutes.tryParseMinutesFromAmPm('13:05 PM'), isNull);
    });
  });
}
