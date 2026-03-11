import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_providers.dart';

class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key});

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authRepository = ref.watch(authRepositoryProvider);

    return Scaffold(
      body: _selectedIndex == 0
          ? FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(28.6139, 77.2090),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.parkd.app',
                ),
              ],
            )
          : Container(
              width: double.infinity,
              color: AppColors.secondaryBlue,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Profile tab placeholder'),
                  const SizedBox(height: 12),
                  AppPrimaryButton(
                    label: 'Logout',
                    onPressed: () async {
                      await authRepository.signOut();
                    },
                  ),
                ],
              ),
            ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
