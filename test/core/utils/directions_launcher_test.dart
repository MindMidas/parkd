import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/utils/directions_launcher.dart';

void main() {
  test('driving directions use a portable HTTPS URL with encoded address', () {
    final uri = drivingDirectionsUri('15 Example Street, Toronto, ON');

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(
      uri.queryParameters['destination'],
      '15 Example Street, Toronto, ON',
    );
    expect(uri.queryParameters['travelmode'], 'driving');
  });
}
