import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parkd/core/widgets/app_step_top_bar.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../manage_listings/edit/upload_listing_photo_screen.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../home/presentation/home_map_screen.dart';
import '../../../../home/presentation/map.dart';
import '../../../../../core/models/search_result.dart';

class AddLocationScreen extends ConsumerStatefulWidget {
  const AddLocationScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends ConsumerState<AddLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedAddress = '';
  List<SearchResult> _cachedResults = []; // store full results here

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
                    controller: _searchController,
                    hintText: 'Search for a location…',
                    showFilterButton: true,
                    onFilterTap: () { /* open filter sheet */ },
                    suggestionsBuilder: (query) async {
                      if (query.trim().isEmpty) {
                        _cachedResults = [];
                        return [];
                      }
                      try {
                        final uri = Uri.parse(
                          'https://corsproxy.io/?https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent('$query, Guelph, Ontario')}&format=json&limit=5&addressdetails=1&countrycodes=ca',
                        );
                        final response = await http.get(
                          uri,
                          headers: {'User-Agent': 'parkd-app/1.0'},
                        );
                        if (response.statusCode == 200) {
                          final List<dynamic> data = json.decode(response.body);
                          _cachedResults = data.map((item) {
                            final addr = item['address'] as Map<String, dynamic>? ?? {};
                            return SearchResult(
                              displayName: item['display_name'] as String,
                              lat: double.parse(item['lat'] as String),
                              lon: double.parse(item['lon'] as String),
                              road: addr['road'] as String? ?? '',
                              houseNumber: addr['house_number'] as String? ?? '',
                              city: addr['city'] as String? ??
                                    addr['town'] as String? ??
                                    addr['village'] as String? ?? '',
                              state: addr['state'] as String? ?? '',
                              postcode: addr['postcode'] as String? ?? '',
                            );
                          }).toList();
                          // Return only display names (strings) to AppSearchField
                          return _cachedResults.map((r) => r.displayName).toList();
                        }
                      } catch (_) {}
                      _cachedResults = [];
                      return [];
                    },
                    onSelected: (displayName) {
                      // Match selected string back to the full SearchResult
                      final result = _cachedResults.firstWhere(
                        (r) => r.displayName == displayName,
                        orElse: () => SearchResult(displayName: displayName, lat: 0, lon: 0),
                      );
                      final address = result.houseNumber.isNotEmpty
                          ? '${result.houseNumber} ${result.road}'
                          : result.road;

                      setState(() => _selectedAddress = result.displayName);
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