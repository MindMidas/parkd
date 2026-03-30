import '../models/listing.dart';

// case-insens match on addrs, locality, and spot label
bool listingMatchesSearchQuery(Listing listing, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;
  return listing.addressLine.toLowerCase().contains(q) ||
      listing.localityLine.toLowerCase().contains(q) ||
      (listing.spotLabel?.toLowerCase().contains(q) ?? false);
}
