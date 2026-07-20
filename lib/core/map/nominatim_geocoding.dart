import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/search_result.dart';
import 'map_constants.dart';

/// Guelph default center — same as [MapConstants].
const double kDefaultMapLat = MapConstants.defaultLatitude;
const double kDefaultMapLon = MapConstants.defaultLongitude;
const double kDefaultMapZoom = MapConstants.defaultZoom;

/// Searches through the Parkd Edge proxy.
///
/// Browsers and mobile clients never call Nominatim or Photon directly. The
/// proxy supplies the required contact identity, normalizes responses, applies
/// a per-user/IP rate limit, and can fail over between providers.
Future<List<SearchResult>> searchAddressesForParkd(String query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  if (q.length > 160) {
    throw const GeocodingException('Search text is too long.');
  }

  try {
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
      final displayName = row['display_name'];
      final latitude = _coordinate(row['lat']);
      final longitude = _coordinate(row['lon']);
      if (displayName is! String ||
          displayName.trim().isEmpty ||
          latitude == null ||
          longitude == null ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        continue;
      }
      results.add(
        SearchResult(
          displayName: displayName.trim(),
          lat: latitude,
          lon: longitude,
          road: _string(row['road']),
          houseNumber: _string(row['house_number']),
          city: _string(row['city']),
          state: _string(row['state']),
          postcode: _string(row['postcode']),
        ),
      );
    }
    return _rankResultsForQuery(_dedupeSearchResults(results), q);
  } on FunctionException catch (error) {
    throw GeocodingException(_errorMessage(error.details));
  } on GeocodingException {
    rethrow;
  } catch (_) {
    throw const GeocodingException(
      'Address search is temporarily unavailable. Try again shortly.',
    );
  }
}

/// Backwards-compatible name used by map call sites.
Future<List<SearchResult>> nominatimSearchAddresses(String query) =>
    searchAddressesForParkd(query);

/// Create-listing step: geocoded addresses/places only.
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
