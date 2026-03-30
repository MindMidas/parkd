import 'package:flutter/services.dart';

// formats national digits as '(XXX) XXX-XXXX' (max 10 digits). strips non-digits
class NanpPhoneInputFormatter extends TextInputFormatter {
  static String formatDigits(String digits) {
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    if (digits.isEmpty) {
      return '';
    }
    if (digits.length < 3) {
      return '($digits';
    }
    if (digits.length == 3) {
      return '($digits)';
    }
    final area = digits.substring(0, 3);
    final rest = digits.substring(3);
    if (rest.length <= 3) {
      return '($area) $rest';
    }
    final mid = rest.substring(0, 3);
    var last = rest.substring(3);
    if (last.length > 4) {
      last = last.substring(0, 4);
    }
    return '($area) $mid-$last';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newDigits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final text = formatDigits(newDigits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
