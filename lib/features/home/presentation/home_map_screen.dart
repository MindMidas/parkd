import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../profile/presentation/profile_menu/profile_menu_screen.dart';
import 'book_listing_screen.dart';

class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key, this.initialIndex = 0});

  /// 0 = Map, 1 = Profile.
  final int initialIndex;

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  late int _selectedIndex;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<_SearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  String _lastSearchQuery = '';

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
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchAddress(query.trim());
    });
  }

  Future<void> _searchAddress(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent('$query, Guelph, Ontario')}&format=json&limit=5&addressdetails=1&countrycodes=ca',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'parkd-app/1.0',
      });
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data
              .map((item) {
                final addr = item['address'] as Map<String, dynamic>? ?? {};
                return _SearchResult(
                  displayName: item['display_name'] as String,
                  lat: double.parse(item['lat'] as String),
                  lon: double.parse(item['lon'] as String),
                  road: addr['road'] as String? ?? '',
                  houseNumber: addr['house_number'] as String? ?? '',
                  city: addr['city'] as String? ?? addr['town'] as String? ?? addr['village'] as String? ?? '',
                  state: addr['state'] as String? ?? '',
                  postcode: addr['postcode'] as String? ?? '',
                );
              })
              .toList();
          _showResults = true;
          _isSearching = false;
        });
      }
    } catch (_) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _onResultTapped(_SearchResult result) {
    final query = _searchController.text.trim();
    setState(() {
      _lastSearchQuery = query.isNotEmpty ? query : result.city;
      _showResults = false;
      _searchController.clear();
      _searchResults = [];
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookListingScreen(
          searchQuery: _lastSearchQuery,
          displayName: result.displayName,
          streetAddress: result.houseNumber.isNotEmpty
              ? '${result.houseNumber} ${result.road}'
              : result.road,
          cityLine: [
            result.city,
            'ON',
            result.postcode,
          ].where((s) => s.isNotEmpty).join(', '),
          latitude: result.lat,
          longitude: result.lon,
        ),
      ),
    );
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
                    ],
                  ),
                  // Search bar + results overlay
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          color: Colors.white,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: AppSearchField(
                            controller: _searchController,
                            hintText: 'Search address',
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        if (_isSearching)
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          ),
                        if (_showResults && _searchResults.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 300),
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, _) => const AppDivider(),
                              itemBuilder: (context, index) {
                                final result = _searchResults[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.location_on_outlined,
                                    color: AppColors.primaryBlue,
                                    size: 20,
                                  ),
                                  title: Text(
                                    result.displayName,
                                    style: AppTypography.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  dense: true,
                                  onTap: () => _onResultTapped(result),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : const ProfileMenuScreen(),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 0) {
              _showResults = false;
              _searchController.clear();
              _searchResults = [];
            }
          });
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search result model
// ---------------------------------------------------------------------------

class _SearchResult {
  const _SearchResult({
    required this.displayName,
    required this.lat,
    required this.lon,
    this.road = '',
    this.houseNumber = '',
    this.city = '',
    this.state = '',
    this.postcode = '',
  });

  final String displayName;
  final double lat;
  final double lon;
  final String road;
  final String houseNumber;
  final String city;
  final String state;
  final String postcode;
}
