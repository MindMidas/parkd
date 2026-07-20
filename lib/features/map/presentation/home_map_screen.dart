import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/main_shell_tab_provider.dart';
import '../../../core/map/map_constants.dart';
import '../../../core/map/map_listing_camera.dart';
import '../../../core/map/map_user_location.dart';
import '../../../core/map/mapbox_runtime.dart';
import '../../../core/map/nominatim_geocoding.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/search_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../hosting/presentation/hosting_hub_screen.dart';
import '../../profile/presentation/account/account_tab_screen.dart';
import '../../profile/providers/notifications_providers.dart';
import '../../reservations/presentation/reservations_hub_screen.dart';
import '../providers/map_providers.dart';
import 'listing_detail_from_map_screen.dart';
import 'main_tab.dart';
import 'map.dart';
import 'map_platform_fallback.dart';

// Explore shell — map plus nested hubs, search, and the listing preview sheet
class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({
    super.key,
    this.initialIndex = MainTab.map,
    this.hasTabInRoute = false,
  });

  final int initialIndex;

  final bool hasTabInRoute;

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen>
    with WidgetsBindingObserver {
  static const String _kLocationPromptDismissedKey =
      'parkd_location_prompt_dismissed';
  static const String _kLocationNeverModeSheetDismissedKey =
      'parkd_location_never_mode_sheet_dismissed';

  late int _selectedIndex;
  final GlobalKey<NavigatorState> _reservationsNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _hostingNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _accountNavigatorKey =
      GlobalKey<NavigatorState>();
  final TextEditingController _searchController = TextEditingController();
  MapboxMap? _mapbox;
  SearchResult? _fallbackSearchCenter;
  ({double lat, double lon, double zoom})? _pendingFlyTo;

  /// Last camera the user cared about (GPS center or a search). Used when the
  /// map widget is recreated (e.g. switching tabs)
  ({double lat, double lon, double zoom})? _mapCameraTarget;

  /// Snapshot from [MapboxMap.getCameraState] before listing preview (restore when sheet closes)
  ({double lat, double lon, double zoom, double bearing, double pitch})?
  _cameraBeforeListingPreview;

  bool _isRoughlyDefaultGuelphCamera() {
    final t = _mapCameraTarget;
    if (t == null) return true;
    const lat = MapConstants.defaultLatitude;
    const lon = MapConstants.defaultLongitude;
    return (t.lat - lat).abs() < 0.002 && (t.lon - lon).abs() < 0.002;
  }

  Future<void> _syncLocationPuckWithPermission(MapboxMap map) async {
    final perm = await geo.Geolocator.checkPermission();
    final granted =
        perm == geo.LocationPermission.whileInUse ||
        perm == geo.LocationPermission.always;
    await configureMapLocationPuck(map, enabled: granted);
  }

  void _onMapReady(MapboxMap map) {
    _mapbox = map;
    final pending = _pendingFlyTo;
    if (pending != null) {
      _pendingFlyTo = null;
      unawaited(_flyAndRemember(map, pending.lat, pending.lon, pending.zoom));
      return;
    }
    final saved = _mapCameraTarget;
    if (saved != null) {
      unawaited(_flyAndRemember(map, saved.lat, saved.lon, saved.zoom));
      return;
    }
    unawaited(_centerOnUser(map));
  }

  Future<void> _flyAndRemember(
    MapboxMap map,
    double lat,
    double lon,
    double zoom,
  ) async {
    await flyMapToLatLon(map, latitude: lat, longitude: lon, zoom: zoom);
    if (!mounted) return;
    setState(() {
      _mapCameraTarget = (lat: lat, lon: lon, zoom: zoom);
    });
    await _syncLocationPuckWithPermission(map);
  }

  Future<void> _useDefaultMapViewNoGps(MapboxMap map) async {
    await configureMapLocationPuck(map, enabled: false);
    await flyMapToLatLon(
      map,
      latitude: MapConstants.defaultLatitude,
      longitude: MapConstants.defaultLongitude,
      zoom: MapConstants.defaultZoom,
    );
    if (!mounted) return;
    setState(() {
      _mapCameraTarget = (
        lat: MapConstants.defaultLatitude,
        lon: MapConstants.defaultLongitude,
        zoom: MapConstants.defaultZoom,
      );
    });
  }

  Future<void> _onAppResumedSyncLocation(MapboxMap map) async {
    await _syncLocationPuckWithPermission(map);
    if (!mounted) return;
    final perm = await geo.Geolocator.checkPermission();
    final granted =
        perm == geo.LocationPermission.whileInUse ||
        perm == geo.LocationPermission.always;
    if (!granted || !_isRoughlyDefaultGuelphCamera()) return;
    final serviceOn = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return;
    geo.Position? pos;
    try {
      pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.medium,
        ),
      );
    } catch (_) {
      pos = null;
    }
    if (pos == null || !mounted) return;
    final lat = pos.latitude;
    final lon = pos.longitude;
    await configureMapLocationPuck(map, enabled: true);
    final zoom = MapConstants.defaultZoom;
    await flyMapToLatLon(map, latitude: lat, longitude: lon, zoom: zoom);
    if (!mounted) return;
    setState(() {
      _mapCameraTarget = (lat: lat, lon: lon, zoom: zoom);
    });
  }

  Future<void> _flyMapToUserIfServicesEnabled(MapboxMap map) async {
    await configureMapLocationPuck(map, enabled: true);

    final serviceOn = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      await configureMapLocationPuck(map, enabled: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Turn on Location Services in your device settings to use your position on the map.',
          ),
        ),
      );
      return;
    }

    geo.Position? pos;
    try {
      pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.medium,
        ),
      );
    } catch (_) {
      pos = null;
    }
    if (pos == null || !mounted) return;
    final lat = pos.latitude;
    final lon = pos.longitude;
    final zoom = MapConstants.defaultZoom;
    await flyMapToLatLon(map, latitude: lat, longitude: lon, zoom: zoom);
    if (!mounted) return;
    setState(() {
      _mapCameraTarget = (lat: lat, lon: lon, zoom: zoom);
    });
  }

  Future<void> _centerOnUser(MapboxMap map) async {
    var perm = await geo.Geolocator.checkPermission();

    if (perm == geo.LocationPermission.whileInUse ||
        perm == geo.LocationPermission.always) {
      await _flyMapToUserIfServicesEnabled(map);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_kLocationPromptDismissedKey) ?? false;
    if (dismissed) {
      await _useDefaultMapViewNoGps(map);
      return;
    }
    if (!mounted) return;

    final wantsSystemPrompt =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSectionTitle('Parking near you'),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Allow location while you use the app so we can show '
                    'parking spots near you on the map.',
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppSecondaryButton(
                    label: 'Not now',
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppPrimaryButton(
                    label: 'Continue',
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
    if (!mounted) return;
    if (!wantsSystemPrompt) {
      await prefs.setBool(_kLocationPromptDismissedKey, true);
      await _useDefaultMapViewNoGps(map);
      return;
    }

    perm = await geo.Geolocator.requestPermission();
    if (!mounted) return;
    if (perm == geo.LocationPermission.whileInUse ||
        perm == geo.LocationPermission.always) {
      await _flyMapToUserIfServicesEnabled(map);
      return;
    }

    await _useDefaultMapViewNoGps(map);
    if (!mounted) return;
    if (perm == geo.LocationPermission.deniedForever) {
      final foreverSheetDismissed =
          prefs.getBool(_kLocationNeverModeSheetDismissedKey) ?? false;
      if (foreverSheetDismissed) return;
      final openSettings =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => Dialog(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSectionTitle('Location is off for Parkd'),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Open Settings to allow "While Using the App".',
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppSecondaryButton(
                      label: 'Not now',
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppPrimaryButton(
                      label: 'Open Settings',
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              ),
            ),
          ) ??
          false;
      if (!mounted) return;
      if (openSettings) {
        await openAppLocationSettings();
      } else {
        await prefs.setBool(_kLocationNeverModeSheetDismissedKey, true);
      }
    }
  }

  void _syncTabRoute() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    try {
      final state = GoRouterState.of(context);
      if (state.matchedLocation != '/home') return;
      final current = state.uri.queryParameters['tab'];
      final next = MainTab.toQuery(_selectedIndex);
      if (current == next) return;
      router.go('/home?tab=$next');
    } on GoError {
      // Not under a GoRouter page (e.g. [HomeMapScreen] pushed with [Navigator] only)
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final resolved = widget.hasTabInRoute
        ? widget.initialIndex.clamp(0, MainTab.count - 1)
        : ref.read(mainShellTabIndexProvider).clamp(0, MainTab.count - 1);
    _selectedIndex = resolved;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(mainShellTabIndexProvider.notifier).setTab(_selectedIndex);
      _syncTabRoute();
    });
  }

  @override
  void didUpdateWidget(HomeMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasTabInRoute && oldWidget.initialIndex != widget.initialIndex) {
      final next = widget.initialIndex.clamp(0, MainTab.count - 1);
      final prevIndex = _selectedIndex;
      if (next == MainTab.map && prevIndex != MainTab.map) {
        ref.invalidate(mapPublishedListingsProvider);
      }
      setState(() => _selectedIndex = next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(mainShellTabIndexProvider.notifier).setTab(next);
        _syncTabRoute();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    if (_selectedIndex != MainTab.map) return;
    final map = _mapbox;
    if (map == null) return;
    unawaited(_onAppResumedSyncLocation(map));
  }

  GlobalKey<NavigatorState>? _navigatorKeyForTab(int tab) {
    switch (tab) {
      case MainTab.reservations:
        return _reservationsNavigatorKey;
      case MainTab.hosting:
        return _hostingNavigatorKey;
      case MainTab.account:
        return _accountNavigatorKey;
      default:
        return null;
    }
  }

  void _onSystemBack() {
    if (_selectedIndex == MainTab.map) {
      SystemNavigator.pop();
      return;
    }
    final nav = _navigatorKeyForTab(_selectedIndex)?.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }
    setState(() => _selectedIndex = MainTab.map);
    ref.read(mainShellTabIndexProvider.notifier).setTab(MainTab.map);
    ref.invalidate(mapPublishedListingsProvider);
  }

  Widget _nestedTabNavigator({
    required GlobalKey<NavigatorState> navigatorKey,
    required String routeName,
    required Widget root,
  }) {
    return Navigator(
      key: navigatorKey,
      onGenerateInitialRoutes: (navigator, initialRoute) {
        return [
          MaterialPageRoute<void>(
            settings: RouteSettings(name: routeName),
            builder: (_) => root,
          ),
        ];
      },
    );
  }

  /// Map tab: map + search. Kept in an [IndexedStack] (see [_buildTabBody]) so the
  /// Mapbox platform view is not disposed when switching bottom tabs — iOS can
  /// throw `recreating_view` if the native view is recreated while still tearing down
  Widget _buildMapTab() {
    final listingsAsync = ref.watch(mapPublishedListingsProvider);
    final listings = listingsAsync.maybeWhen(
      data: (data) => data,
      orElse: () => <Listing>[],
    );
    if (!supportsNativeMapboxMaps) {
      final searchCenter = _fallbackSearchCenter;
      final orderedListings = searchCenter == null
          ? listings
          : sortListingsNear(
              listings: listings,
              latitude: searchCenter.lat,
              longitude: searchCenter.lon,
            );
      return MapPlatformFallback(
        searchPanel: AppMapAddressSearchPanel(
          controller: _searchController,
          hintText: 'Search city or address…',
          showFilterButton: true,
          onFilterTap: _showMapFilterSheet,
          searchFn: nominatimSearchAddresses,
          onResultSelected: _onResultTapped,
        ),
        listings: orderedListings,
        isLoading: listingsAsync.isLoading,
        hasError: listingsAsync.hasError,
        selectedAreaLabel: searchCenter?.displayName,
        onRetry: () => ref.invalidate(mapPublishedListingsProvider),
        onListingTap: (listing) {
          unawaited(_openListingPreview(listing));
        },
      );
    }

    final topPad = MediaQuery.paddingOf(context).top;
    final fabBottom =
        kParkdMapRecenterFabBottomOffset + MediaQuery.paddingOf(context).bottom;
    final compassMb =
        fabBottom + kParkdMapRecenterFabSize + kParkdMapCompassGapAboveFab;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: MapView(
            listings: listings,
            onMapReady: _onMapReady,
            onMapSurfaceTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            onListingTap: (listing) {
              unawaited(_openListingPreview(listing));
            },
            onRecenterPressed: _onRecenterMapPressed,
            mapRecenterFabBottomOffset: fabBottom,
            compassBottomMargin: compassMb,
          ),
        ),
        Positioned(
          left: AppSpacing.mapSearchOverlayHorizontal,
          right: AppSpacing.mapSearchOverlayHorizontal,
          top: topPad + AppSpacing.sm,
          child: AppMapAddressSearchPanel(
            controller: _searchController,
            hintText: 'Search city or address…',
            showFilterButton: true,
            onFilterTap: _showMapFilterSheet,
            searchFn: nominatimSearchAddresses,
            onResultSelected: _onResultTapped,
          ),
        ),
        if (listingsAsync.isLoading)
          Positioned(
            left: AppSpacing.mapSearchOverlayHorizontal,
            right: AppSpacing.mapSearchOverlayHorizontal,
            top: topPad + 76,
            child: const LinearProgressIndicator(minHeight: 2),
          ),
        if (listingsAsync.hasError)
          Positioned(
            left: AppSpacing.mapSearchOverlayHorizontal,
            right: AppSpacing.mapSearchOverlayHorizontal,
            bottom: fabBottom + 64,
            child: Material(
              color: AppColors.surface,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Parking spots could not be loaded.',
                        style: AppTypography.bodySecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(mapPublishedListingsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTabBody() {
    return IndexedStack(
      index: _selectedIndex,
      sizing: StackFit.expand,
      children: [
        _buildMapTab(),
        _nestedTabNavigator(
          navigatorKey: _reservationsNavigatorKey,
          routeName: 'reservations_hub',
          root: const ReservationsHubScreen(),
        ),
        _nestedTabNavigator(
          navigatorKey: _hostingNavigatorKey,
          routeName: 'hosting_hub',
          root: const HostingHubScreen(),
        ),
        _nestedTabNavigator(
          navigatorKey: _accountNavigatorKey,
          routeName: 'account_tab',
          root: const AccountTabScreen(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  void _showMapFilterSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final f = ref.watch(mapFiltersProvider);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSectionTitle('Map filters'),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Max price per hour: \$${f.maxPricePerHour.toStringAsFixed(0)}',
                      style: AppTypography.body,
                    ),
                    Slider(
                      value: f.maxPricePerHour.clamp(5, 50),
                      min: 5,
                      max: 50,
                      divisions: 9,
                      label: '\$${f.maxPricePerHour.toStringAsFixed(0)}',
                      onChanged: (v) {
                        ref
                            .read(mapFiltersProvider.notifier)
                            .setMaxPricePerHour(v);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Guelph listings only'),
                      subtitle: Text(
                        'When off, shows any published listing in the database.',
                        style: AppTypography.bodyMuted,
                      ),
                      value: f.guelphOnly,
                      onChanged: (v) {
                        ref.read(mapFiltersProvider.notifier).setGuelphOnly(v);
                      },
                    ),
                    AppPrimaryButton(
                      label: 'Done',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openListingPreview(Listing listing) async {
    final map = _mapbox;
    const zoom = 17.0;

    if (map != null) {
      try {
        final state = await map.getCameraState();
        final c = state.center.coordinates;
        _cameraBeforeListingPreview = (
          lat: c.lat.toDouble(),
          lon: c.lng.toDouble(),
          zoom: state.zoom,
          bearing: state.bearing,
          pitch: state.pitch,
        );
      } catch (_) {
        final t = _mapCameraTarget;
        _cameraBeforeListingPreview = t == null
            ? null
            : (lat: t.lat, lon: t.lon, zoom: t.zoom, bearing: 0, pitch: 0);
      }
    } else {
      final t = _mapCameraTarget;
      _cameraBeforeListingPreview = t == null
          ? null
          : (lat: t.lat, lon: t.lon, zoom: t.zoom, bearing: 0, pitch: 0);
    }

    if (!mounted) return;

    if (map != null) {
      final mq = MediaQuery.of(context);
      final h = mq.size.height;
      const previewFraction = 0.70;
      // Center the pin in the visible band: below the floating search card and above
      // the 70% sheet (must match Stack + ListingDetailFromMapSheet heights)
      // Top: Positioned(top: safe + sm) + Material vertical padding + search row + nudge
      // so the target sits lower in the gap (Mapbox centers in the padded inset)
      final topPad =
          mq.padding.top +
          AppSpacing.sm +
          AppSpacing.xs * 2 +
          64 +
          AppSpacing.lg +
          AppSpacing.lg;
      // Bottom: sheet height from physical bottom — do not add safe-area padding here
      // (the sheet fills into the home indicator; extra bottom inset skews center upward)
      final bottomPad = h * previewFraction;
      await flyMapToListingPreview(
        map,
        latitude: listing.latitude,
        longitude: listing.longitude,
        zoom: zoom,
        topPadding: topPad,
        bottomPadding: bottomPad,
      );
      if (!mounted) return;
      setState(() {
        _mapCameraTarget = (
          lat: listing.latitude,
          lon: listing.longitude,
          zoom: zoom,
        );
      });
      await _syncLocationPuckWithPermission(map);
    }

    if (!mounted) return;
    final sheetResult = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: false,
      builder: (ctx) => ListingDetailFromMapSheet(listing: listing),
    );

    if (!mounted) return;
    if (sheetResult == kListingDetailSheetResultFull) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => ListingDetailFromMapScreen(listing: listing),
        ),
      );
    }

    final m = _mapbox;
    final prev = _cameraBeforeListingPreview;
    _cameraBeforeListingPreview = null;
    if (m != null && prev != null && mounted) {
      await flyMapToLatLonWithoutPadding(
        m,
        latitude: prev.lat,
        longitude: prev.lon,
        zoom: prev.zoom,
        bearing: prev.bearing,
        pitch: prev.pitch,
      );
      if (!mounted) return;
      setState(() {
        _mapCameraTarget = (lat: prev.lat, lon: prev.lon, zoom: prev.zoom);
      });
      await _syncLocationPuckWithPermission(m);
    }
  }

  Future<void> _onRecenterMapPressed() async {
    final map = _mapbox;
    if (map == null) return;
    await tryCenterMapOnUserLocation(map);
    await _syncLocationPuckWithPermission(map);
    try {
      final state = await map.getCameraState();
      final c = state.center.coordinates;
      if (!mounted) return;
      setState(() {
        _mapCameraTarget = (
          lat: c.lat.toDouble(),
          lon: c.lng.toDouble(),
          zoom: state.zoom,
        );
      });
    } catch (_) {}
  }

  void _onResultTapped(SearchResult result) {
    if (!supportsNativeMapboxMaps) {
      setState(() => _fallbackSearchCenter = result);
      return;
    }
    // Closer than [MapConstants.defaultZoom] so a chosen place feels “zoomed in”
    const zoom = 15.5;
    final map = _mapbox;
    if (map != null) {
      unawaited(_flyAndRemember(map, result.lat, result.lon, zoom));
    } else {
      _pendingFlyTo = (lat: result.lat, lon: result.lon, zoom: zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationCounts = ref.watch(myNotificationHubCountsProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onSystemBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: _buildTabBody(),
        bottomNavigationBar: AppBottomNav(
          selectedIndex: _selectedIndex,
          reservationsBadgeCount: notificationCounts.reservations,
          hostingBadgeCount: notificationCounts.hosting,
          accountBadgeCount: notificationCounts.account,
          onDestinationSelected: (index) {
            final prevIndex = _selectedIndex;
            setState(() {
              _selectedIndex = index;
              if (index == MainTab.map) {
                _searchController.clear();
              }
            });
            if (index == MainTab.map && prevIndex != MainTab.map) {
              ref.invalidate(mapPublishedListingsProvider);
            }
            ref.read(mainShellTabIndexProvider.notifier).setTab(index);
            _syncTabRoute();
          },
        ),
      ),
    );
  }
}
