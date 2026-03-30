import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/map/map_filters.dart';
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
}

final mapFiltersProvider = NotifierProvider<MapFiltersNotifier, MapFilters>(
  MapFiltersNotifier.new,
);

final mapPublishedListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final filters = ref.watch(mapFiltersProvider);
  return ref
      .read(listingsRepositoryProvider)
      .getPublishedListingsForMap(filters: filters);
});
