const int minSignupPasswordLength = 8;
const int maxSignupPasswordLength = 256;

// True if password contains at least one non–letter, non-digit character
bool signupPasswordHasSpecialCharacter(String password) {
  return RegExp(r'[^A-Za-z0-9]').hasMatch(password);
}

// Individual password rules for checklist UI (order matches validation priority)
List<({String label, bool met})> signupPasswordRequirements(String password) {
  return [
    (
      label: 'At least $minSignupPasswordLength characters',
      met: password.length >= minSignupPasswordLength,
    ),
    (label: 'One lowercase letter', met: RegExp('[a-z]').hasMatch(password)),
    (label: 'One uppercase letter', met: RegExp('[A-Z]').hasMatch(password)),
    (label: 'One number', met: RegExp(r'\d').hasMatch(password)),
    (
      label: 'One special character (e.g. !@#)',
      met: signupPasswordHasSpecialCharacter(password),
    ),
  ];
}

// Returns `null` if password meets policy, otherwise a short user-facing reason
String? signupPasswordValidationMessage(String password) {
  if (password.length < minSignupPasswordLength) {
    return 'Password must be at least $minSignupPasswordLength characters.';
  }
  if (password.length > maxSignupPasswordLength) {
    return 'Password is too long.';
  }
  if (!RegExp('[a-z]').hasMatch(password)) {
    return 'Password must include at least one lowercase letter.';
  }
  if (!RegExp('[A-Z]').hasMatch(password)) {
    return 'Password must include at least one uppercase letter.';
  }
  if (!RegExp(r'\d').hasMatch(password)) {
    return 'Password must include at least one number.';
  }
  if (!signupPasswordHasSpecialCharacter(password)) {
    return 'Password must include at least one special character.';
  }
  return null;
}
