import 'package:parkd/core/models/availability_specific.dart';
import 'package:parkd/core/models/availability_weekly.dart';
import 'package:parkd/core/models/chat_message_row.dart';
import 'package:parkd/core/models/conversation_row.dart';
import 'package:parkd/core/models/host_earnings_row.dart';
import 'package:parkd/core/models/listing.dart';
import 'package:parkd/core/models/listing_photo.dart';
import 'package:parkd/core/models/message_delivery_status.dart';
import 'package:parkd/core/models/payment_method_row.dart';
import 'package:parkd/core/models/payment_record_status.dart';
import 'package:parkd/core/models/payment_row.dart';
import 'package:parkd/core/models/profile.dart';
import 'package:parkd/core/models/reservation_row.dart';
import 'package:parkd/core/models/reservation_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final fixtureNow = DateTime.utc(2026, 7, 20, 14);

Session fixtureSession({String userId = 'driver-1'}) {
  return Session(
    accessToken: 'test-access-token',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {'display_name': 'Test Driver'},
      aud: 'authenticated',
      email: 'driver@example.test',
      createdAt: fixtureNow.toIso8601String(),
    ),
  );
}

Profile fixtureProfile({String id = 'driver-1'}) {
  return Profile(
    id: id,
    username: 'test_driver',
    fullName: 'Test Driver',
    email: 'driver@example.test',
    rating: 4.8,
    ratingCount: 12,
    createdAt: fixtureNow,
    updatedAt: fixtureNow,
  );
}

Listing fixtureListing({
  String id = 'listing-1',
  String hostId = 'host-1',
  String address = '10 Test Street',
}) {
  return Listing(
    id: id,
    hostId: hostId,
    address: address,
    city: 'Guelph',
    postalCode: 'N1G 2W1',
    country: 'Canada',
    spotNumber: 'A1',
    latitude: 43.5448,
    longitude: -80.2482,
    isActive: true,
    isPublished: true,
    termsAccepted: true,
    termsAcceptedAt: fixtureNow,
    createdAt: fixtureNow,
    updatedAt: fixtureNow,
    heroPhotoUrl: 'https://example.test/listing.jpg',
  );
}

ListingPhoto fixtureListingPhoto({
  String id = 'photo-1',
  String listingId = 'listing-1',
}) {
  return ListingPhoto(
    id: id,
    listingId: listingId,
    photoUrl: 'https://example.test/$id.jpg',
    markerX: 0.4,
    markerY: 0.6,
    createdAt: fixtureNow,
  );
}

AvailabilityWeekly fixtureWeeklyAvailability({
  String id = 'weekly-1',
  String listingId = 'listing-1',
}) {
  return AvailabilityWeekly(
    id: id,
    listingId: listingId,
    dayOfWeek: 1,
    startTime: '09:00',
    endTime: '17:00',
    priceHour: 4,
    priceDay: 24,
    createdAt: fixtureNow,
  );
}

AvailabilitySpecific fixtureSpecificAvailability({
  String id = 'specific-1',
  String listingId = 'listing-1',
}) {
  return AvailabilitySpecific(
    id: id,
    listingId: listingId,
    startDatetime: fixtureNow,
    endDatetime: fixtureNow.add(const Duration(hours: 8)),
    priceHour: 4,
    priceDay: 24,
    createdAt: fixtureNow,
  );
}

PaymentMethodRow fixturePaymentMethod({
  String id = 'payment-method-1',
  String userId = 'driver-1',
  bool isDefault = true,
}) {
  return PaymentMethodRow(
    id: id,
    userId: userId,
    stripePaymentMethodId: 'pm_test_visa',
    brand: 'visa',
    last4: '4242',
    expMonth: 12,
    expYear: 2030,
    isDefault: isDefault,
    createdAt: fixtureNow,
    updatedAt: fixtureNow,
  );
}

ReservationRow fixtureReservation({
  String id = 'reservation-1',
  String listingId = 'listing-1',
  String driverId = 'driver-1',
  String hostId = 'host-1',
  ReservationStatus status = ReservationStatus.confirmed,
}) {
  return ReservationRow(
    id: id,
    listingId: listingId,
    driverId: driverId,
    hostId: hostId,
    startTime: fixtureNow.add(const Duration(days: 1)),
    endTime: fixtureNow.add(const Duration(days: 1, hours: 2)),
    totalPrice: 8,
    serviceFee: 0.28,
    status: status,
    createdAt: fixtureNow,
    updatedAt: fixtureNow,
  );
}

PaymentRow fixturePayment({
  String id = 'payment-1',
  String reservationId = 'reservation-1',
  PaymentRecordStatus status = PaymentRecordStatus.succeeded,
}) {
  return PaymentRow(
    id: id,
    reservationId: reservationId,
    paymentMethodId: 'payment-method-1',
    stripePaymentIntentId: 'pi_test_1',
    amount: 8,
    serviceFee: 0.28,
    status: status,
    createdAt: fixtureNow,
    updatedAt: fixtureNow,
  );
}

ConversationRow fixtureConversation({
  String id = 'conversation-1',
  String reservationId = 'reservation-1',
}) {
  return ConversationRow(
    id: id,
    reservationId: reservationId,
    hostId: 'host-1',
    driverId: 'driver-1',
    isClosed: false,
    createdAt: fixtureNow,
    updatedAt: fixtureNow,
  );
}

ChatMessageRow fixtureMessage({
  String id = 'message-1',
  String conversationId = 'conversation-1',
  String senderId = 'driver-1',
  String message = 'Is the space available?',
}) {
  return ChatMessageRow(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    message: message,
    status: MessageDeliveryStatus.sent,
    createdAt: fixtureNow,
  );
}

HostEarningsRow fixtureHostEarnings({String hostId = 'host-1'}) {
  return HostEarningsRow(
    hostId: hostId,
    month: DateTime.utc(2026, 7),
    reservationCount: 3,
    grossEarnings: 48,
  );
}
