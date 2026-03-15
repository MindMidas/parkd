import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isSubmitting = false;
  bool _awaitingEmailConfirmation = false;
  String? _pendingEmail;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final emailLooksValid = email.contains('@');

    if (email.isEmpty || !emailLooksValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    if (!_isSignUp && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    if (_isSignUp && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    final authRepository = ref.read(authRepositoryProvider);

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isSignUp) {
        final response = await authRepository.signUp(
          email: email,
          password: password,
        );

        if (response.session == null && mounted) {
          setState(() {
            _awaitingEmailConfirmation = true;
            _pendingEmail = email;
            _isSignUp = false;
          });
        }
      } else {
        await authRepository.signIn(email: email, password: password);
      }
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resendConfirmation() async {
    final pendingEmail = _pendingEmail ?? _emailController.text.trim();
    if (pendingEmail.isEmpty) {
      return;
    }

    final authRepository = ref.read(authRepositoryProvider);
    setState(() {
      _isSubmitting = true;
    });

    try {
      await authRepository.resendSignupEmail(email: pendingEmail);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmation email sent again.')),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.secondaryGrey),
                ),
                child: Text(
                  _awaitingEmailConfirmation
                      ? 'Account created. Confirm your email, then log in.'
                      : (_isSignUp
                            ? 'Create an account with email and password.'
                            : 'Log in to access the map home screen.'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                obscureText: true,
              ),
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                onPressed: _isSubmitting
                    ? null
                    : (_awaitingEmailConfirmation
                          ? () {
                              setState(() {
                                _awaitingEmailConfirmation = false;
                                _isSignUp = false;
                              });
                            }
                          : _submit),
                label: _awaitingEmailConfirmation
                    ? 'I confirmed my email, continue to login'
                    : (_isSignUp ? 'Create account' : 'Login'),
              ),
              if (_awaitingEmailConfirmation) ...[
                const SizedBox(height: AppSpacing.xs),
                AppSecondaryButton(
                  onPressed: _isSubmitting ? null : _resendConfirmation,
                  label: 'Resend confirmation email',
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _awaitingEmailConfirmation = false;
                          _isSignUp = !_isSignUp;
                        });
                      },
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Login'
                      : "Don't have an account? Sign up",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
