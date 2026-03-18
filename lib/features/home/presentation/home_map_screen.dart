import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../profile/presentation/profile_menu/profile_menu_screen.dart';
import 'map.dart';

class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key, this.initialIndex = 0});

  /// 0 = Map, 1 = Profile.
  final int initialIndex;

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 1);
  }

  @override
  void didUpdateWidget(HomeMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _selectedIndex = widget.initialIndex.clamp(0, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _selectedIndex == 0
          ? ColoredBox(
              color: Colors.white,
              child: SafeArea(
                top: true,
                bottom: false,
                child: Stack(
                  children: [
                    const MapView(),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        width: double.infinity,
                        color: Colors.white,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: const AppSearchField(),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const ProfileMenuScreen(),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}