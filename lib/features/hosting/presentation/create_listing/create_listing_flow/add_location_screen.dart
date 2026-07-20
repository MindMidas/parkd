import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../manage_listings/edit/upload_listing_photo_screen.dart';
import '../../../../../core/map/map_constants.dart';
import '../../../../../core/map/map_listing_camera.dart';
import '../../../../../core/map/map_user_location.dart';
import '../../../../../core/map/nominatim_geocoding.dart';
import '../../../../../core/models/search_result.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../map/presentation/map.dart';
import '../create_listing_draft.dart';
import '../create_listing_flow_constants.dart';

enum _LocationPhase { search, adjustPin }

/// Pin the spot, then continue the wizard with an in-memory [CreateListingDraft]
/// (no DB row until publish on the terms step)
class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({super.key});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final TextEditingController _searchController = TextEditingController();

  _LocationPhase _phase = _LocationPhase.search;
  SearchResult? _picked;
  double? _pinLat;
  double? _pinLon;
  MapboxMap? _map;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onMapReady(MapboxMap map) async {
    _map = map;
    if (_phase == _LocationPhase.search) {
      await tryCenterMapOnUserLocation(map);
    }
  }

  void _onAddressPicked(SearchResult result) {
    setState(() {
      _picked = result;
      _pinLat = result.lat;
      _pinLon = result.lon;
    });
    final m = _map;
    if (m != null) {
      unawaited(
        flyMapToLatLonWithoutPadding(
          m,
          latitude: result.lat,
          longitude: result.lon,
          zoom: 15.5,
        ),
      );
    }
  }

  void _useSearchResultLocation() {
    if (_picked == null || _pinLat == null || _pinLon == null) return;
    setState(() => _phase = _LocationPhase.adjustPin);
    final m = _map;
    if (m != null) {
      unawaited(
        flyMapToLatLonWithoutPadding(
          m,
          latitude: _pinLat!,
          longitude: _pinLon!,
          zoom: 18,
        ),
      );
    }
  }

  void _onMapTapAdjustPin(double lat, double lon) {
    setState(() {
      _pinLat = lat;
      _pinLon = lon;
    });
  }

  void _goToPhotoStep() {
    final r = _picked;
    final lat = _pinLat;
    final lon = _pinLon;
    if (r == null || lat == null || lon == null) return;

    final draft = CreateListingDraft()
      ..picked = r
      ..pinLat = lat
      ..pinLon = lon;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadListingPhotoScreen(
          createDraft: draft,
          currentStep: 2,
          totalSteps: kCreateListingTotalSteps,
          selectedAddress: draft.addressLine,
          latitude: lat,
          longitude: lon,
        ),
      ),
    );
  }

  void _onStepBack() {
    if (_phase == _LocationPhase.adjustPin) {
      setState(() => _phase = _LocationPhase.search);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + AppSpacing.lg;
    final fabBottom = bottomInset + AppSpacing.primaryButtonMinHeight + 12;
    final compassMb =
        fabBottom + kParkdMapRecenterFabSize + kParkdMapCompassGapAboveFab;
    final showSearch = _phase == _LocationPhase.search;

    return PopScope(
      canPop: _phase == _LocationPhase.search,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_phase == _LocationPhase.adjustPin) {
          setState(() => _phase = _LocationPhase.search);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppStepTopBar(
          title: 'Set parking spot address',
          currentStep: 1,
          totalSteps: kCreateListingTotalSteps,
          onBack: _onStepBack,
        ),
        body: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: MapView(
                mapLayerId: 'parkd_create_listing_map',
                listings: const [],
                useListingPinForDraft: true,
                recenterCameraOnDraftPinChange: false,
                draftPin: _pinLat != null && _pinLon != null
                    ? (lat: _pinLat!, lon: _pinLon!)
                    : null,
                onMapReady: _onMapReady,
                onMapSurfaceTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                onMapContentTap: _phase == _LocationPhase.adjustPin
                    ? _onMapTapAdjustPin
                    : null,
                onRecenterPressed: () async {
                  final m = _map;
                  if (m != null) {
                    await tryCenterMapOnUserLocation(m);
                  }
                },
                mapRecenterFabBottomOffset: fabBottom,
                compassBottomMargin: compassMb,
              ),
            ),
            if (showSearch)
              Positioned(
                left: AppSpacing.mapSearchOverlayHorizontal,
                right: AppSpacing.mapSearchOverlayHorizontal,
                top: AppSpacing.sm,
                child: AppMapAddressSearchPanel(
                  controller: _searchController,
                  hintText: 'Search for an address…',
                  showFilterButton: false,
                  searchFn: searchAddressesForCreateListing,
                  onResultSelected: _onAddressPicked,
                ),
              ),
            if (_phase == _LocationPhase.adjustPin)
              Positioned(
                left: AppSpacing.mapSearchOverlayHorizontal,
                right: AppSpacing.mapSearchOverlayHorizontal,
                top: AppSpacing.sm,
                child: AppMapSearchCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'If the location isn’t accurate, tap the map or drag the '
                      'pin to the exact spot, then confirm.',
                      style: AppTypography.caption.copyWith(height: 1.45),
                    ),
                  ),
                ),
              ),
            if (_phase == _LocationPhase.search && _picked != null)
              Positioned(
                left: AppSpacing.mapSearchOverlayHorizontal,
                right: AppSpacing.mapSearchOverlayHorizontal,
                bottom: bottomInset,
                child: AppPrimaryButton(
                  label: 'Use this location',
                  onPressed: _useSearchResultLocation,
                ),
              ),
            if (_phase == _LocationPhase.adjustPin)
              Positioned(
                left: AppSpacing.mapSearchOverlayHorizontal,
                right: AppSpacing.mapSearchOverlayHorizontal,
                bottom: bottomInset,
                child: AppPrimaryButton(
                  label: 'Looks good',
                  icon: Icons.thumb_up_rounded,
                  onPressed: _goToPhotoStep,
                  applyTitleCase: false,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
