import 'package:flutter/material.dart';

import '../../providers/reservations_providers.dart';
import '../driver_trips_list_screen.dart';

// driver: completed or cancelled trips they booked
class PastReservationsScreen extends StatelessWidget {
  const PastReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DriverTripsListScreen(
      title: 'Past Reservations',
      tripsProvider: driverPastTripsProvider,
      whenEmpty: 'No past reservations',
    );
  }
}
