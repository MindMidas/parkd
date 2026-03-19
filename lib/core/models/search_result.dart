class SearchResult {
  const SearchResult({
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