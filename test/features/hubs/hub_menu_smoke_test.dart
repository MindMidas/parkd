import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/models/notification_row.dart';
import 'package:parkd/core/models/profile.dart';
import 'package:parkd/core/theme/app_theme.dart';
import 'package:parkd/features/hosting/presentation/hosting_menu_body.dart';
import 'package:parkd/features/profile/presentation/account/account_tab_screen.dart';
import 'package:parkd/features/profile/providers/notifications_providers.dart';
import 'package:parkd/features/profile/providers/profile_providers.dart';
import 'package:parkd/features/reservations/presentation/reservations_menu/reservations_menu_body.dart';

void main() {
  const emptyCounts = NotificationHubCounts.empty();

  testWidgets('hosting hub shows menu titles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myNotificationHubCountsProvider.overrideWithValue(emptyCounts),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HostingMenuBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Listing'), findsOneWidget);
    expect(find.text('Manage Listings'), findsOneWidget);
    expect(find.text('Active Bookings'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
  });

  testWidgets('reservations hub shows menu titles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myNotificationHubCountsProvider.overrideWithValue(emptyCounts),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ReservationsMenuBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active Reservations'), findsOneWidget);
    expect(find.text('Past Reservations'), findsOneWidget);
  });

  testWidgets('account hub shows titles and sign out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myNotificationHubCountsProvider.overrideWithValue(emptyCounts),
          currentProfileProvider.overrideWith(
            (ref) async => const Profile(
              id: 'u1',
              fullName: 'Test Host',
              email: 'test@example.com',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountTabScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });
}
