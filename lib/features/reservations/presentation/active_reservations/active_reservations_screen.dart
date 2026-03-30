import 'package:flutter/material.dart';

import '../../providers/reservations_providers.dart';
import '../driver_trips_list_screen.dart';

// driver: trips they booked that are still active (pending/confirmed/active)
class ActiveReservationsScreen extends StatelessWidget {
  const ActiveReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DriverTripsListScreen(
      title: 'Active Reservations',
      tripsProvider: driverActiveTripsProvider,
      whenEmpty: 'No active reservations',
    );
  }
}
