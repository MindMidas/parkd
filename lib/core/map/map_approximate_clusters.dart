import '../models/listing.dart';
import 'map_geo.dart';

/// Groups approximate public listings that share the same privacy grid cell.
/// Exact (unlocked) listings are omitted — they render as individual pins.
Map<String, List<Listing>> clusterApproximateListingsByCell(
  Iterable<Listing> listings,
) {
  final byCell = <String, List<Listing>>{};
  for (final listing in listings) {
    if (!listing.isApproximateLocation) continue;
    final key = approximateLocationCellKey(
      listing.latitude,
      listing.longitude,
    );
    (byCell[key] ??= <Listing>[]).add(listing);
  }
  for (final group in byCell.values) {
    group.sort((a, b) => a.id.compareTo(b.id));
  }
  return byCell;
}
