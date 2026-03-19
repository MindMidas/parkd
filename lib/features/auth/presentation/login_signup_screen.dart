import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_providers.dart';

class LoginSignupScreen extends ConsumerStatefulWidget {
  const LoginSignupScreen({super.key});

  @override
  ConsumerState<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends ConsumerState<LoginSignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _isSubmitting = false;
  bool _awaitingEmailConfirmation = false;
  bool _acceptedTerms = false;
  String? _pendingEmail;
  String? _pendingPassword;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final emailLooksValid = email.contains('@');

    if (_isSignUp && name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name is required.')));
      return;
    }

    if (email.isEmpty || !emailLooksValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    if (_isSignUp && confirmPassword != password) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirm Password must match Password.')),
      );
      return;
    }

    if (_isSignUp && !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept Terms and Conditions to continue.'),
        ),
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
            _pendingPassword = password;
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

  void _showForgotPasswordNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Forgot password flow is not wired yet.')),
    );
  }

  void _switchToSignUp() {
    setState(() {
      _awaitingEmailConfirmation = false;
      _isSignUp = true;
      _acceptedTerms = false;
      _pendingEmail = null;
      _pendingPassword = null;
    });
  }

  void _switchToLogin() {
    setState(() {
      _awaitingEmailConfirmation = false;
      _isSignUp = false;
      _pendingEmail = null;
      _pendingPassword = null;
    });
  }

  Future<void> _confirmEmailAndContinue() async {
    final pendingEmail = _pendingEmail ?? _emailController.text.trim();
    final pendingPassword = _pendingPassword ?? _passwordController.text.trim();

    if (pendingEmail.isEmpty || pendingPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing signup details. Please login manually.'),
        ),
      );
      _switchToLogin();
      return;
    }

    final authRepository = ref.read(authRepositoryProvider);
    setState(() {
      _isSubmitting = true;
    });

    try {
      await authRepository.signIn(
        email: pendingEmail,
        password: pendingPassword,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _awaitingEmailConfirmation = false;
        _pendingEmail = null;
        _pendingPassword = null;
      });
    } on Exception {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please confirm your email before continuing.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSignUpInput({
    required BuildContext context,
    required String title,
    required TextEditingController controller,
    String? hint,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLayout(BuildContext context) {
    final imageHeight = MediaQuery.of(context).size.height / 3;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: imageHeight,
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset('assets/login_house.jpg', fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _showForgotPasswordNotice,
                    child: Text(
                      'Forgot password?',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  onPressed: _isSubmitting ? null : _submit,
                  label: 'Login',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'New User? ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: _isSubmitting ? null : _switchToSignUp,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Register now',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostSignUpSuccessLayout(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AppSuccessView(
                title: 'Success',
                message: 'Your account has been created',
                buttonLabel: 'Confirm your email and continue',
                onClose: _isSubmitting ? () {} : _confirmEmailAndContinue,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppSecondaryButton(
              onPressed: _isSubmitting ? null : _resendConfirmation,
              label: 'Resend confirmation email',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpLayout(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign Up',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Create an account to get started',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildSignUpInput(
              context: context,
              title: 'Name',
              controller: _nameController,
              hint: 'Enter your full name',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildSignUpInput(
              context: context,
              title: 'Email address',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              hint: 'example@email.com',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildSignUpInput(
              context: context,
              title: 'Password',
              controller: _passwordController,
              obscureText: true,
              hint: 'Create a password',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildSignUpInput(
              context: context,
              title: 'Confirm Password',
              controller: _confirmPasswordController,
              obscureText: true,
              hint: 'Confirm password',
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _acceptedTerms,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primaryBlue;
                      }
                      return AppColors.secondaryGrey;
                    }),
                    side: const BorderSide(color: AppColors.secondaryGrey),
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _acceptedTerms = value ?? false;
                            });
                          },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        const TextSpan(
                          text: "I've read and agree with the ",
                        ),
                        TextSpan(
                          text: 'Terms and Conditions',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const TextSpan(text: ' and the '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              onPressed: _isSubmitting ? null : _submit,
              label: 'Register',
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already a User? ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: _isSubmitting ? null : _switchToLogin,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Login',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _awaitingEmailConfirmation
          ? _buildPostSignUpSuccessLayout(context)
          : (_isSignUp ? _buildSignUpLayout(context) : _buildLoginLayout(context)),
    );
  }
}
