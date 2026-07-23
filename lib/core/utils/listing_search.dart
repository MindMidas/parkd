import '../models/listing.dart';

/// Case-insensitive match on address, locality, and spot label
bool listingMatchesSearchQuery(Listing listing, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;
  return listing.addressLine.toLowerCase().contains(q) ||
      listing.localityLine.toLowerCase().contains(q) ||
      (listing.spotLabel?.toLowerCase().contains(q) ?? false);
}
