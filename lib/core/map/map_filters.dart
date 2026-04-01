// Map filters applied in the app after listings are loaded from Supabase.
class MapFilters {
  const MapFilters({
    this.maxPricePerHour = 50,
    this.guelphOnly = true,
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

  // Nearby radius filter; needs a GPS fix or it does nothing.
  final bool proximityEnabled;
  final double proximityRadiusKm;

  // Calendar window filter; drops spots that are closed or already booked.
  final bool availabilityFilterEnabled;
  final DateTime? availRangeStart;
  final DateTime? availRangeEnd;
  final int availStartMinutes;
  final int availEndMinutes;

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
