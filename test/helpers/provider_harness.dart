import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkd/app/app.dart';
import 'package:parkd/core/stripe/stripe_checkout_provider.dart';
import 'package:parkd/core/stripe/stripe_checkout_remote.dart';
import 'package:parkd/features/auth/providers/auth_providers.dart';
import 'package:parkd/features/hosting/providers/hosting_providers.dart';
import 'package:parkd/features/profile/providers/profile_providers.dart';
import 'package:parkd/features/profile/providers/notifications_providers.dart';
import 'package:parkd/core/supabase/notifications_remote.dart';
import 'package:parkd/features/reservations/providers/reservations_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_repositories.dart';

class MockStripeCheckoutRemote extends Mock implements StripeCheckoutRemote {}

class ParkdTestDependencies {
  ParkdTestDependencies({
    FakeListingsRepository? listings,
    FakeProfileRepository? profiles,
    FakePaymentMethodsRepository? paymentMethods,
    FakeReservationsRepository? reservations,
    FakeMessagingRepository? messaging,
    FakeHostEarningsRepository? earnings,
    MockStripeCheckoutRemote? stripe,
  }) : listings = listings ?? FakeListingsRepository(),
       profiles = profiles ?? FakeProfileRepository(),
       paymentMethods = paymentMethods ?? FakePaymentMethodsRepository(),
       reservations = reservations ?? FakeReservationsRepository(),
       messaging = messaging ?? FakeMessagingRepository(),
       earnings = earnings ?? FakeHostEarningsRepository(),
       stripe = stripe ?? MockStripeCheckoutRemote();

  final FakeListingsRepository listings;
  final FakeProfileRepository profiles;
  final FakePaymentMethodsRepository paymentMethods;
  final FakeReservationsRepository reservations;
  final FakeMessagingRepository messaging;
  final FakeHostEarningsRepository earnings;
  final MockStripeCheckoutRemote stripe;
}

ProviderContainer buildTestContainer({
  required ParkdTestDependencies dependencies,
  Session? session,
  bool needsMfa = false,
}) {
  return ProviderContainer(
    overrides: [
      currentSessionProvider.overrideWithValue(session),
      needsMfaChallengeProvider.overrideWithValue(needsMfa),
      passwordRecoverySessionProvider.overrideWithValue(false),
      listingsRepositoryProvider.overrideWithValue(dependencies.listings),
      profileRepositoryProvider.overrideWithValue(dependencies.profiles),
      paymentMethodsRepositoryProvider.overrideWithValue(
        dependencies.paymentMethods,
      ),
      reservationsRepositoryProvider.overrideWithValue(
        dependencies.reservations,
      ),
      messagingRepositoryProvider.overrideWithValue(dependencies.messaging),
      hostEarningsRepositoryProvider.overrideWithValue(dependencies.earnings),
      stripeCheckoutRemoteProvider.overrideWithValue(dependencies.stripe),
      myNotificationFeedProvider.overrideWith(
        (ref) => Stream.value(const NotificationFeedSnapshot.empty()),
      ),
    ],
  );
}

Widget buildParkdTestApp({
  required ParkdTestDependencies dependencies,
  Session? session,
  bool needsMfa = false,
}) {
  return ProviderScope(
    overrides: [
      currentSessionProvider.overrideWithValue(session),
      needsMfaChallengeProvider.overrideWithValue(needsMfa),
      passwordRecoverySessionProvider.overrideWithValue(false),
      listingsRepositoryProvider.overrideWithValue(dependencies.listings),
      profileRepositoryProvider.overrideWithValue(dependencies.profiles),
      paymentMethodsRepositoryProvider.overrideWithValue(
        dependencies.paymentMethods,
      ),
      reservationsRepositoryProvider.overrideWithValue(
        dependencies.reservations,
      ),
      messagingRepositoryProvider.overrideWithValue(dependencies.messaging),
      hostEarningsRepositoryProvider.overrideWithValue(dependencies.earnings),
      stripeCheckoutRemoteProvider.overrideWithValue(dependencies.stripe),
      myNotificationFeedProvider.overrideWith(
        (ref) => Stream.value(const NotificationFeedSnapshot.empty()),
      ),
    ],
    child: const ParkdApp(),
  );
}
