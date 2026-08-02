// Map search filters applied to Parkd's privacy-safe public listing data.
class MapFilters {
  const MapFilters({
    this.maxPricePerHour = 50,
    this.guelphOnly = false,
    this.proximityEnabled = false,
    this.proximityRadiusKm = 10,
    this.availabilityFilterEnabled = false,
    this.availRangeStart,
    this.availRangeEnd,
    this.availStartMinutes = 9 * 60,
    this.availEndMinutes = 17 * 60,
  });

  final double maxPricePerHour;
  final bool guelphOnly;

  // Nearby filtering uses the coarse coordinates exposed by the public map
  final bool proximityEnabled;
  final double proximityRadiusKm;

  final bool availabilityFilterEnabled;
  final DateTime? availRangeStart;
  final DateTime? availRangeEnd;
  final int availStartMinutes;
  final int availEndMinutes;

  DateTime? get availabilityWindowStart {
    final day = availRangeStart;
    if (day == null) return null;
    return DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: availStartMinutes));
  }

  DateTime? get availabilityWindowEnd {
    final day = availRangeEnd;
    if (day == null) return null;
    return DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: availEndMinutes));
  }

  bool get hasValidAvailabilityWindow {
    final start = availabilityWindowStart;
    final end = availabilityWindowEnd;
    return start != null && end != null && end.isAfter(start);
  }

  MapFilters copyWith({
    double? maxPricePerHour,
    bool? guelphOnly,
    bool? proximityEnabled,
    double? proximityRadiusKm,
    bool? availabilityFilterEnabled,
    int? availStartMinutes,
    int? availEndMinutes,
  }) {
    return MapFilters(
      maxPricePerHour: maxPricePerHour ?? this.maxPricePerHour,
      guelphOnly: guelphOnly ?? this.guelphOnly,
      proximityEnabled: proximityEnabled ?? this.proximityEnabled,
      proximityRadiusKm: proximityRadiusKm ?? this.proximityRadiusKm,
      availabilityFilterEnabled:
          availabilityFilterEnabled ?? this.availabilityFilterEnabled,
      availRangeStart: availRangeStart,
      availRangeEnd: availRangeEnd,
      availStartMinutes: availStartMinutes ?? this.availStartMinutes,
      availEndMinutes: availEndMinutes ?? this.availEndMinutes,
    );
  }
}
