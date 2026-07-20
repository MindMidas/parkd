import 'package:flutter/material.dart';

import '../utils/password_policy.dart';
import '../utils/phone_e164.dart';

/// Reusable [FormFieldValidator]s for [TextFormField] / [AppTextField]
class FormValidators {
  FormValidators._();

  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 2) {
      return 'Enter your full name (at least 2 characters).';
    }
    return null;
  }

  static String? firstName(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 2) {
      return 'Enter your first name (at least 2 characters).';
    }
    return null;
  }

  /// last name, compound surnames, etc
  static String? familyName(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 2) {
      return 'Enter your last name (at least 2 characters).';
    }
    return null;
  }

  /// Empty is OK; if the user types something, require at least 2 characters
  static String? optionalFamilyName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length < 2) {
      return 'If provided, use at least 2 characters.';
    }
    return null;
  }

  /// Phone may be left blank; otherwise must normalize to E.164
  static String? phoneOptional(String? value) {
    final raw = value ?? '';
    if (raw.trim().isEmpty) return null;
    if (normalizePhoneToE164(raw) == null) {
      return 'Enter a valid phone number (10 digits or international +country).';
    }
    return null;
  }

  static String? username(String? value) {
    final u = (value ?? '').trim().toLowerCase();
    if (!_usernamePattern.hasMatch(u)) {
      return 'Username must be 3–20 characters: letters, numbers, or underscores.';
    }
    return null;
  }

  /// `true` when [username] satisfies the same rules as [username] validator
  static bool usernameFormatIsValid(String? value) => username(value) == null;

  /// Rules for signup username checklist (local validation only)
  static List<({String label, bool met})> usernameRequirements(String? value) {
    final u = (value ?? '').trim().toLowerCase();
    final lenOk = u.length >= 3 && u.length <= 20;
    final charsOk = u.isEmpty || RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(u);
    return [
      (label: '3–20 characters', met: lenOk),
      (label: 'Letters, numbers, and underscores only', met: charsOk),
    ];
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty || !_emailPattern.hasMatch(v)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? signupPassword(String? value) {
    return signupPasswordValidationMessage(value ?? '');
  }

  static String? phoneRequired(String? value) {
    if (normalizePhoneToE164(value ?? '') == null) {
      return 'Enter a valid phone number (10 digits or international +country).';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Enter your password.';
    }
    return null;
  }

  /// Signup confirmation code from email (`{{ .Token }}` in Supabase)
  /// GoTrue often sends **6** digits but may send **8** (or similar); we allow 6–10 digits
  static String? signupEmailOtp(String? value) {
    final v = (value ?? '').trim().replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6,10}$').hasMatch(v)) {
      return 'Enter the verification code from your email (digits only).';
    }
    return null;
  }

  /// 6-digit code from the SMS sent for phone verification
  static String? signupSmsOtp(String? value) {
    final v = (value ?? '').trim().replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(v)) {
      return 'Enter the 6-digit code from your text message.';
    }
    return null;
  }

  /// 6-digit TOTP from an authenticator app (Supabase MFA)
  static String? totpCode(String? value) {
    final v = (value ?? '').trim().replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(v)) {
      return 'Enter the 6-digit code from your authenticator app.';
    }
    return null;
  }

  /// Validates that the field matches [other]’s current text (trimmed)
  static String? Function(String?) matchPassword(TextEditingController other) {
    return (String? value) {
      if ((value ?? '').trim() != other.text.trim()) {
        return 'Confirm password must match password.';
      }
      return null;
    };
  }
}
