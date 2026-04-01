import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/map/map_filters.dart';
import '../../../core/map/map_user_location.dart';
import '../../../core/models/listing.dart';
import '../../profile/providers/profile_providers.dart';

class MapFiltersNotifier extends Notifier<MapFilters> {
  @override
  MapFilters build() => const MapFilters();

  void setMaxPricePerHour(double v) {
    state = state.copyWith(maxPricePerHour: v);
  }

  void setGuelphOnly(bool v) {
    state = state.copyWith(guelphOnly: v);
  }

  void setProximityEnabled(bool v) {
    state = state.copyWith(proximityEnabled: v);
  }

  void setProximityRadiusKm(double v) {
    state = state.copyWith(proximityRadiusKm: v);
  }

  void setAvailabilityFilterEnabled(bool v) {
    state = state.copyWith(availabilityFilterEnabled: v);
  }

  void setAvailRange(DateTime? start, DateTime? end) {
    state = MapFilters(
      maxPricePerHour: state.maxPricePerHour,
      guelphOnly: state.guelphOnly,
      proximityEnabled: state.proximityEnabled,
      proximityRadiusKm: state.proximityRadiusKm,
      availabilityFilterEnabled: state.availabilityFilterEnabled,
      availRangeStart: start,
      availRangeEnd: end,
      availStartMinutes: state.availStartMinutes,
      availEndMinutes: state.availEndMinutes,
    );
  }

  void setAvailStartMinutes(int v) {
    state = state.copyWith(availStartMinutes: v);
  }

  void setAvailEndMinutes(int v) {
    state = state.copyWith(availEndMinutes: v);
  }
}

final mapFiltersProvider = NotifierProvider<MapFiltersNotifier, MapFilters>(
  MapFiltersNotifier.new,
);

final mapPublishedListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final filters = ref.watch(mapFiltersProvider);
  double? uLat;
  double? uLon;
  if (filters.proximityEnabled) {
    final pos = await getCurrentUserPositionIfAllowed();
    uLat = pos?.latitude;
    uLon = pos?.longitude;
  }
  return ref.read(listingsRepositoryProvider).getPublishedListingsForMap(
        filters: filters,
        proximityUserLatitude: uLat,
        proximityUserLongitude: uLon,
      );
});
