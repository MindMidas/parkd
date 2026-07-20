import 'package:parkd/core/map/map_filters.dart';
import 'package:parkd/core/models/availability_specific.dart';
import 'package:parkd/core/models/availability_weekly.dart';
import 'package:parkd/core/models/booking_time_window.dart';
import 'package:parkd/core/models/chat_message_row.dart';
import 'package:parkd/core/models/conversation_row.dart';
import 'package:parkd/core/models/host_earnings_row.dart';
import 'package:parkd/core/models/host_listing_booking_thread.dart';
import 'package:parkd/core/models/host_payment_transaction.dart';
import 'package:parkd/core/models/listing.dart';
import 'package:parkd/core/models/listing_photo.dart';
import 'package:parkd/core/models/message_delivery_status.dart';
import 'package:parkd/core/models/payment_method_row.dart';
import 'package:parkd/core/models/payment_row.dart';
import 'package:parkd/core/models/profile.dart';
import 'package:parkd/core/models/reservation_row.dart';
import 'package:parkd/core/models/reservation_status.dart';
import 'package:parkd/features/hosting/data/host_earnings_repository.dart';
import 'package:parkd/features/profile/data/listings_repository.dart';
import 'package:parkd/features/profile/data/payment_methods_repository.dart';
import 'package:parkd/features/profile/data/profile_repository.dart';
import 'package:parkd/features/reservations/data/messaging_repository.dart';
import 'package:parkd/features/reservations/data/reservations_repository.dart';

import 'fixtures.dart';

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([Iterable<Profile> seed = const []]) {
    profiles.addEntries(seed.map((profile) => MapEntry(profile.id, profile)));
  }

  final Map<String, Profile> profiles = {};
  final List<String> requestedUserIds = [];
  final List<String> updatedUserIds = [];
  final List<String> uploadedAvatarUserIds = [];

  @override
  Future<Profile?> getProfile(String userId) async {
    requestedUserIds.add(userId);
    return profiles[userId];
  }

  @override
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? phoneE164,
    DateTime? birthDate,
    String? username,
    String? email,
  }) async {
    updatedUserIds.add(userId);
    final current = profiles[userId];
    profiles[userId] = Profile(
      id: userId,
      fullName: fullName,
      phone: phoneE164,
      birthDate: birthDate,
      username: username,
      email: email,
      rating: current?.rating ?? 0,
      ratingCount: current?.ratingCount ?? 0,
      avatarUrl: current?.avatarUrl,
      createdAt: current?.createdAt,
      updatedAt: fixtureNow,
    );
  }

  @override
  Future<void> uploadAvatar({
    required String userId,
    required String localFilePath,
  }) async {
    uploadedAvatarUserIds.add(userId);
  }
}

class FakeListingsRepository implements ListingsRepository {
  FakeListingsRepository([Iterable<Listing> seed = const []]) {
    listings.addEntries(seed.map((listing) => MapEntry(listing.id, listing)));
  }

  final Map<String, Listing> listings = {};
  final Map<String, List<ListingPhoto>> photosByListing = {};
  final Map<String, List<AvailabilityWeekly>> weeklyByListing = {};
  final Map<String, List<AvailabilitySpecific>> specificByListing = {};
  final Map<String, List<BookingTimeWindow>> bookingBlocksByListing = {};
  final List<String> requestedListingIds = [];
  int publishedMapRequestCount = 0;

  @override
  Future<List<Listing>> getMyListings(String userId) async {
    return listings.values
        .where((listing) => listing.hostId == userId)
        .toList();
  }

  @override
  Future<Listing?> getListingById(String id) async {
    requestedListingIds.add(id);
    return listings[id];
  }

  @override
  Future<List<ListingPhoto>> getListingPhotos(String listingId) async {
    return List.unmodifiable(photosByListing[listingId] ?? const []);
  }

  @override
  Future<List<AvailabilityWeekly>> getAvailabilityWeekly(
    String listingId,
  ) async {
    return List.unmodifiable(weeklyByListing[listingId] ?? const []);
  }

  @override
  Future<List<AvailabilitySpecific>> getAvailabilitySpecific(
    String listingId,
  ) async {
    return List.unmodifiable(specificByListing[listingId] ?? const []);
  }

  @override
  Future<List<BookingTimeWindow>> getBookingBlocksOverlapping(
    String listingId, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    return List.unmodifiable(bookingBlocksByListing[listingId] ?? const []);
  }

  @override
  Future<List<Listing>> getPublishedListingsForMap({
    MapFilters? filters,
  }) async {
    publishedMapRequestCount++;
    return listings.values.where((listing) => listing.isPublished).toList();
  }

  @override
  Future<Listing> createListing({
    required String hostId,
    required String address,
    required String city,
    String? postalCode,
    required String country,
    String? spotNumber,
    required double latitude,
    required double longitude,
    String availabilityMode = 'weekly',
  }) async {
    final id = 'listing-${listings.length + 1}';
    final listing = Listing(
      id: id,
      hostId: hostId,
      address: address,
      city: city,
      postalCode: postalCode,
      country: country,
      spotNumber: spotNumber,
      latitude: latitude,
      longitude: longitude,
      availabilityMode: availabilityMode,
    );
    listings[id] = listing;
    return listing;
  }

  @override
  Future<void> deleteListing(String listingId) async {
    listings.remove(listingId);
  }

  @override
  Future<void> patchListing({
    required String listingId,
    String? address,
    String? city,
    String? postalCode,
    String? country,
    String? spotNumber,
    double? latitude,
    double? longitude,
    bool? isActive,
    bool? isPublished,
    bool? termsAccepted,
    DateTime? termsAcceptedAt,
    String? availabilityMode,
  }) async {
    final current = listings[listingId];
    if (current == null) return;
    listings[listingId] = Listing(
      id: current.id,
      hostId: current.hostId,
      address: address ?? current.address,
      city: city ?? current.city,
      postalCode: postalCode ?? current.postalCode,
      country: country ?? current.country,
      spotNumber: spotNumber ?? current.spotNumber,
      latitude: latitude ?? current.latitude,
      longitude: longitude ?? current.longitude,
      availabilityMode: availabilityMode ?? current.availabilityMode,
      isActive: isActive ?? current.isActive,
      isPublished: isPublished ?? current.isPublished,
      termsAccepted: termsAccepted ?? current.termsAccepted,
      termsAcceptedAt: termsAcceptedAt ?? current.termsAcceptedAt,
      createdAt: current.createdAt,
      updatedAt: fixtureNow,
      heroPhotoUrl: current.heroPhotoUrl,
    );
  }

  @override
  Future<ListingPhoto> addListingPhotoFromLocalPath({
    required String listingId,
    required String localFilePath,
    int sortOrder = 0,
  }) async {
    final photo = fixtureListingPhoto(
      id: 'photo-${photosByListing[listingId]?.length ?? 0}',
      listingId: listingId,
    );
    photosByListing.putIfAbsent(listingId, () => []).add(photo);
    return photo;
  }

  @override
  Future<void> deleteListingPhoto(String photoId) async {
    for (final photos in photosByListing.values) {
      photos.removeWhere((photo) => photo.id == photoId);
    }
  }

  @override
  Future<void> reorderListingPhotos({
    required String listingId,
    required List<String> photoIdsInOrder,
  }) async {
    final current = photosByListing[listingId] ?? [];
    final byId = {for (final photo in current) photo.id: photo};
    photosByListing[listingId] = [
      for (final id in photoIdsInOrder)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Future<void> setHeroPhotoSpotMarker({
    required String listingId,
    required double markerX,
    required double markerY,
  }) async {}

  @override
  Future<void> setAllAvailabilitySlotPrices({
    required String listingId,
    required double priceHour,
    double? priceDay,
  }) async {}

  @override
  Future<void> updateAvailabilityWeeklySlotPrices({
    required String slotId,
    required double priceHour,
    double? priceDay,
  }) async {}

  @override
  Future<AvailabilityWeekly> insertAvailabilityWeeklySlot({
    required String listingId,
    required int dayOfWeek,
    required String startTimeHhMm,
    required String endTimeHhMm,
    double priceHour = 0,
    double? priceDay,
  }) async {
    final slot = AvailabilityWeekly(
      id: 'weekly-${weeklyByListing[listingId]?.length ?? 0}',
      listingId: listingId,
      dayOfWeek: dayOfWeek,
      startTime: startTimeHhMm,
      endTime: endTimeHhMm,
      priceHour: priceHour,
      priceDay: priceDay,
    );
    weeklyByListing.putIfAbsent(listingId, () => []).add(slot);
    return slot;
  }

  @override
  Future<void> deleteAvailabilityWeeklySlot(String slotId) async {
    for (final slots in weeklyByListing.values) {
      slots.removeWhere((slot) => slot.id == slotId);
    }
  }

  @override
  Future<void> updateAvailabilitySpecificSlotPrices({
    required String slotId,
    required double priceHour,
    double? priceDay,
  }) async {}

  @override
  Future<AvailabilitySpecific> insertAvailabilitySpecificSlot({
    required String listingId,
    required DateTime start,
    required DateTime end,
    double priceHour = 0,
    double? priceDay,
  }) async {
    final slot = AvailabilitySpecific(
      id: 'specific-${specificByListing[listingId]?.length ?? 0}',
      listingId: listingId,
      startDatetime: start,
      endDatetime: end,
      priceHour: priceHour,
      priceDay: priceDay,
    );
    specificByListing.putIfAbsent(listingId, () => []).add(slot);
    return slot;
  }

  @override
  Future<void> deleteAvailabilitySpecificSlot(String slotId) async {
    for (final slots in specificByListing.values) {
      slots.removeWhere((slot) => slot.id == slotId);
    }
  }
}

class FakePaymentMethodsRepository implements PaymentMethodsRepository {
  FakePaymentMethodsRepository([Iterable<PaymentMethodRow> seed = const []])
    : methods = List.of(seed);

  final List<PaymentMethodRow> methods;
  final List<String> requestedUserIds = [];

  @override
  Future<List<PaymentMethodRow>> listForUser(String userId) async {
    requestedUserIds.add(userId);
    return methods.where((method) => method.userId == userId).toList();
  }

  @override
  Future<PaymentMethodRow> addMethod({
    required String userId,
    String? stripePaymentMethodId,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
    bool setAsDefault = false,
  }) async {
    if (setAsDefault) {
      for (var i = 0; i < methods.length; i++) {
        final current = methods[i];
        if (current.userId == userId) {
          methods[i] = _copyMethod(current, isDefault: false);
        }
      }
    }
    final method = PaymentMethodRow(
      id: 'payment-method-${methods.length + 1}',
      userId: userId,
      stripePaymentMethodId: stripePaymentMethodId,
      brand: brand,
      last4: last4,
      expMonth: expMonth,
      expYear: expYear,
      isDefault: setAsDefault,
      createdAt: fixtureNow,
      updatedAt: fixtureNow,
    );
    methods.add(method);
    return method;
  }

  @override
  Future<void> setDefault({required String userId, required String id}) async {
    for (var i = 0; i < methods.length; i++) {
      final current = methods[i];
      if (current.userId == userId) {
        methods[i] = _copyMethod(current, isDefault: current.id == id);
      }
    }
  }

  @override
  Future<void> remove({required String userId, required String id}) async {
    methods.removeWhere((method) => method.userId == userId && method.id == id);
  }

  @override
  Future<void> updateDisplayFields({
    required String userId,
    required String id,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
  }) async {
    final index = methods.indexWhere(
      (method) => method.userId == userId && method.id == id,
    );
    if (index < 0) return;
    final current = methods[index];
    methods[index] = PaymentMethodRow(
      id: current.id,
      userId: current.userId,
      stripePaymentMethodId: current.stripePaymentMethodId,
      brand: brand ?? current.brand,
      last4: last4 ?? current.last4,
      expMonth: expMonth ?? current.expMonth,
      expYear: expYear ?? current.expYear,
      isDefault: current.isDefault,
      createdAt: current.createdAt,
      updatedAt: fixtureNow,
    );
  }

  static PaymentMethodRow _copyMethod(
    PaymentMethodRow current, {
    required bool isDefault,
  }) {
    return PaymentMethodRow(
      id: current.id,
      userId: current.userId,
      stripePaymentMethodId: current.stripePaymentMethodId,
      brand: current.brand,
      last4: current.last4,
      expMonth: current.expMonth,
      expYear: current.expYear,
      isDefault: isDefault,
      createdAt: current.createdAt,
      updatedAt: fixtureNow,
    );
  }
}

class FakeReservationsRepository implements ReservationsRepository {
  FakeReservationsRepository({
    Iterable<ReservationRow> reservations = const [],
    Iterable<PaymentRow> payments = const [],
  }) {
    this.reservations.addEntries(
      reservations.map((row) => MapEntry(row.id, row)),
    );
    paymentsByReservation.addEntries(
      payments.map((row) => MapEntry(row.reservationId, row)),
    );
  }

  final Map<String, ReservationRow> reservations = {};
  final Map<String, PaymentRow> paymentsByReservation = {};
  final List<({String userId, bool activeOnly})> driverTripRequests = [];
  final List<({String userId, bool activeOnly})> hostTripRequests = [];

  @override
  Future<ReservationRow?> getReservation(String id) async => reservations[id];

  @override
  Future<List<ReservationRow>> listDriverTrips({
    required String driverId,
    required bool activeOnly,
  }) async {
    driverTripRequests.add((userId: driverId, activeOnly: activeOnly));
    return reservations.values
        .where(
          (row) =>
              row.driverId == driverId && _matchesActivity(row, activeOnly),
        )
        .toList();
  }

  @override
  Future<List<ReservationRow>> listHostTrips({
    required String hostId,
    required bool activeOnly,
  }) async {
    hostTripRequests.add((userId: hostId, activeOnly: activeOnly));
    return reservations.values
        .where(
          (row) => row.hostId == hostId && _matchesActivity(row, activeOnly),
        )
        .toList();
  }

  @override
  Future<void> cancelCheckoutHold(String id) async {
    final current = reservations[id];
    if (current == null) return;
    reservations[id] = ReservationRow(
      id: current.id,
      listingId: current.listingId,
      driverId: current.driverId,
      hostId: current.hostId,
      startTime: current.startTime,
      endTime: current.endTime,
      totalPrice: current.totalPrice,
      serviceFee: current.serviceFee,
      status: ReservationStatus.cancelled,
      extendedFromReservationId: current.extendedFromReservationId,
      createdAt: current.createdAt,
      updatedAt: fixtureNow,
    );
  }

  @override
  Future<PaymentRow?> paymentForReservation(String reservationId) async {
    return paymentsByReservation[reservationId];
  }

  static bool _matchesActivity(ReservationRow row, bool activeOnly) {
    final active =
        row.status == ReservationStatus.pending ||
        row.status == ReservationStatus.confirmed ||
        row.status == ReservationStatus.active;
    return activeOnly ? active : !active;
  }
}

class FakeMessagingRepository implements MessagingRepository {
  FakeMessagingRepository({
    Iterable<ConversationRow> conversations = const [],
    Iterable<ChatMessageRow> messages = const [],
    Iterable<HostListingBookingThread> hostThreads = const [],
  }) : hostThreads = List.of(hostThreads) {
    this.conversations.addEntries(
      conversations.map((row) => MapEntry(row.id, row)),
    );
    for (final message in messages) {
      messagesByConversation
          .putIfAbsent(message.conversationId, () => [])
          .add(message);
    }
  }

  final Map<String, ConversationRow> conversations = {};
  final Map<String, List<ChatMessageRow>> messagesByConversation = {};
  final List<HostListingBookingThread> hostThreads;
  final List<String> inboxRequests = [];

  @override
  Future<ConversationRow> ensureThread(String reservationId) async {
    final existing = conversations.values
        .where((row) => row.reservationId == reservationId)
        .firstOrNull;
    if (existing != null) return existing;
    final row = fixtureConversation(
      id: 'conversation-${conversations.length + 1}',
      reservationId: reservationId,
    );
    conversations[row.id] = row;
    return row;
  }

  @override
  Future<List<ConversationRow>> inboxForUser(String userId) async {
    inboxRequests.add(userId);
    return conversations.values
        .where((row) => row.driverId == userId || row.hostId == userId)
        .toList();
  }

  @override
  Future<List<HostListingBookingThread>> listHostListingThreads({
    required String hostId,
    required String listingId,
    required bool activeOnly,
  }) async {
    return hostThreads
        .where(
          (thread) =>
              thread.reservation.hostId == hostId &&
              thread.reservation.listingId == listingId,
        )
        .toList();
  }

  @override
  Future<List<ChatMessageRow>> messages(String conversationId) async {
    return List.unmodifiable(
      messagesByConversation[conversationId] ?? const [],
    );
  }

  @override
  Stream<List<ChatMessageRow>> watchMessages(String conversationId) {
    return Stream.value(
      List.unmodifiable(
        messagesByConversation[conversationId] ?? const <ChatMessageRow>[],
      ),
    );
  }

  @override
  Future<ChatMessageRow> send({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    final row = ChatMessageRow(
      id: 'message-${messagesByConversation[conversationId]?.length ?? 0}',
      conversationId: conversationId,
      senderId: senderId,
      message: text,
      status: MessageDeliveryStatus.sent,
      createdAt: fixtureNow,
    );
    messagesByConversation.putIfAbsent(conversationId, () => []).add(row);
    return row;
  }

  @override
  Future<void> markRead(String messageId) async {}
}

class FakeHostEarningsRepository implements HostEarningsRepository {
  FakeHostEarningsRepository({
    Iterable<HostEarningsRow> earnings = const [],
    Iterable<HostPaymentTransaction> transactions = const [],
  }) : earnings = List.of(earnings),
       transactions = List.of(transactions);

  final List<HostEarningsRow> earnings;
  final List<HostPaymentTransaction> transactions;
  final List<String> requestedHostIds = [];

  @override
  Future<List<HostEarningsRow>> listForHost(String hostId) async {
    requestedHostIds.add(hostId);
    return earnings.where((row) => row.hostId == hostId).toList();
  }

  @override
  Future<List<HostPaymentTransaction>> listSucceededTransactionsForHost(
    String hostId,
  ) async {
    requestedHostIds.add(hostId);
    return transactions
        .where((row) => row.reservation.hostId == hostId)
        .toList();
  }
}
