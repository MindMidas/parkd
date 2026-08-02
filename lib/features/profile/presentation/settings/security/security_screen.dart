import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/auth_error_messages.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../auth/providers/auth_providers.dart';

// TOTP enroll/disable + forgot-password route — Supabase auth, not SQL
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends ConsumerState<SecuritySettingsScreen> {
  bool _loadingFactors = true;
  String? _factorsError;
  String? _actionError;
  String? _enrollFactorId;
  bool _enrolling = false;

  String? _qrDataUri;
  String? _secret;

  final _codeController = TextEditingController();

  bool _verifying = false;
  bool _unenrolling = false;

  List<Factor>?
  _totpFactors; // verified factors (mfaListFactors filters verified)

  @override
  void initState() {
    super.initState();
    _refreshFactors();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _resetEnrollUi() {
    void clear() {
      _enrollFactorId = null;
      _qrDataUri = null;
      _secret = null;
      _codeController.clear();
      _enrolling = false;
      _verifying = false;
    }

    if (!mounted) {
      clear();
      return;
    }
    setState(clear);
  }

  // Drops the in-progress TOTP factor on the server (if any), then clears UI
  Future<void> _cancelEnroll() async {
    final factorId = _enrollFactorId;
    _resetEnrollUi();
    if (factorId == null || factorId.isEmpty) return;
    try {
      await ref.read(authRepositoryProvider).mfaUnenroll(factorId);
    } on Exception catch (_) {}
    if (mounted) await _refreshFactors();
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

  Future<void> _refreshFactors() async {
    setState(() {
      _loadingFactors = true;
      _factorsError = null;
    });
    try {
      final factors = await ref.read(authRepositoryProvider).mfaListFactors();
      if (!mounted) return;
      setState(() {
        _totpFactors = factors.totp;
        _loadingFactors = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _factorsError = userFacingAuthMessage(e);
        _loadingFactors = false;
      });
    }
  }

  Future<void> _startEnrollTotp() async {
    setState(() {
      _enrolling = true;
      _factorsError = null;
      _verifying = false;
      _enrollFactorId = null;
      _qrDataUri = null;
      _secret = null;
    });
    try {
      final enroll = await ref.read(authRepositoryProvider).mfaEnrollTotp();
      if (!mounted) return;
      setState(() {
        _enrollFactorId = enroll.id;
        _qrDataUri = enroll.totp?.qrCode;
        _secret = enroll.totp?.secret;
        _enrolling = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _enrolling = false;
        _factorsError = userFacingAuthMessage(e);
      });
    }
  }

  Future<void> _verifyEnroll() async {
    if (_enrollFactorId == null || _enrollFactorId!.isEmpty) {
      return;
    }
    if (!(_codeController.text.trim().isNotEmpty)) {
      return;
    }

    setState(() {
      _verifying = true;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .mfaVerifyNewFactor(
            factorId: _enrollFactorId!,
            code: _codeController.text.trim(),
          );
      if (!mounted) return;
      _codeController.clear();
      _resetEnrollUi();
      await _refreshFactors();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _actionError = userFacingAuthMessage(e);
      });
    }
    if (mounted) {
      setState(() {
        _verifying = false;
      });
    }
  }

  Future<void> _disableTotp() async {
    final factorId = (_totpFactors != null && _totpFactors!.isNotEmpty)
        ? _totpFactors!.first.id
        : null;
    if (factorId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmDialog(
        title: 'Disable two-step verification?',
        message:
            'You will be able to log in without an authenticator code after disabling.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Disable',
        confirmDestructive: true,
        onCancel: () => Navigator.of(ctx).pop(false),
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _unenrolling = true;
    });
    try {
      await ref.read(authRepositoryProvider).mfaUnenroll(factorId);
      if (!mounted) return;
      setState(() {
        _unenrolling = false;
      });
      _resetEnrollUi();
      await _refreshFactors();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _unenrolling = false;
        _actionError = userFacingAuthMessage(e);
      });
    }
  }

  Widget _buildTwoStepBody(BuildContext context, bool hasTotp) {
    if (_loadingFactors) {
      return const AppPageStatus.loading();
    }
    if (_factorsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInlineError(
            message: _factorsError!,
            onDismiss: () => setState(() => _factorsError = null),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSecondaryButton(
            label: 'Try again',
            onPressed: _refreshFactors,
          ),
        ],
      );
    }
    if (hasTotp) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppFormHelperText(
            'Authenticator app enabled for your account.',
          ),
          if (_actionError != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppInlineError(
              message: _actionError!,
              onDismiss: () => setState(() => _actionError = null),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: 'Disable 2FA',
            onPressed: _unenrolling
                ? null
                : () {
                    setState(() => _actionError = null);
                    _disableTotp();
                  },
            applyTitleCase: false,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppFormHelperText('Use any authenticator app.'),
        const SizedBox(height: AppSpacing.md),
        if (_qrDataUri == null)
          AppPrimaryButton(
            label: 'Set up authenticator',
            onPressed: _enrolling ? null : _startEnrollTotp,
          )
        else ...[
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: AppDisplayOutlineCard(
                child: _svgXmlFromQrDataUri(_qrDataUri) == null
                    ? Center(
                        child: Text(
                          'QR not available',
                          style: AppTypography.bodyMuted,
                        ),
                      )
                    : SvgPicture.string(
                        _svgXmlFromQrDataUri(_qrDataUri)!,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ),
          if (_secret != null && _secret!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const AppDivider(),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Can't scan the QR? Enter this key manually in your app.",
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppReadonlyCopyField(
              label: 'Secret key',
              value: _secret!,
              onCopy: () async {
                await Clipboard.setData(ClipboardData(text: _secret!));
                if (!context.mounted) return;
                AppMessenger.showSuccess(context, 'Secret copied to clipboard');
              },
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const AppDivider(),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Authenticator code',
            controller: _codeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: FormValidators.totpCode,
            autocorrect: false,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTotp = (_totpFactors != null && _totpFactors!.isNotEmpty);
    final showEnrollFooter = !hasTotp && _qrDataUri != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Security', showBack: true),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: AppMenuScrollBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppScreenSection(
                      title: 'Two-step verification',
                      child: _buildTwoStepBody(context, hasTotp),
                    ),
                    if (!showEnrollFooter)
                      AppScreenSection(
                        dividerAbove: true,
                        title: 'Password',
                        child: AppNavTile(
                          label: 'Change password',
                          icon: Icons.lock_reset_rounded,
                          onTap: () => context.push('/auth/forgot-password'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (showEnrollFooter)
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
                    AppPrimaryButton(
                      label: 'Verify & enable',
                      onPressed: _verifying
                          ? null
                          : () {
                              setState(() => _actionError = null);
                              _verifyEnroll();
                            },
                      loading: _verifying,
                      applyTitleCase: false,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppSecondaryButton(
                      label: 'Cancel',
                      onPressed:
                          _enrolling || _verifying ? null : _cancelEnroll,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
