import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/models/availability_specific.dart';
import 'package:parkd/core/models/availability_weekly.dart';
import 'package:parkd/core/models/slot_pricing_summary.dart';

void main() {
  group('SlotPricingSummary', () {
    const weekly = AvailabilityWeekly(
      id: 'weekly',
      listingId: 'listing',
      dayOfWeek: 1,
      startTime: '09:00',
      endTime: '17:00',
      priceHour: 7,
      priceDay: 35,
    );
    final specific = AvailabilitySpecific(
      id: 'specific',
      listingId: 'listing',
      startDatetime: DateTime.utc(2026, 7, 21),
      endDatetime: DateTime.utc(2026, 7, 22),
      priceHour: 5.5,
      priceDay: 30,
    );

    test('finds minimum rates across weekly and specific slots', () {
      expect(SlotPricingSummary.minHourly([weekly], [specific]), 5.5);
      expect(SlotPricingSummary.minDailyWhereSet([weekly], [specific]), 30);
      expect(
        SlotPricingSummary.label([weekly], [specific]),
        '\$6/hr • \$30/day',
      );
    });

    test('formats compact and absent prices', () {
      expect(SlotPricingSummary.moneyCompact(0), '\$0');
      expect(SlotPricingSummary.moneyCompact(8), '\$8');
      expect(SlotPricingSummary.moneyCompact(8.5), '\$8.50');
      expect(SlotPricingSummary.label(const [], const []), '—');
      expect(SlotPricingSummary.dailyRateCaption(null), isNull);
    });
  });
}
