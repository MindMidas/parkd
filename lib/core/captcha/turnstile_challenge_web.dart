import 'dart:js_interop';

@JS('parkdTurnstileToken')
external JSPromise<JSString> _parkdTurnstileToken(JSString siteKey);

Future<String?> requestTurnstileToken(String siteKey) async {
  final token = await _parkdTurnstileToken(siteKey.toJS).toDart;
  final value = token.toDart.trim();
  return value.isEmpty ? null : value;
}
