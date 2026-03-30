// normalizes user input to E.164 for Supabase phone auth
String? normalizePhoneToE164(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('+')) {
    final rest = trimmed.substring(1).replaceAll(RegExp(r'\D'), '');
    if (rest.length < 10) return null;
    return '+$rest';
  }

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) {
    return '+1$digits';
  }
  if (digits.length == 11 && digits.startsWith('1')) {
    return '+$digits';
  }
  if (digits.length >= 10) {
    return '+$digits';
  }
  return null;
}
