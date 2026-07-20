/// Map search filters (client-side on top of Supabase query)
class MapFilters {
  const MapFilters({this.maxPricePerHour = 50, this.guelphOnly = true});

  final double maxPricePerHour;

  final bool guelphOnly;

  MapFilters copyWith({double? maxPricePerHour, bool? guelphOnly}) {
    return MapFilters(
      maxPricePerHour: maxPricePerHour ?? this.maxPricePerHour,
      guelphOnly: guelphOnly ?? this.guelphOnly,
    );
  }
}
