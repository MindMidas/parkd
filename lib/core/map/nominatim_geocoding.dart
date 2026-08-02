import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_environment.dart';
import '../models/search_result.dart';
import 'map_constants.dart';

// Guelph default center — same as MapConstants.
const double kDefaultMapLat = MapConstants.defaultLatitude;
const double kDefaultMapLon = MapConstants.defaultLongitude;
const double kDefaultMapZoom = MapConstants.defaultZoom;

// Searches for addresses near the Parkd map area.
Future<List<SearchResult>> searchAddressesForParkd(String query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  if (q.length > 160) {
    throw const GeocodingException('Search text is too long.');
  }

  try {
    final proxied = await _searchViaEdgeProxy(q);
    if (proxied.isNotEmpty) {
      return _rankResultsForQuery(_dedupeSearchResults(proxied), q);
    }
  } catch (_) {
    // Fall through to Mapbox.
  }

  final mapbox = await _searchViaMapbox(q);
  if (mapbox.isNotEmpty) {
    return _rankResultsForQuery(_dedupeSearchResults(mapbox), q);
  }

  throw const GeocodingException(
    'Address search is temporarily unavailable. Try again shortly.',
  );
}

Future<List<SearchResult>> _searchViaEdgeProxy(String q) async {
  final response = await Supabase.instance.client.functions.invoke(
    'geocode-search',
    body: {'q': q, 'limit': 8},
  );
  if (response.status != 200) {
    throw GeocodingException(_errorMessage(response.data));
  }
  final data = response.data;
  if (data is! Map || data['results'] is! List) {
    throw const GeocodingException(
      'The address service returned an invalid response.',
    );
  }

  final results = <SearchResult>[];
  for (final value in data['results'] as List) {
    if (value is! Map) continue;
    final row = Map<String, dynamic>.from(value);
    final parsed = _resultFromRow(
      displayName: row['display_name'],
      lat: row['lat'],
      lon: row['lon'],
      road: row['road'],
      houseNumber: row['house_number'],
      city: row['city'],
      state: row['state'],
      postcode: row['postcode'],
    );
    if (parsed != null) results.add(parsed);
  }
  return results;
}

Future<List<SearchResult>> _searchViaMapbox(String q) async {
  final token = AppEnvironment.optional(AppEnvironmentKey.mapboxAccessToken);
  if (token == null || token.isEmpty) {
    throw const GeocodingException(
      'Mapbox is not configured for address search.',
    );
  }

  final uri = Uri.https(
    'api.mapbox.com',
    '/geocoding/v5/mapbox.places/${Uri.encodeComponent(q)}.json',
    {
      'access_token': token,
      'autocomplete': 'true',
      'country': 'ca',
      'limit': '8',
      'language': 'en',
      'proximity':
          '${MapConstants.defaultLongitude},${MapConstants.defaultLatitude}',
      'types': 'address,place,locality,neighborhood,poi',
    },
  );

  final response = await http.get(uri).timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) {
    throw GeocodingException(
      'Mapbox address search failed (${response.statusCode}).',
    );
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map || decoded['features'] is! List) {
    return const [];
  }

  final results = <SearchResult>[];
  for (final value in decoded['features'] as List) {
    if (value is! Map) continue;
    final feature = Map<String, dynamic>.from(value);
    final center = feature['center'];
    if (center is! List || center.length < 2) continue;
    final lon = _coordinate(center[0]);
    final lat = _coordinate(center[1]);
    final placeName = feature['place_name'];
    if (lat == null || lon == null || placeName is! String) continue;

    String road = '';
    String houseNumber = '';
    String city = '';
    String state = '';
    String postcode = '';
    final text = feature['text'];
    final address = feature['address'];
    if (text is String) road = text;
    if (address is String) houseNumber = address;

    final context = feature['context'];
    if (context is List) {
      for (final item in context) {
        if (item is! Map) continue;
        final id = item['id'];
        final name = item['text'];
        if (id is! String || name is! String) continue;
        if (id.startsWith('place.') || id.startsWith('locality.')) {
          city = name;
        } else if (id.startsWith('region.')) {
          state = name;
        } else if (id.startsWith('postcode.')) {
          postcode = name;
        }
      }
    }

    final parsed = _resultFromRow(
      displayName: placeName,
      lat: lat,
      lon: lon,
      road: road,
      houseNumber: houseNumber,
      city: city,
      state: state,
      postcode: postcode,
    );
    if (parsed != null) results.add(parsed);
  }
  return results;
}

SearchResult? _resultFromRow({
  required Object? displayName,
  required Object? lat,
  required Object? lon,
  Object? road,
  Object? houseNumber,
  Object? city,
  Object? state,
  Object? postcode,
}) {
  final latitude = _coordinate(lat);
  final longitude = _coordinate(lon);
  if (displayName is! String ||
      displayName.trim().isEmpty ||
      latitude == null ||
      longitude == null ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    return null;
  }
  return SearchResult(
    displayName: displayName.trim(),
    lat: latitude,
    lon: longitude,
    road: _string(road),
    houseNumber: _string(houseNumber),
    city: _string(city),
    state: _string(state),
    postcode: _string(postcode),
  );
}

Future<List<SearchResult>> searchAddressesForCreateListing(String query) =>
    searchAddressesForParkd(query);

List<SearchResult> _dedupeSearchResults(List<SearchResult> results) {
  if (results.isEmpty) return results;
  final sorted = [...results]
    ..sort(
      (a, b) => _duplicateQualityScore(b).compareTo(_duplicateQualityScore(a)),
    );
  final seen = <String>{};
  final output = <SearchResult>[];
  for (final result in sorted) {
    final key =
        '${result.lat.toStringAsFixed(5)}_${result.lon.toStringAsFixed(5)}';
    if (!seen.add(key)) continue;
    output.add(result);
    if (output.length >= 8) break;
  }
  return output;
}

int _duplicateQualityScore(SearchResult result) {
  var score = 0;
  final houseNumber = result.houseNumber.trim();
  final road = result.road.trim();
  if (houseNumber.isNotEmpty && road.isNotEmpty) score += 500;
  if (houseNumber.isNotEmpty) score += 40;
  if (road.isNotEmpty) score += 40;
  final (title, _) = result.listTitleAndSubtitle;
  if (RegExp(r'^\d+$').hasMatch(title.trim())) score -= 400;
  if (RegExp(r'^\d+\s+\S').hasMatch(title.trim())) score += 200;
  return score + (result.displayName.length ~/ 6).clamp(0, 35);
}

List<SearchResult> _rankResultsForQuery(
  List<SearchResult> results,
  String query,
) {
  if (results.length <= 1) return results;
  final normalizedQuery = query.trim().toLowerCase();
  final tokens = normalizedQuery
      .split(RegExp(r'\s+'))
      .where((token) => token.length >= 2)
      .toList();
  final wantedHouse = RegExp(r'^(\d+)\b').firstMatch(query.trim())?.group(1);

  final scored = results.map((result) {
    var score = 0;
    final displayName = result.displayName.toLowerCase();
    final houseNumber = result.houseNumber.trim();
    if (wantedHouse != null && houseNumber.isNotEmpty) {
      if (houseNumber == wantedHouse) {
        score += 200;
      } else if (houseNumber.startsWith(wantedHouse)) {
        score += 80;
      }
    }
    if (displayName.contains(normalizedQuery)) score += 40;
    for (final token in tokens) {
      if (displayName.contains(token)) score += 6;
    }
    return MapEntry(score, result);
  }).toList()..sort((a, b) => b.key.compareTo(a.key));
  return scored.map((entry) => entry.value).toList(growable: false);
}

double? _coordinate(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _string(Object? value) => value is String ? value.trim() : '';

String _errorMessage(Object? data) {
  if (data is Map) {
    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) return error.trim();
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
  }
  return 'Address search is temporarily unavailable. Try again shortly.';
}

class GeocodingException implements Exception {
  const GeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}
