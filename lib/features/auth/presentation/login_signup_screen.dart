import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/captcha/turnstile_challenge.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/auth_error_messages.dart';
import '../../../core/utils/password_policy.dart';
import '../../../core/utils/phone_e164.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_providers.dart';

// One big auth screen: login, signup, email OTP, MFA setup + login TOTP challenge
class LoginSignupScreen extends ConsumerStatefulWidget {
  const LoginSignupScreen({super.key});

  @override
  ConsumerState<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends ConsumerState<LoginSignupScreen> {
  static const _otpResendCooldownSeconds = 30;

  final _loginFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _mfaEnrollFormKey = GlobalKey<FormState>();
  final _mfaLoginFormKey = GlobalKey<FormState>();
  final _confirmPasswordFieldKey = GlobalKey<FormFieldState<String>>();

  final _signUpUsernameFocus = FocusNode(debugLabel: 'signupUsername');
  final _signUpPasswordFocus = FocusNode(debugLabel: 'signupPassword');

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _signupPhoneController = TextEditingController();
  final _birthDateDisplayController = TextEditingController();
  final _loginEmailController = TextEditingController();
  final _loginEmailFieldKey = GlobalKey<FormFieldState<String>>();
  final _loginEmailFocus = FocusNode(debugLabel: 'loginEmail');
  Timer? _loginEmailValidateDebounce;

  /// True after idle debounce or blur so we show format errors (not while mid-typing)
  bool _loginEmailFormatChecked = false;
  final _signUpEmailController = TextEditingController();
  final _signUpEmailFieldKey = GlobalKey<FormFieldState<String>>();
  final _signUpEmailFocus = FocusNode(debugLabel: 'signupEmail');
  Timer? _signUpEmailValidateDebounce;

  /// True after idle debounce or blur so signup email format errors show (not while mid-typing)
  bool _signUpEmailFormatChecked = false;
  final _loginPasswordController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _signupOtpController = TextEditingController();
  final _mfaOtpController = TextEditingController();

  bool _isSignUp = false;
  bool _isSubmitting = false;
  bool _awaitingEmailConfirmation = false;
  bool _awaitingMfaEnrollment = false;
  bool _acceptedTerms = false;
  String? _pendingEmail;
  DateTime? _birthDate;

  /// Latest E.164-style value from [AppIntlPhoneField] (`+[country][national]`)
  String _signupPhoneE164 = '';

  bool _mfaEnrollLoading = false;
  String? _mfaEnrollError;
  String? _mfaEnrollFactorId;
  String? _mfaQrDataUri;
  String? _mfaSecret;

  String? _loginMfaFactorId;
  bool _loginMfaFactorLoading = false;
  String? _loginMfaFactorError;
  bool _loginMfaLoadScheduled = false;
  bool _loginMfaNeedsEnrollment = false;

  AutovalidateMode _signUpAutovalidateMode = AutovalidateMode.disabled;
  AutovalidateMode _loginAutovalidateMode = AutovalidateMode.disabled;

  int _emailOtpResendRemaining = 0;
  Timer? _signupOtpResendCooldownTimer;
  bool _emailOtpResendBusy = false;

  bool get _signUpLiveValidation =>
      _signUpAutovalidateMode != AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _signUpUsernameFocus.addListener(_onSignUpFieldFocusChanged);
    _signUpPasswordFocus.addListener(_onSignUpFieldFocusChanged);
    _loginEmailFocus.addListener(_loginEmailFocusListener);
    _signUpEmailFocus.addListener(_signUpEmailFocusListener);
  }

  void _loginEmailFocusListener() {
    if (!_loginEmailFocus.hasFocus) {
      _loginEmailValidateDebounce?.cancel();
      if (!mounted) {
        return;
      }
      if (_loginAutovalidateMode == AutovalidateMode.disabled) {
        setState(() => _loginEmailFormatChecked = true);
      }
      _loginEmailFieldKey.currentState?.validate();
    }
  }

  void _resetLoginEmailFieldValidation() {
    _loginEmailValidateDebounce?.cancel();
    _loginEmailFormatChecked = false;
  }

  void _onLoginEmailChanged(String _) {
    setState(() {});
    if (_loginAutovalidateMode != AutovalidateMode.disabled) {
      _loginEmailFieldKey.currentState?.validate();
      return;
    }
    if (_loginEmailFormatChecked) {
      _loginEmailFieldKey.currentState?.validate();
    }
    _loginEmailValidateDebounce?.cancel();
    _loginEmailValidateDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) {
        return;
      }
      setState(() => _loginEmailFormatChecked = true);
      _loginEmailFieldKey.currentState?.validate();
    });
  }

  String? _loginEmailValidator(String? value) {
    final s = (value ?? '').trim();
    if (_loginAutovalidateMode == AutovalidateMode.disabled) {
      if (!_loginEmailFormatChecked) {
        return null;
      }
      if (s.isEmpty) {
        return null;
      }
    }
    return FormValidators.email(value);
  }

  bool get _loginEmailOk =>
      _loginEmailController.text.trim().isNotEmpty &&
      FormValidators.email(_loginEmailController.text) == null;

  void _signUpEmailFocusListener() {
    if (!_signUpEmailFocus.hasFocus) {
      _signUpEmailValidateDebounce?.cancel();
      if (!mounted) {
        return;
      }
      if (_signUpAutovalidateMode == AutovalidateMode.disabled) {
        setState(() => _signUpEmailFormatChecked = true);
      }
      _signUpEmailFieldKey.currentState?.validate();
    }
  }

  void _resetSignUpEmailFieldValidation() {
    _signUpEmailValidateDebounce?.cancel();
    _signUpEmailFormatChecked = false;
  }

  void _onSignUpEmailChanged(String _) {
    setState(() {});
    if (_signUpAutovalidateMode != AutovalidateMode.disabled) {
      _signUpEmailFieldKey.currentState?.validate();
      return;
    }
    if (_signUpEmailFormatChecked) {
      _signUpEmailFieldKey.currentState?.validate();
    }
    _signUpEmailValidateDebounce?.cancel();
    _signUpEmailValidateDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) {
        return;
      }
      setState(() => _signUpEmailFormatChecked = true);
      _signUpEmailFieldKey.currentState?.validate();
    });
  }

  String? _signUpEmailValidator(String? value) {
    final s = (value ?? '').trim();
    if (_signUpAutovalidateMode == AutovalidateMode.disabled) {
      if (!_signUpEmailFormatChecked) {
        return null;
      }
      if (s.isEmpty) {
        return null;
      }
    }
    return FormValidators.email(value);
  }

  void _onSignUpFieldFocusChanged() {
    setState(() {});
  }

  void _cancelSignupOtpResendCooldown() {
    _signupOtpResendCooldownTimer?.cancel();
    _signupOtpResendCooldownTimer = null;
    _emailOtpResendRemaining = 0;
  }

  void _ensureSignupOtpResendCooldownTicker() {
    if (_signupOtpResendCooldownTimer != null) return;
    _signupOtpResendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (
      t,
    ) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_emailOtpResendRemaining > 0) {
          _emailOtpResendRemaining--;
        }
        if (_emailOtpResendRemaining <= 0) {
          t.cancel();
          _signupOtpResendCooldownTimer = null;
        }
      });
    });
  }

  void _startEmailOtpResendCooldown() {
    setState(() => _emailOtpResendRemaining = _otpResendCooldownSeconds);
    _ensureSignupOtpResendCooldownTicker();
  }

  @override
  void dispose() {
    _signupOtpResendCooldownTimer?.cancel();
    _loginEmailValidateDebounce?.cancel();
    _signUpEmailValidateDebounce?.cancel();
    _signUpEmailFocus.removeListener(_signUpEmailFocusListener);
    _signUpEmailFocus.dispose();
    _loginEmailFocus.removeListener(_loginEmailFocusListener);
    _loginEmailFocus.dispose();
    _signUpUsernameFocus.removeListener(_onSignUpFieldFocusChanged);
    _signUpPasswordFocus.removeListener(_onSignUpFieldFocusChanged);
    _signUpUsernameFocus.dispose();
    _signUpPasswordFocus.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _signupPhoneController.dispose();
    _birthDateDisplayController.dispose();
    _loginEmailController.dispose();
    _signUpEmailController.dispose();
    _loginPasswordController.dispose();
    _signUpPasswordController.dispose();
    _confirmPasswordController.dispose();
    _signupOtpController.dispose();
    _mfaOtpController.dispose();
    super.dispose();
  }

  String? _svgXmlFromQrDataUri(String? dataUri) {
    if (dataUri == null || dataUri.isEmpty) {
      return null;
    }
    if (!dataUri.startsWith('data:image/svg+xml')) {
      return null;
    }
    final i = dataUri.indexOf(',');
    if (i < 0) {
      return null;
    }
    return Uri.decodeComponent(dataUri.substring(i + 1));
  }

  void _resetMfaEnrollmentState() {
    _mfaEnrollLoading = false;
    _mfaEnrollError = null;
    _mfaEnrollFactorId = null;
    _mfaQrDataUri = null;
    _mfaSecret = null;
  }

  void _resetLoginMfaState() {
    _loginMfaFactorId = null;
    _loginMfaFactorLoading = false;
    _loginMfaFactorError = null;
    _loginMfaLoadScheduled = false;
    _loginMfaNeedsEnrollment = false;
  }

  Future<void> _loadMfaEnrollmentData() async {
    setState(() {
      _mfaEnrollLoading = true;
      _mfaEnrollError = null;
      _mfaEnrollFactorId = null;
      _mfaQrDataUri = null;
      _mfaSecret = null;
    });
    try {
      final r = await ref.read(authRepositoryProvider).mfaEnrollTotp();
      if (!mounted) {
        return;
      }
      setState(() {
        _mfaEnrollFactorId = r.id;
        _mfaQrDataUri = r.totp?.qrCode;
        _mfaSecret = r.totp?.secret;
        _mfaEnrollLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mfaEnrollError = userFacingAuthMessage(e);
        _mfaEnrollLoading = false;
      });
    }
  }

  Future<void> _skipMfaEnrollment() async {
    final id = _mfaEnrollFactorId;
    if (id != null) {
      try {
        await ref.read(authRepositoryProvider).mfaUnenroll(id);
      } on Exception catch (_) {}
    }
    if (!mounted) {
      return;
    }
    _mfaOtpController.clear();
    setState(() {
      _awaitingMfaEnrollment = false;
      _resetMfaEnrollmentState();
    });
  }

  Future<void> _verifyMfaEnrollment() async {
    if (!_mfaEnrollFormKey.currentState!.validate()) {
      return;
    }
    final factorId = _mfaEnrollFactorId;
    if (factorId == null || factorId.isEmpty) {
      AppMessenger.showError(
        context,
        'Set up is still loading. Wait for the QR code or try again.',
      );
      return;
    }

    final authRepository = ref.read(authRepositoryProvider);
    setState(() {
      _isSubmitting = true;
    });

    try {
      await authRepository.mfaVerifyNewFactor(
        factorId: factorId,
        code: _mfaOtpController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      _mfaOtpController.clear();
      setState(() {
        _awaitingMfaEnrollment = false;
        _resetMfaEnrollmentState();
        _loginAutovalidateMode = AutovalidateMode.disabled;
        _loginEmailFormatChecked = false;
        _signUpEmailFormatChecked = false;
        _loginMfaNeedsEnrollment = false;
      });
      _loginEmailValidateDebounce?.cancel();
      _signUpEmailValidateDebounce?.cancel();
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      AppMessenger.showError(context, userFacingAuthMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _ensureLoginMfaFactorLoaded() async {
    if (_loginMfaFactorId != null || _loginMfaFactorLoading) {
      return;
    }
    setState(() {
      _loginMfaFactorLoading = true;
      _loginMfaFactorError = null;
    });
    try {
      final factors = await ref.read(authRepositoryProvider).mfaListFactors();
      if (!mounted) {
        return;
      }
      final id = factors.totp.isNotEmpty ? factors.totp.first.id : null;
      setState(() {
        _loginMfaFactorId = id;
        _loginMfaFactorLoading = false;
        if (id == null) {
          _loginMfaNeedsEnrollment = true;
        } else {
          _loginMfaNeedsEnrollment = false;
        }
      });

      // If the user skipped enrollment during signup, allow them to set up
      // authenticator from this login MFA screen without re-sending emails
      if (id == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadMfaEnrollmentData();
          }
        });
      }
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loginMfaFactorLoading = false;
        _loginMfaFactorError = userFacingAuthMessage(e);
        _loginMfaNeedsEnrollment = false;
      });
    }
  }

  Future<void> _verifyLoginMfa() async {
    if (!_mfaLoginFormKey.currentState!.validate()) {
      return;
    }
    final factorId = _loginMfaFactorId;
    if (factorId == null || factorId.isEmpty) {
      AppMessenger.showError(
        context,
        'Could not load your security key. Try again.',
      );
      return;
    }

    final authRepository = ref.read(authRepositoryProvider);
    setState(() {
      _isSubmitting = true;
    });

    try {
      await authRepository.mfaChallengeAndVerify(
        factorId: factorId,
        code: _mfaOtpController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      _mfaOtpController.clear();
      _resetLoginMfaState();
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      AppMessenger.showError(context, userFacingAuthMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _signOutFromLoginMfa() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on Exception catch (_) {}
    if (!mounted) {
      return;
    }
    _mfaOtpController.clear();
    setState(_resetLoginMfaState);
  }

  Future<void> _pickBirthDate() async {
    if (_isSubmitting) {
      return;
    }
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        _birthDate = picked;
        _birthDateDisplayController.text = DateFormat.yMMMMd().format(picked);
      });
    }
  }

  Future<void> _submit() async {
    final formKey = _isSignUp ? _signUpFormKey : _loginFormKey;
    if (_isSignUp) {
      setState(() {
        _signUpAutovalidateMode = AutovalidateMode.onUserInteraction;
      });
    } else {
      setState(() {
        _loginAutovalidateMode = AutovalidateMode.onUserInteraction;
      });
    }
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (_isSignUp && !_acceptedTerms) {
      AppMessenger.showError(
        context,
        'Please accept Terms and Conditions to continue.',
      );
      return;
    }

    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final fullName = '$first $last'.trim();
    final username = _usernameController.text.trim().toLowerCase();
    final email = (_isSignUp ? _signUpEmailController : _loginEmailController)
        .text
        .trim();
    final password =
        (_isSignUp ? _signUpPasswordController : _loginPasswordController).text
            .trim();

    final authRepository = ref.read(authRepositoryProvider);

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isSignUp) {
        String? captchaToken;
        final turnstileSiteKey = AppEnvironment.optional(
          AppEnvironmentKey.turnstileSiteKey,
        );
        if (kIsWeb && AppEnvironment.isPortfolioDemo) {
          if ((turnstileSiteKey == null || turnstileSiteKey.isEmpty) &&
              kReleaseMode) {
            throw StateError(
              'Public sign-up is unavailable because bot protection is not configured.',
            );
          }
          if (turnstileSiteKey != null && turnstileSiteKey.isNotEmpty) {
            captchaToken = await requestTurnstileToken(turnstileSiteKey);
            if (captchaToken == null) {
              throw StateError('Bot verification could not be completed.');
            }
          }
        }
        final hasPhone = _signupPhoneController.text.trim().isNotEmpty;
        final phoneE164 = hasPhone
            ? normalizePhoneToE164(_signupPhoneE164)
            : null;
        if (hasPhone && phoneE164 == null) {
          if (!mounted) {
            return;
          }
          AppMessenger.showError(
            context,
            'Enter a valid phone number for the selected country.',
          );
          return;
        }
        final response = await authRepository.signUp(
          email: email,
          password: password,
          fullName: fullName,
          username: username,
          phoneE164: phoneE164,
          birthDate: _birthDate,
          captchaToken: captchaToken,
        );

        if (!mounted) {
          return;
        }

        if (response.session == null) {
          _signupOtpController.clear();
          setState(() {
            _awaitingEmailConfirmation = true;
            _pendingEmail = email;
            _isSignUp = false;
            _emailOtpResendRemaining = _otpResendCooldownSeconds;
          });
          _ensureSignupOtpResendCooldownTicker();
        } else {
          _signupOtpController.clear();
          setState(() {
            _isSignUp = false;
            _awaitingMfaEnrollment = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadMfaEnrollmentData();
            }
          });
        }
      } else {
        await authRepository.signIn(email: email, password: password);
      }
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      AppMessenger.showError(context, userFacingAuthMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resendConfirmation() async {
    final pendingEmail = _pendingEmail ?? _signUpEmailController.text.trim();
    if (pendingEmail.isEmpty ||
        _emailOtpResendRemaining > 0 ||
        _emailOtpResendBusy) {
      return;
    }

    final authRepository = ref.read(authRepositoryProvider);
    setState(() {
      _emailOtpResendBusy = true;
    });

    try {
      await authRepository.resendSignupEmail(email: pendingEmail);
      if (!mounted) {
        return;
      }
      _startEmailOtpResendCooldown();
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      AppMessenger.showError(context, userFacingAuthMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _emailOtpResendBusy = false;
        });
      }
    }
  }

  void _openForgotPassword() {
    context.push('/auth/forgot-password');
  }

  /// Clears all sign-up field values and related UI state (call before [setState] or inside it)
  void _clearSignUpFormFields() {
    _firstNameController.clear();
    _lastNameController.clear();
    _usernameController.clear();
    _signUpEmailController.clear();
    _signupPhoneController.clear();
    _signupPhoneE164 = '';
    _signUpPasswordController.clear();
    _confirmPasswordController.clear();
    _birthDate = null;
    _birthDateDisplayController.clear();
    _acceptedTerms = false;
    _signupOtpController.clear();
    _signUpAutovalidateMode = AutovalidateMode.disabled;
  }

  void _clearLoginFormFields() {
    _loginEmailController.clear();
    _loginPasswordController.clear();
  }

  void _switchToSignUp() {
    _resetLoginEmailFieldValidation();
    _resetSignUpEmailFieldValidation();
    _cancelSignupOtpResendCooldown();
    _clearLoginFormFields();
    _clearSignUpFormFields();
    setState(() {
      _emailOtpResendBusy = false;
      _awaitingEmailConfirmation = false;
      _awaitingMfaEnrollment = false;
      _pendingEmail = null;
      _loginAutovalidateMode = AutovalidateMode.disabled;
      _isSignUp = true;
      _resetMfaEnrollmentState();
      _resetLoginMfaState();
    });
    _mfaOtpController.clear();
  }

  Future<void> _switchToLogin() async {
    _resetLoginEmailFieldValidation();
    _resetSignUpEmailFieldValidation();
    final signOutMidFlow =
        _awaitingEmailConfirmation ||
        _awaitingMfaEnrollment ||
        ref.read(needsMfaChallengeProvider);
    if (signOutMidFlow) {
      try {
        await ref.read(authRepositoryProvider).signOut();
      } on Exception catch (_) {}
    }
    if (!mounted) {
      return;
    }
    _cancelSignupOtpResendCooldown();
    _clearSignUpFormFields();
    _loginPasswordController.clear();
    setState(() {
      _emailOtpResendBusy = false;
      _awaitingEmailConfirmation = false;
      _awaitingMfaEnrollment = false;
      _pendingEmail = null;
      _loginAutovalidateMode = AutovalidateMode.disabled;
      _isSignUp = false;
      _resetMfaEnrollmentState();
      _resetLoginMfaState();
    });
    _mfaOtpController.clear();
  }

  void _onUsernameChanged(String _) {
    setState(() {});
  }

  RequirementRowState _rowStateForRule({
    required bool met,
    required bool neutralWhen,
  }) {
    if (neutralWhen) {
      return RequirementRowState.neutral;
    }
    return met ? RequirementRowState.met : RequirementRowState.unmet;
  }

  bool _isSignUpEmailOk() {
    final e = _signUpEmailController.text.trim();
    return e.isNotEmpty && FormValidators.email(e) == null;
  }

  /// Availability is enforced server-side without exposing an enumeration API.
  bool _isSignUpUsernameFullyOk() {
    final u = _usernameController.text.trim().toLowerCase();
    return FormValidators.usernameFormatIsValid(u);
  }

  /// Requirement rows: only while incomplete and user is engaged (focus / typed / after Register)
  bool _showUsernameRequirementList() {
    if (_isSignUpUsernameFullyOk()) {
      return false;
    }
    return _signUpUsernameFocus.hasFocus ||
        _usernameController.text.isNotEmpty ||
        _signUpLiveValidation;
  }

  bool _showPasswordRequirementList() {
    if (_isSignUpPasswordPolicyOk()) {
      return false;
    }
    return _signUpPasswordFocus.hasFocus ||
        _signUpPasswordController.text.isNotEmpty ||
        _signUpLiveValidation;
  }

  bool _isSignUpPasswordPolicyOk() {
    final p = _signUpPasswordController.text;
    return p.isNotEmpty && signupPasswordValidationMessage(p) == null;
  }

  bool _isSignUpConfirmPasswordOk() {
    if (!_isSignUpPasswordPolicyOk()) {
      return false;
    }
    final c = _confirmPasswordController.text.trim();
    if (c.isEmpty) {
      return false;
    }
    return FormValidators.matchPassword(_signUpPasswordController)(c) == null;
  }

  Future<void> _verifySignupOtp() async {
    if (!_otpFormKey.currentState!.validate()) {
      return;
    }
    final email = _pendingEmail ?? _signUpEmailController.text.trim();
    if (email.isEmpty) {
      AppMessenger.showError(
        context,
        'Missing email. Go back and sign up again, or log in.',
      );
      await _switchToLogin();
      return;
    }

    final authRepository = ref.read(authRepositoryProvider);
    setState(() {
      _isSubmitting = true;
    });

    try {
      await authRepository.verifySignupOtp(
        email: email,
        token: _signupOtpController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      _signupOtpController.clear();
      setState(() {
        _awaitingEmailConfirmation = false;
        _pendingEmail = null;
        _awaitingMfaEnrollment = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadMfaEnrollmentData();
        }
      });
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      AppMessenger.showError(context, userFacingAuthMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildLoginLayout(BuildContext context) {
    final imageHeight = MediaQuery.of(context).size.height / 3;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppLoginHeroImage(height: imageHeight),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Welcome!', style: AppTypography.headline),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  formFieldKey: _loginEmailFieldKey,
                  focusNode: _loginEmailFocus,
                  controller: _loginEmailController,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: _loginEmailValidator,
                  showValidCheckmark: _loginEmailOk,
                  enabled: !_isSubmitting,
                  onChanged: _onLoginEmailChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _loginPasswordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  obscureText: true,
                  showPasswordToggle: true,
                  validator: FormValidators.loginPassword,
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppCompactPrimaryTextButton(
                    label: 'Forgot password?',
                    enabled: !_isSubmitting,
                    onPressed: _openForgotPassword,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  onPressed: _isSubmitting ? null : _submit,
                  label: 'Login',
                ),
                const SizedBox(height: AppSpacing.md),
                AppMutedLinkRow(
                  leadingText: 'New User? ',
                  linkText: 'Sign Up',
                  enabled: !_isSubmitting,
                  onLinkPressed: _switchToSignUp,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostSignUpSuccessLayout(BuildContext context) {
    final email = _pendingEmail ?? '';
    return SafeArea(
      bottom: false,
      child: ColoredBox(
        color: AppColors.surface,
        child: Form(
          key: _otpFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: AppFormScrollBody(
            topPadding: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Check your email', style: AppTypography.headline),
                const SizedBox(height: AppSpacing.sm),
                AppFormHelperText('We sent a verification code to\n$email'),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  controller: _signupOtpController,
                  label: 'Verification code',
                  hint: '6-10 digits from email',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: FormValidators.signupEmailOtp,
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(
                  onPressed: _isSubmitting ? null : _verifySignupOtp,
                  label: 'Verify & continue',
                ),
                const SizedBox(height: AppSpacing.md),
                AppSecondaryButton(
                  fullWidth: true,
                  applyTitleCase: false,
                  label: _emailOtpResendRemaining > 0
                      ? 'Send again in ${_emailOtpResendRemaining}s'
                      : 'Resend code',
                  loading: _emailOtpResendBusy,
                  onPressed:
                      (_emailOtpResendRemaining > 0 || _emailOtpResendBusy)
                      ? null
                      : _resendConfirmation,
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: AppCompactPrimaryTextButton(
                    label: 'Back to login',
                    enabled: !_isSubmitting,
                    onPressed: _isSubmitting ? null : () => _switchToLogin(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMfaEnrollmentLayout(BuildContext context) {
    final svg = _svgXmlFromQrDataUri(_mfaQrDataUri);
    return SafeArea(
      bottom: false,
      child: ColoredBox(
        color: AppColors.surface,
        child: Form(
          key: _mfaEnrollFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: AppFormScrollBody(
            topPadding: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Two-step verification', style: AppTypography.headline),
                const SizedBox(height: AppSpacing.sm),
                const AppFormHelperText(
                  'Add an authenticator app (Google Authenticator, Authy, 1Password, etc.). Scan the QR code or enter the secret manually, then enter the 6-digit code.',
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_mfaEnrollLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_mfaEnrollError != null) ...[
                  Text(_mfaEnrollError!, style: AppTypography.bodySecondary),
                  const SizedBox(height: AppSpacing.md),
                  AppPrimaryButton(
                    onPressed: _isSubmitting ? null : _loadMfaEnrollmentData,
                    label: 'Try again',
                  ),
                ] else ...[
                  if (svg != null)
                    Center(
                      child: AppDisplayOutlineCard(
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: SvgPicture.string(svg, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  if (_mfaSecret != null && _mfaSecret!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    SelectableText(
                      'Secret: ${_mfaSecret!}',
                      style: AppTypography.monoCaption,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    controller: _mfaOtpController,
                    label: 'Authenticator code',
                    hint: '6-digit code',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: FormValidators.totpCode,
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    onPressed: _isSubmitting ? null : _verifyMfaEnrollment,
                    label: 'Verify & continue',
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: AppCompactPrimaryTextButton(
                    label: 'Skip for now',
                    enabled: !_isSubmitting && !_mfaEnrollLoading,
                    onPressed: _isSubmitting || _mfaEnrollLoading
                        ? null
                        : () => _skipMfaEnrollment(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: AppCompactPrimaryTextButton(
                    label: 'Back to login',
                    enabled: !_isSubmitting && !_mfaEnrollLoading,
                    onPressed: _isSubmitting || _mfaEnrollLoading
                        ? null
                        : () => _switchToLogin(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginMfaLayout(BuildContext context) {
    final email = ref.watch(currentSessionProvider)?.user.email ?? '';
    return SafeArea(
      bottom: false,
      child: ColoredBox(
        color: AppColors.surface,
        child: Form(
          key: _mfaLoginFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: AppFormScrollBody(
            topPadding: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Two-step verification', style: AppTypography.headline),
                const SizedBox(height: AppSpacing.sm),
                AppFormHelperText(
                  email.isNotEmpty
                      ? 'Enter the code from your authenticator app for\n$email'
                      : 'Enter the code from your authenticator app.',
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_loginMfaFactorLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_loginMfaFactorError != null) ...[
                  Text(
                    _loginMfaFactorError!,
                    style: AppTypography.bodySecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPrimaryButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _loginMfaFactorError = null;
                              _loginMfaFactorId = null;
                            });
                            _ensureLoginMfaFactorLoaded();
                          },
                    label: 'Try again',
                  ),
                ] else ...[
                  AppTextField(
                    controller: _mfaOtpController,
                    label: 'Authenticator code',
                    hint: '6-digit code',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: FormValidators.totpCode,
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    onPressed: _isSubmitting ? null : _verifyLoginMfa,
                    label: 'Continue',
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: AppCompactPrimaryTextButton(
                    label: 'Sign out',
                    enabled: !_isSubmitting,
                    onPressed: _isSubmitting ? null : _signOutFromLoginMfa,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLayout(BuildContext context) {
    return AppFormScrollBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppFormHelperText('Create an account to get started'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _firstNameController,
            label: 'First name',
            hint: 'Alex',
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            validator: FormValidators.firstName,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _lastNameController,
            label: 'Last name(s)',
            hint: 'Smith-Jones',
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            validator: FormValidators.familyName,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            focusNode: _signUpUsernameFocus,
            controller: _usernameController,
            label: 'Username',
            hint: 'alex_doe',
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
              LengthLimitingTextInputFormatter(20),
            ],
            validator: FormValidators.username,
            collapseValidationMessage: true,
            showValidCheckmark: _isSignUpUsernameFullyOk(),
            enabled: !_isSubmitting,
            onChanged: _onUsernameChanged,
          ),
          if (_showUsernameRequirementList())
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...FormValidators.usernameRequirements(
                    _usernameController.text,
                  ).map(
                    (r) => AppRequirementCheckRow(
                      label: r.label,
                      state: _rowStateForRule(
                        met: r.met,
                        neutralWhen:
                            _usernameController.text.trim().isEmpty &&
                            !_signUpLiveValidation,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            formFieldKey: _signUpEmailFieldKey,
            focusNode: _signUpEmailFocus,
            controller: _signUpEmailController,
            label: 'Email address',
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: _signUpEmailValidator,
            showValidCheckmark: _isSignUpEmailOk(),
            enabled: !_isSubmitting,
            onChanged: _onSignUpEmailChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          AppIntlPhoneField(
            controller: _signupPhoneController,
            enabled: !_isSubmitting,
            initialCountryCode: 'CA',
            phoneRequired: false,
            labelText: 'Phone number (optional)',
            onPhoneChanged: (phone) {
              setState(() {
                _signupPhoneE164 = phone.completeNumber;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            readOnly: true,
            onTap: _isSubmitting ? null : _pickBirthDate,
            controller: _birthDateDisplayController,
            label: 'Date of birth (optional)',
            hint: 'Select date',
            suffixIcon: Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: AppColors.iconGrey,
            ),
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            focusNode: _signUpPasswordFocus,
            controller: _signUpPasswordController,
            label: 'Password',
            hint: 'Create a password',
            obscureText: true,
            showPasswordToggle: true,
            validator: FormValidators.signupPassword,
            collapseValidationMessage: true,
            showValidCheckmark: _isSignUpPasswordPolicyOk(),
            enabled: !_isSubmitting,
            onChanged: (_) {
              setState(() {});
              if (_signUpAutovalidateMode != AutovalidateMode.disabled &&
                  _confirmPasswordController.text.isNotEmpty) {
                _confirmPasswordFieldKey.currentState?.validate();
              }
            },
          ),
          if (_showPasswordRequirementList())
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...signupPasswordRequirements(
                    _signUpPasswordController.text,
                  ).map(
                    (r) => AppRequirementCheckRow(
                      label: r.label,
                      state: _rowStateForRule(
                        met: r.met,
                        neutralWhen:
                            _signUpPasswordController.text.isEmpty &&
                            !_signUpLiveValidation,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            formFieldKey: _confirmPasswordFieldKey,
            controller: _confirmPasswordController,
            label: 'Confirm password',
            hint: 'Re-enter your password',
            obscureText: true,
            showPasswordToggle: true,
            validator: FormValidators.matchPassword(_signUpPasswordController),
            collapseValidationMessage: true,
            showValidCheckmark: _isSignUpConfirmPasswordOk(),
            enabled: !_isSubmitting,
            onChanged: (_) {
              setState(() {});
              if (_signUpAutovalidateMode != AutovalidateMode.disabled) {
                _confirmPasswordFieldKey.currentState?.validate();
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCheckboxRichTextRow(
            value: _acceptedTerms,
            onChanged: _isSubmitting
                ? null
                : (value) {
                    setState(() {
                      _acceptedTerms = value ?? false;
                    });
                  },
            labelSpan: TextSpan(
              style: AppTypography.caption,
              children: [
                const TextSpan(text: "I've read and agree with the "),
                TextSpan(
                  text: 'Terms and Conditions',
                  style: AppTypography.captionLink,
                ),
                const TextSpan(text: ' and the '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: AppTypography.captionLink,
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: AppSpacing.xs,
              children: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => context.push('/legal/terms'),
                  child: const Text('Read demo terms'),
                ),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => context.push('/legal/privacy'),
                  child: const Text('Read privacy notice'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            onPressed: _isSubmitting ? null : _submit,
            label: 'Sign Up',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsMfaChallenge = ref.watch(needsMfaChallengeProvider);

    if (needsMfaChallenge) {
      if (!_loginMfaLoadScheduled) {
        _loginMfaLoadScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _ensureLoginMfaFactorLoaded();
          }
        });
      }
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: _loginMfaNeedsEnrollment
            ? _buildMfaEnrollmentLayout(context)
            : _buildLoginMfaLayout(context),
      );
    }

    _loginMfaLoadScheduled = false;

    if (_awaitingMfaEnrollment) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: _buildMfaEnrollmentLayout(context),
      );
    }

    if (_awaitingEmailConfirmation) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: _buildPostSignUpSuccessLayout(context),
      );
    }
    if (_isSignUp) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppTopBar(
          title: 'Sign Up',
          onBack: () {
            if (!_isSubmitting) {
              _switchToLogin();
            }
          },
        ),
        body: Form(
          key: _signUpFormKey,
          autovalidateMode: _signUpAutovalidateMode,
          child: _buildSignUpLayout(context),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Form(
        key: _loginFormKey,
        autovalidateMode: _loginAutovalidateMode,
        child: _buildLoginLayout(context),
      ),
    );
  }
}
