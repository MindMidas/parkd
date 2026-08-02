import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../manage_listings/edit/upload_listing_photo_screen.dart';
import '../../../../../core/map/map_constants.dart';
import '../../../../../core/map/map_geo.dart';
import '../../../../../core/map/map_listing_camera.dart';
import '../../../../../core/map/map_user_location.dart';
import '../../../../../core/map/nominatim_geocoding.dart';
import '../../../../../core/models/listing.dart';
import '../../../../../core/models/search_result.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../map/presentation/map.dart';
import '../create_listing_draft.dart';
import '../create_listing_flow_constants.dart';

enum _LocationPhase { search, adjustPin, sharing }

// pin + general/specific sharing, then continue
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
  ListingLocationSharing _locationSharing = ListingLocationSharing.general;
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
      unawaited(() async {
        // Stop the GPS puck from competing with the address pin.
        await configureMapLocationPuck(m, enabled: false);
        await flyMapToLatLonWithoutPadding(
          m,
          latitude: result.lat,
          longitude: result.lon,
          zoom: 15.5,
        );
      }());
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

  void _confirmPin() {
    if (_picked == null || _pinLat == null || _pinLon == null) return;
    setState(() => _phase = _LocationPhase.sharing);
    final m = _map;
    if (m != null) {
      unawaited(
        flyMapToLatLonWithoutPadding(
          m,
          latitude: _pinLat!,
          longitude: _pinLon!,
          zoom: _locationSharing.isGeneral ? 15.5 : 17.5,
        ),
      );
    }
  }

  void _setSharing(ListingLocationSharing sharing) {
    setState(() => _locationSharing = sharing);
    final m = _map;
    final lat = _pinLat;
    final lon = _pinLon;
    if (m == null || lat == null || lon == null) return;
    unawaited(
      flyMapToLatLonWithoutPadding(
        m,
        latitude: lat,
        longitude: lon,
        zoom: sharing.isGeneral ? 15.5 : 17.5,
      ),
    );
  }

  void _goToPhotoStep() {
    final r = _picked;
    final lat = _pinLat;
    final lon = _pinLon;
    if (r == null || lat == null || lon == null) return;

    final draft = CreateListingDraft()
      ..picked = r
      ..pinLat = lat
      ..pinLon = lon
      ..locationSharing = _locationSharing;

    Navigator.of(context).push(
      AppPageRoute<void>(
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
    if (_phase == _LocationPhase.sharing) {
      setState(() => _phase = _LocationPhase.adjustPin);
      return;
    }
    if (_phase == _LocationPhase.adjustPin) {
      setState(() => _phase = _LocationPhase.search);
      return;
    }
    Navigator.of(context).maybePop();
  }

  ({double latitude, double longitude})? get _guestPreviewHalo {
    if (_phase != _LocationPhase.sharing) return null;
    if (!_locationSharing.isGeneral) return null;
    final lat = _pinLat;
    final lon = _pinLon;
    if (lat == null || lon == null) return null;
    // Stable preview offset (create flow has no listing id yet).
    return obfuscateApproximateMapCenter(
      listingId: 'create-preview',
      latitude: lat,
      longitude: lon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + AppSpacing.lg;
    final fabBottom = bottomInset + AppSpacing.primaryButtonMinHeight + 12;
    final compassMb =
        fabBottom + kParkdMapRecenterFabSize + kParkdMapCompassGapAboveFab;
    final showSearch = _phase == _LocationPhase.search;
    final guestHalo = _guestPreviewHalo;

    return PopScope(
      canPop: _phase == _LocationPhase.search,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onStepBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppStepTopBar(
          title: _phase == _LocationPhase.sharing
              ? 'Location sharing'
              : 'Set parking spot address',
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
                draftPin:
                    _pinLat != null &&
                        _pinLon != null &&
                        !(
                          _phase == _LocationPhase.sharing &&
                          _locationSharing.isGeneral
                        )
                    ? (lat: _pinLat!, lon: _pinLon!)
                    : null,
                approximatePrivacyHalo: guestHalo,
                onMapReady: _onMapReady,
                onMapSurfaceTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                onMapContentTap: _phase == _LocationPhase.adjustPin
                    ? _onMapTapAdjustPin
                    : null,
                onRecenterPressed: () async {
                  final m = _map;
                  if (m == null) return;
                  // During pin adjust / sharing, recenter on the listing pin —
                  // not GPS (that felt like the pin “sent you home”).
                  final lat = _pinLat;
                  final lon = _pinLon;
                  if (_phase != _LocationPhase.search &&
                      lat != null &&
                      lon != null) {
                    await flyMapToLatLonWithoutPadding(
                      m,
                      latitude: lat,
                      longitude: lon,
                      zoom: _phase == _LocationPhase.adjustPin
                          ? 18
                          : (_locationSharing.isGeneral ? 15.5 : 17.5),
                    );
                    return;
                  }
                  await tryCenterMapOnUserLocation(m);
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
            if (_phase == _LocationPhase.sharing)
              Positioned(
                left: AppSpacing.mapSearchOverlayHorizontal,
                right: AppSpacing.mapSearchOverlayHorizontal,
                top: AppSpacing.sm,
                child: AppMapSearchCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'What should drivers see before they book?',
                          style: AppTypography.bodyStrong,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Street address is always private until a reservation '
                          'is confirmed.',
                          style: AppTypography.caption.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppSegmentControl<ListingLocationSharing>(
                          options: const [
                            AppSegmentOption(
                              value: ListingLocationSharing.general,
                              label: 'General',
                              icon: Icons.blur_circular_rounded,
                            ),
                            AppSegmentOption(
                              value: ListingLocationSharing.specific,
                              label: 'Specific',
                              icon: Icons.location_on_rounded,
                            ),
                          ],
                          selected: _locationSharing,
                          onChanged: _setSharing,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _locationSharing == ListingLocationSharing.general
                              ? 'Show only an approximate area (~2–3 short blocks).'
                              : 'Show a pin on the map. Still hides the street '
                                  'address until booking.',
                          style: AppTypography.caption.copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_phase == _LocationPhase.search && _picked != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppStickyFooter(
                  child: AppPrimaryButton(
                    label: 'Use this location',
                    onPressed: _useSearchResultLocation,
                  ),
                ),
              ),
            if (_phase == _LocationPhase.adjustPin)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppStickyFooter(
                  child: AppPrimaryButton(
                    label: 'Continue',
                    onPressed: _confirmPin,
                  ),
                ),
              ),
            if (_phase == _LocationPhase.sharing)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppStickyFooter(
                  child: AppPrimaryButton(
                    label: 'Continue',
                    onPressed: _goToPhotoStep,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
