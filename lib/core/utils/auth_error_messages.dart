import 'package:supabase_flutter/supabase_flutter.dart';

// maps Supabase/GoTrue errors to UI copy
String userFacingAuthMessage(Object error) {
  if (error is AuthWeakPasswordException) {
    if (error.reasons.isNotEmpty) {
      return error.reasons.join(' ');
    }
    return error.message;
  }

  if (error is AuthException) {
    final code = error.code;
    if (code == 'email_exists' || code == 'user_already_exists') {
      return 'This email is already registered. Try logging in or use forgot password.';
    }
    if (code == 'email_not_confirmed') {
      return 'Email not confirmed. Check your inbox for the signup code, confirm it, then log in.';
    }
    if (code == 'phone_exists') {
      return 'This phone number is already registered with another account.';
    }
    if (code == 'over_request_rate_limit' || code == 'over_email_send_rate_limit') {
      return 'Too many email requests. Wait a few minutes and try again.';
    }
    if (code == 'otp_expired' || code == 'otp_disabled') {
      return 'That code is invalid or expired. Request a new code.';
    }
    if (code == 'mfa_verification_failed' ||
        code == 'mfa_verification_rejected' ||
        code == 'mfa_challenge_expired') {
      return 'That authenticator code is invalid or expired. Try again.';
    }
    if (code == 'mfa_totp_enroll_disabled' ||
        code == 'mfa_phone_enroll_not_enabled') {
      return 'Two-step verification is not enabled for this project. Turn on MFA in the Supabase dashboard, or skip setup for now.';
    }
    if (code == 'too_many_enrolled_mfa_factors') {
      return 'Too many authenticator setups on this account. Remove an old one in the dashboard or try again later.';
    }
    if (code == 'mfa_factor_name_conflict') {
      return 'An authenticator setup is already in progress with this name. Cancel it on this screen, then try Set up again.';
    }
    if (code == 'mfa_factor_not_found') {
      return 'That authenticator setup is no longer valid. Cancel and start Set up again.';
    }
    if (code == 'insufficient_aal') {
      return 'Sign in again with your password, then continue two-step setup.';
    }
    if (code == 'identity_already_exists') {
      return 'That sign-in method is already linked to your account.';
    }

    final lower = error.message.toLowerCase();
    if (lower.contains('token') &&
        (lower.contains('invalid') ||
            lower.contains('expired') ||
            lower.contains('otp'))) {
      return 'That code is invalid or expired. Request a new code.';
    }
    if (lower.contains('already registered')) {
      if (lower.contains('phone')) {
        return 'This phone number is already registered.';
      }
      return 'This email is already registered. Try logging in or use forgot password.';
    }
    if (lower.contains('already exists')) {
      if (lower.contains('phone') || lower.contains('phone number')) {
        return 'This phone number is already registered.';
      }
      if (lower.contains('factor') ||
          lower.contains('friendly name') ||
          lower.contains('mfa') ||
          lower.contains('totp') ||
          lower.contains('authenticator')) {
        return 'An authenticator setup is already in progress. Tap Cancel to clear it, then tap Set up again.';
      }
      return error.message;
    }
    if (lower.contains('database error saving new user') ||
        lower.contains('saving new user')) {
      return 'Could not finish sign-up. That username may already be taken—try another.';
    }
    if (lower.contains('profiles_phone_unique') ||
        (lower.contains('duplicate key') && lower.contains('phone'))) {
      return 'That phone number is already registered.';
    }

    return error.message;
  }

  return error.toString();
}
