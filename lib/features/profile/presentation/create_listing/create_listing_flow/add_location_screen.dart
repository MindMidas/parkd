import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parkd/core/widgets/app_step_top_bar.dart';

import '../../manage_listings/edit/upload_listing_photo_screen.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../home/presentation/home_map_screen.dart';
import '../../../../home/presentation/map.dart';

class AddLocationScreen extends ConsumerStatefulWidget {
  const AddLocationScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends ConsumerState<AddLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  // ignore: unused_field
  String _selectedAddress =
      ''; // this will be updated when user selects an address from search suggestions

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppStepTopBar(
        title: 'Enter the parking spot address',
        currentStep: 1,
        totalSteps: 5,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                const MapView(),
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: AppSearchField(
                    hintText: 'Search for a location…',
                    showFilterButton: true,
                    onFilterTap: () {
                      /* open filter sheet */
                    },
                    suggestionsBuilder: (query) async {
                      // API call here
                      return [
                        '25 MacNaughton Spring St...',
                        '25 Macdonell Street, Guelph...',
                      ];
                    },
                    onSelected: (address) {
                      setState(() => _selectedAddress = address);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UploadListingPhotoScreen(
                            listingId: widget.listingId,
                            currentStep: 2,
                            totalSteps: 5,
                            selectedAddress: address,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => HomeMapScreen(initialIndex: index),
            ),
            (route) => false,
          );
        },
      ),
    );
  }
}
