import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/auth_error_messages.dart';
import '../../../core/utils/password_policy.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/auth_providers.dart';

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _busy = false;
  bool _complete = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.updatePassword(_passwordController.text);
      await auth.signOut();
      if (!mounted) return;
      setState(() => _complete = true);
    } on Exception catch (error) {
      if (mounted) {
        AppMessenger.showError(context, userFacingAuthMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_complete) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: AppOutcomeView(
            kind: AppOutcomeKind.success,
            title: 'Password updated',
            message: 'Sign in again with your new password.',
            buttonLabel: 'Return to sign in',
            onClose: () => context.go('/auth'),
          ),
        ),
      );
    }

    final hasSession = ref.watch(currentSessionProvider) != null;
    if (!hasSession) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const AppTopBar(title: 'Reset password'),
        body: SafeArea(
          child: AppOutcomeView(
            kind: AppOutcomeKind.failure,
            title: 'Reset link required',
            message:
                'Open the newest password-reset link from your email. '
                'Expired and already-used links cannot change a password.',
            buttonLabel: 'Request another link',
            onClose: () => context.go('/auth/forgot-password'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Choose a new password'),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            Expanded(
              child: AppFormScrollBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppFormHelperText(
                      'Use a unique password you don’t reuse elsewhere.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _passwordController,
                      label: 'New password',
                      obscureText: true,
                      showPasswordToggle: true,
                      enabled: !_busy,
                      validator: FormValidators.signupPassword,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      ...signupPasswordRequirements(_passwordController.text)
                          .map(
                        (rule) => AppRequirementCheckRow(
                          label: rule.label,
                          state: rule.met
                              ? RequirementRowState.met
                              : RequirementRowState.unmet,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _confirmationController,
                      label: 'Confirm new password',
                      obscureText: true,
                      showPasswordToggle: true,
                      enabled: !_busy,
                      validator:
                          FormValidators.matchPassword(_passwordController),
                    ),
                  ],
                ),
              ),
            ),
            AppStickyFooter(
              child: AppPrimaryButton(
                label: 'Update password',
                loading: _busy,
                onPressed: _busy ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
