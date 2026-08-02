import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/auth_error_messages.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/auth_providers.dart';

// Forgot password flow: Supabase emails a link that returns to the update screen.
class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  ConsumerState<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState
    extends ConsumerState<PasswordRecoveryScreen> {
  static const _resendCooldownSeconds = 30;
  static const _rateLimitCooldownSeconds = 180;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _emailSendBusy = false;
  bool _emailResendBusy = false;
  bool _emailSentOnce = false;
  int _emailResendRemaining = 0;
  Timer? _cooldownTimer;
  String? _actionError;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _passwordResetRedirectUrl() {
    return AppEnvironment.optional(AppEnvironmentKey.passwordResetRedirectUrl);
  }

  void _ensureCooldownTicker() {
    if (_cooldownTimer != null) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_emailResendRemaining > 0) {
          _emailResendRemaining--;
        }
        if (_emailResendRemaining <= 0) {
          t.cancel();
          _cooldownTimer = null;
        }
      });
    });
  }

  void _startEmailCooldown() {
    setState(() => _emailResendRemaining = _resendCooldownSeconds);
    _ensureCooldownTicker();
  }

  Future<void> _sendEmailRecovery() async {
    setState(() {
      _actionError = null;
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final email = _emailCtrl.text.trim();
    setState(() => _emailSendBusy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPasswordForEmail(
            email: email,
            redirectTo: _passwordResetRedirectUrl(),
          );
      if (!mounted) return;
      setState(() {
        _emailSentOnce = true;
        _actionError = null;
      });
      _startEmailCooldown();
      AppMessenger.showSuccess(
        context,
        'If that email is on an account, you will get a message with a reset link. Open it in your email app to choose a new password.',
      );
    } on Exception catch (e) {
      if (!mounted) return;
      if (e is AuthException &&
          (e.code == 'over_request_rate_limit' ||
              e.code == 'over_email_send_rate_limit')) {
        setState(() {
          // Treat this like a "cooldown until resend" so the user doesn't
          // keep hammering the endpoint and getting 429 with no email
          _emailSentOnce = true;
          _emailResendRemaining = _rateLimitCooldownSeconds;
        });
        _ensureCooldownTicker();
      }
      setState(() => _actionError = userFacingAuthMessage(e));
    } finally {
      if (mounted) setState(() => _emailSendBusy = false);
    }
  }

  Future<void> _resendEmailRecovery() async {
    if (!_emailSentOnce ||
        _emailResendRemaining > 0 ||
        _emailResendBusy ||
        _emailSendBusy) {
      return;
    }
    setState(() {
      _actionError = null;
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final email = _emailCtrl.text.trim();
    setState(() => _emailResendBusy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPasswordForEmail(
            email: email,
            redirectTo: _passwordResetRedirectUrl(),
          );
      if (!mounted) return;
      setState(() => _actionError = null);
      _startEmailCooldown();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _actionError = userFacingAuthMessage(e));
    } finally {
      if (mounted) setState(() => _emailResendBusy = false);
    }
  }

  Widget _emailPrimaryButton(BuildContext context) {
    final busy = _emailSendBusy || _emailResendBusy;

    VoidCallback? onPressed;
    String label;

    if (busy) {
      onPressed = null;
      label = '';
    } else if (!_emailSentOnce) {
      onPressed = _sendEmailRecovery;
      label = 'Send Link';
    } else if (_emailResendRemaining > 0) {
      onPressed = null;
      label = 'Send again in ${_emailResendRemaining}s';
    } else {
      onPressed = _resendEmailRecovery;
      label = 'Resend Email';
    }

    return AppPrimaryButton(
      label: label.isEmpty ? ' ' : label,
      onPressed: onPressed,
      loading: busy,
      applyTitleCase: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailFieldsEnabled = !_emailSendBusy && !_emailResendBusy;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: 'Reset password',
        onBack: _emailSendBusy || _emailResendBusy ? null : () => context.pop(),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: Column(
          children: [
            Expanded(
              child: AppFormScrollBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppFormHelperText(
                      'We’ll email a reset link.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _emailCtrl,
                      label: 'Email',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: FormValidators.email,
                      enabled: emailFieldsEnabled,
                      onChanged: (_) {
                        if (_actionError != null) {
                          setState(() => _actionError = null);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            AppStickyFooter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_actionError != null) ...[
                    AppInlineError(
                      message: _actionError!,
                      onDismiss: () => setState(() => _actionError = null),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  _emailPrimaryButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
