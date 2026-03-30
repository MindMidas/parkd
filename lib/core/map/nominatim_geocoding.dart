import 'dart:convert';

import 'package:http/http.dart' as http;

import 'map_constants.dart';
import '../models/search_result.dart';

// Nominatim/Photon needs userAgent
const _userAgent = 'Parkd/1.0 (student project; +https://github.com/parkd-app)';

// address search: Photon + Nominatim (map tiles stay Mapbox)
Future<List<SearchResult>> searchAddressesForParkd(String query) async {
  final q = query.trim();
  if (q.isEmpty) return [];

  final looksLikeStreetAddress = RegExp(r'\d').hasMatch(q);

  if (looksLikeStreetAddress) {
    List<SearchResult> nom = [];
    List<SearchResult> photon = [];
    try {
      nom = await _nominatimSearchAddresses(q);
    } catch (_) {}
    try {
      photon = await _photonSearchAddresses(q);
    } catch (_) {}
    final merged = _dedupeSearchResults([...nom, ...photon]);
    if (merged.isEmpty) return [];
    return _rankResultsForQuery(merged, q);
  }

  try {
    final photon = await _photonSearchAddresses(q);
    if (photon.isNotEmpty) {
      return _rankResultsForQuery(_dedupeSearchResults(photon), q);
    }
  } catch (_) {}

  try {
    final nom = await _nominatimSearchAddresses(q);
    return _rankResultsForQuery(_dedupeSearchResults(nom), q);
  } catch (_) {
    return [];
  }
}

// Nominatim + photon often return same place with different displayName strings
// so dedupe by rounded coordinates and keep clearest label
List<SearchResult> _dedupeSearchResults(List<SearchResult> results) {
  if (results.isEmpty) return results;
  final sorted = [...results]
    ..sort(
      (a, b) => _duplicateQualityScore(b).compareTo(_duplicateQualityScore(a)),
    );
  final seen = <String>{};
  final out = <SearchResult>[];
  for (final r in sorted) {
    final key = '${r.lat.toStringAsFixed(5)}_${r.lon.toStringAsFixed(5)}';
    if (seen.contains(key)) continue;
    seen.add(key);
    out.add(r);
    if (out.length >= 18) break;
  }
  return out;
}

// prefer full street lines over jus house nums when coords collide
int _duplicateQualityScore(SearchResult r) {
  var s = 0;
  final hn = r.houseNumber.trim();
  final road = r.road.trim();
  if (hn.isNotEmpty && road.isNotEmpty) s += 500;
  if (hn.isNotEmpty) s += 40;
  if (road.isNotEmpty) s += 40;

  final (title, _) = r.listTitleAndSubtitle;
  final t = title.trim();
  if (RegExp(r'^\d+$').hasMatch(t)) s -= 400;
  if (RegExp(r'^\d+\s+\S').hasMatch(t)) s += 200;

  s += (r.displayName.length ~/ 6).clamp(0, 35);
  return s;
}

// Prefer exact house-num matches and query token overlap
List<SearchResult> _rankResultsForQuery(List<SearchResult> results, String q) {
  if (results.length <= 1) return results;
  final qTrim = q.trim();
  final qLower = qTrim.toLowerCase();
  final tokens = qLower
      .split(RegExp(r'\s+'))
      .where((s) => s.length >= 2)
      .toList();
  final wantedHouse = RegExp(r'^(\d+)\b').firstMatch(qTrim)?.group(1);

  final scored = results.map((r) {
    var score = 0;
    final dn = r.displayName.toLowerCase();
    final hn = r.houseNumber.trim();
    if (wantedHouse != null && hn.isNotEmpty) {
      if (hn == wantedHouse) {
        score += 200;
      } else if (hn.startsWith(wantedHouse)) {
        score += 80;
      }
    }
    if (dn.contains(qLower)) score += 40;
    for (final t in tokens) {
      if (dn.contains(t)) score += 6;
    }
    return MapEntry(score, r);
  }).toList()..sort((a, b) => b.key.compareTo(a.key));

  return scored.map((e) => e.value).toList();
}

// Photon (komoot)

Future<List<SearchResult>> _photonSearchAddresses(String query) async {
  final uri = Uri.https('photon.komoot.io', '/api', {
    'q': query,
    'limit': '12',
    'lang': 'en',
    // bias toward Guelph/Wellington County area (minLon, minLat, maxLon, maxLat)
    'bbox': '-80.75,43.35,-79.95,43.75',
    // proximity bias (Photon), city center improves street-level rank
    'lat': '${MapConstants.defaultLatitude}',
    'lon': '${MapConstants.defaultLongitude}',
  });

  final response = await http.get(
    uri,
    headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
  );

  if (response.statusCode != 200) return [];

  final decoded = json.decode(response.body);
  if (decoded is! Map) return [];
  final root = Map<String, dynamic>.from(decoded);
  final features = root['features'];
  if (features is! List<dynamic>) return [];

  final out = <SearchResult>[];
  for (final raw in features) {
    if (raw is! Map) continue;
    try {
      final f = Map<String, dynamic>.from(raw);
      final geom = f['geometry'];
      if (geom is! Map) continue;
      final geomMap = Map<String, dynamic>.from(geom);
      final coords = geomMap['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();

      final props = f['properties'];
      final p = props is Map
          ? Map<String, dynamic>.from(props)
          : <String, dynamic>{};

      final name = p['name'] as String? ?? '';
      final street = p['street'] as String? ?? '';
      final housenumber = p['housenumber'] as String? ?? '';
      final city =
          p['city'] as String? ??
          p['town'] as String? ??
          p['district'] as String? ??
          '';
      final state = p['state'] as String? ?? '';
      final postcode = p['postcode'] as String? ?? '';
      final country = p['country'] as String? ?? '';

      final line1 = [
        if (housenumber.isNotEmpty) housenumber,
        if (street.isNotEmpty) street,
      ].join(' ').trim();

      final displayName = [
        if (name.isNotEmpty) name,
        if (line1.isNotEmpty) line1,
        if (city.isNotEmpty) city,
        if (state.isNotEmpty) state,
        if (postcode.isNotEmpty) postcode,
        if (country.isNotEmpty) country,
      ].where((s) => s.isNotEmpty).join(', ');

      if (displayName.isEmpty) continue;

      out.add(
        SearchResult(
          displayName: displayName,
          lat: lat,
          lon: lon,
          road: street,
          houseNumber: housenumber,
          city: city,
          state: state,
          postcode: postcode,
        ),
      );
    } catch (_) {
      continue;
    }
  }
  return out;
}

Future<List<SearchResult>> _nominatimSearchAddresses(String query) async {
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': query,
    'format': 'json',
    'addressdetails': '1',
    'limit': '15',
    'countrycodes': 'ca',
    'viewbox': '-80.75,43.75,-79.95,43.35',
    'bounded': '0',
  });

  final response = await http.get(
    uri,
    headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
  );

  if (response.statusCode != 200) return [];

  final decoded = json.decode(response.body);
  if (decoded is Map) return [];
  if (decoded is! List<dynamic>) return [];

  final out = <SearchResult>[];
  for (final raw in decoded) {
    if (raw is! Map) continue;
    try {
      final item = Map<String, dynamic>.from(raw);
      final addr = item['address'];
      final addrMap = addr is Map
          ? Map<String, dynamic>.from(addr)
          : <String, dynamic>{};

      final name = item['display_name'];
      if (name is! String || name.isEmpty) continue;

      out.add(
        SearchResult(
          displayName: name,
          lat: _parseCoord(item['lat']),
          lon: _parseCoord(item['lon']),
          road: addrMap['road'] as String? ?? '',
          houseNumber: addrMap['house_number'] as String? ?? '',
          city:
              addrMap['city'] as String? ??
              addrMap['town'] as String? ??
              addrMap['village'] as String? ??
              addrMap['hamlet'] as String? ??
              '',
          state: addrMap['state'] as String? ?? '',
          postcode: addrMap['postcode'] as String? ?? '',
        ),
      );
    } catch (_) {
      continue;
    }
  }
  return out;
}

double _parseCoord(dynamic v) {
  if (v == null) throw FormatException('missing coordinate');
  if (v is num) return v.toDouble();
  if (v is String) return double.parse(v);
  throw FormatException('invalid coordinate');
}
