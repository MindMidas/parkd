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

  // First comma-separated segment vs remainder (title / subtitle in search lists)
  (String title, String subtitle) get listTitleAndSubtitle {
    final t = displayName.trim();
    if (t.isEmpty) return ('', '');
    final i = t.indexOf(',');
    if (i < 0) return (t, '');
    final head = t.substring(0, i).trim();
    final tail = t.substring(i + 1).trim();
    if (head.isEmpty) return (tail, '');
    return (head, tail);
  }
}
