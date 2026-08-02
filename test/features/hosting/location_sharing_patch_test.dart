import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/models/listing.dart';

import '../../helpers/fake_repositories.dart';

void main() {
  test('patchListing updates locationSharing on fake repo', () async {
    final repo = FakeListingsRepository();
    const id = 'listing-1';
    repo.listings[id] = Listing(
      id: id,
      hostId: 'host-1',
      address: '1 Main St',
      city: 'Toronto',
      country: 'Canada',
      latitude: 43.65,
      longitude: -79.38,
      locationSharing: ListingLocationSharing.general,
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );

    await repo.patchListing(
      listingId: id,
      locationSharing: ListingLocationSharing.specific,
    );

    expect(
      repo.listings[id]!.locationSharing,
      ListingLocationSharing.specific,
    );
  });
}
