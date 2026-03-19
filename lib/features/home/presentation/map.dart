import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapView extends StatelessWidget {
  const MapView({
    super.key,
    this.initialCenter = const LatLng(28.6139, 77.2090),
    this.initialZoom = 13.0,
    this.children = const [],
  });

  final LatLng initialCenter;
  final double initialZoom;

  /// Extra FlutterMap children (e.g. MarkerLayer, PolylineLayer).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.parkd.app',
        ),
        ...children,
      ],
    );
  }
}