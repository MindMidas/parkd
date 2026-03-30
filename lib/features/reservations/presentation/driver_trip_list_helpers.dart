import '../../../core/models/listing.dart';
import '../../../core/models/reservation_row.dart';
import '../../../core/utils/listing_search.dart';

bool driverTripRowMatchesSearchQuery({
  required ReservationRow reservation,
  required Listing? listing,
  required String query,
}) {
  final q = query.trim();
  if (q.isEmpty) return true;
  if (listing != null && listingMatchesSearchQuery(listing, q)) return true;
  return reservation.id.toLowerCase().contains(q.toLowerCase());
}
