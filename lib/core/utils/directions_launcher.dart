import 'package:url_launcher/url_launcher.dart';

Uri drivingDirectionsUri(String destination) =>
    Uri.https('www.google.com', '/maps/dir/', <String, String>{
      'api': '1',
      'destination': destination.trim(),
      'travelmode': 'driving',
    });

/// Opens a platform-neutral HTTPS directions link.
///
/// Android/iOS can hand this URL to an installed maps app; browsers retain a
/// fully functional web fallback without relying on platform-specific schemes.
Future<bool> launchDrivingDirections(String destination) async {
  try {
    return await launchUrl(
      drivingDirectionsUri(destination),
      mode: LaunchMode.externalApplication,
    );
  } on Exception {
    return false;
  }
}
