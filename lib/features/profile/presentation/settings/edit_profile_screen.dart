import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/auth_error_messages.dart';
import '../../../../core/utils/profile_avatar_image_provider.dart';
import '../../../../core/utils/phone_e164.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import 'upload_profile_photo_screen.dart';

// Edit profile fields and verify email changes by OTP.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  static (String, String) splitFullName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) {
      return ('', '');
    }
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return (parts.single, '');
    }
    return (parts.first, parts.sublist(1).join(' '));
  }

  static String _dashToEmpty(String s) {
    if (s == '—' || s == 'Loading…') return '';
    return s;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const AppTopBar(title: 'Edit profile', showBack: true),
        body: const AppPageStatus.loading(),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const AppTopBar(title: 'Edit profile', showBack: true),
        body: const AppPageStatus.error(title: 'Could not load your profile.'),
      ),
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: const AppTopBar(title: 'Edit profile', showBack: true),
            body: const AppPageStatus.empty(title: 'No profile found.'),
          );
        }
        return _EditProfileScaffold(profile: profile);
      },
    );
  }
}

class _EditProfileScaffold extends ConsumerStatefulWidget {
  const _EditProfileScaffold({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_EditProfileScaffold> createState() =>
      _EditProfileScaffoldState();
}

class _EditProfileScaffoldState extends ConsumerState<_EditProfileScaffold> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _birthDateDisplay;
  late final TextEditingController _emailOtp;

  late String _sessionEmail;
  late String _phoneCountryCode;

  // Latest E.164-style value from AppIntlPhoneField (`+countrynational`)
  String _phoneE164 = '';

  DateTime? _birthDate;

  bool _saving = false;
  bool _verifyingEmail = false;
  String? _pendingNewEmail;
  String? _actionError;
  bool _verifyOtpAttempted = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final sessionEmail = ref.read(currentSessionProvider)?.user.email ?? '';
    _sessionEmail = sessionEmail;

    final (f, l) = EditProfileScreen.splitFullName(widget.profile.fullName);
    _firstName = TextEditingController(text: EditProfileScreen._dashToEmpty(f));
    _lastName = TextEditingController(text: EditProfileScreen._dashToEmpty(l));

    final profileEmail = widget.profile.email?.trim();
    _email = TextEditingController(
      text: (profileEmail != null && profileEmail.isNotEmpty)
          ? profileEmail
          : sessionEmail,
    );
    final existingPhone = widget.profile.phone?.trim();
    final decoded = decodeE164ForIntlPhoneField(existingPhone);
    _phoneCountryCode = decoded?.iso ?? 'CA';
    _phone = TextEditingController(text: decoded?.nationalDigits ?? '');
    _phoneE164 = (existingPhone != null && existingPhone.isNotEmpty)
        ? existingPhone
        : '';
    _birthDate = widget.profile.birthDate;
    _birthDateDisplay = TextEditingController(
      text: _birthDate != null ? DateFormat.yMMMMd().format(_birthDate!) : '',
    );
    _emailOtp = TextEditingController();

    _firstName.addListener(_onNameFieldsChanged);
    _lastName.addListener(_onNameFieldsChanged);
  }

  void _onNameFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _firstName.removeListener(_onNameFieldsChanged);
    _lastName.removeListener(_onNameFieldsChanged);
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _birthDateDisplay.dispose();
    _emailOtp.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateDisplay.text = DateFormat.yMMMMd().format(picked);
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _actionError = null;
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final auth = ref.read(authRepositoryProvider);
      final userId = widget.profile.id;

      final first = _firstName.text.trim();
      final last = _lastName.text.trim();
      final fullName = last.isEmpty ? first : '$first $last';

      final nationalDigits = _phone.text.replaceAll(RegExp(r'\D'), '');
      final String? phoneE164;
      if (nationalDigits.isEmpty) {
        phoneE164 = null;
      } else {
        phoneE164 = normalizePhoneToE164(_phoneE164) ?? _phoneE164;
      }

      final newEmail = _email.text.trim();
      final emailChanged =
          newEmail.toLowerCase() != _sessionEmail.toLowerCase();

      await repo.updateProfile(
        userId: userId,
        fullName: fullName,
        phoneE164: phoneE164,
        birthDate: _birthDate,
      );

      if (emailChanged) {
        await auth.updateUserEmail(newEmail);
        if (!mounted) return;
        setState(() {
          _pendingNewEmail = newEmail;
          _saving = false;
        });
        AppMessenger.showSuccessFor(
          messenger,
          'We sent a confirmation code to your new email. Enter it below to finish the change.',
        );
      } else {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _pendingNewEmail = null;
        });
        AppMessenger.showSuccessFor(messenger, 'Profile updated.');
      }

      invalidateProfileSurfaces(ref, widget.profile.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _actionError = userFacingAuthMessage(e);
      });
    }
  }

  Future<void> _verifyEmailChange() async {
    final pending = _pendingNewEmail;
    if (pending == null) return;
    final code = _emailOtp.text.trim();
    setState(() {
      _actionError = null;
      _verifyOtpAttempted = true;
    });
    if (code.length < 6) return;
    setState(() => _verifyingEmail = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyEmailChangeOtp(email: pending, token: code);
      if (!mounted) return;
      setState(() {
        _verifyingEmail = false;
        _pendingNewEmail = null;
        _sessionEmail = _email.text.trim();
      });
      _emailOtp.clear();
      invalidateProfileSurfaces(ref, widget.profile.id);
      AppMessenger.showSuccessFor(messenger, 'Email address confirmed.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifyingEmail = false;
        _actionError = userFacingAuthMessage(e);
      });
    }
  }

  Widget _buildProfileHeader() {
    final refreshed = ref.watch(currentProfileProvider);
    final profileForAvatar = refreshed.asData?.value ?? widget.profile;

    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    final String displayName;
    if (first.isEmpty && last.isEmpty) {
      displayName = widget.profile.displayName;
    } else {
      displayName = last.isEmpty ? first : '$first $last';
    }

    final u = profileForAvatar.username?.trim();
    final handleText = (u != null && u.isNotEmpty) ? '@$u' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AppMenuProfileAvatar(
                imageProvider: profileAvatarImageProvider(profileForAvatar),
                size: 96,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Material(
                  color: AppColors.primaryBlue,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _saving
                        ? null
                        : () async {
                            await Navigator.of(context).push<void>(
                              AppPageRoute<void>(
                                builder: (_) => UploadProfilePhotoScreen(
                                  userId: widget.profile.id,
                                ),
                              ),
                            );
                            if (mounted) {
                              invalidateProfileSurfaces(ref, widget.profile.id);
                            }
                          },
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.edit_rounded,
                        color: AppColors.onPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          displayName,
          style: AppTypography.profileDisplayName,
          textAlign: TextAlign.center,
        ),
        if (handleText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            handleText,
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Edit profile', showBack: true),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: _buildProfileHeader(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: AppTextField(
                        controller: _firstName,
                        label: 'First name',
                        hint: 'Alex',
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [LengthLimitingTextInputFormatter(60)],
                        validator: FormValidators.firstName,
                        enabled: !_saving,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: AppTextField(
                        controller: _lastName,
                        label: 'Last name',
                        hint: 'Smith-Jones',
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [LengthLimitingTextInputFormatter(80)],
                        validator: FormValidators.optionalFamilyName,
                        enabled: !_saving,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            controller: _email,
                            label: 'Email address',
                            hint: 'you@example.com',
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            validator: FormValidators.email,
                            enabled: !_saving,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'If you change your email, we will send a confirmation code to the new address. Your sign-in email updates only after you enter that code.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: AppIntlPhoneField(
                        controller: _phone,
                        enabled: !_saving,
                        initialCountryCode: _phoneCountryCode,
                        phoneRequired: false,
                        labelText: 'Phone number (optional)',
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onPhoneChanged: (phone) {
                          setState(() {
                            _phoneE164 = phone.completeNumber;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: AppTextField(
                        readOnly: true,
                        onTap: _saving ? null : _pickBirthDate,
                        controller: _birthDateDisplay,
                        label: 'Date of birth',
                        hint: 'Select date',
                        suffixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 20,
                          color: AppColors.iconGrey,
                        ),
                        enabled: !_saving,
                      ),
                    ),
                    if (_pendingNewEmail != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Confirm new email',
                              style: AppTypography.hubTitle,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Code sent to $_pendingNewEmail',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Confirmation code',
                              controller: _emailOtp,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              autocorrect: false,
                              onChanged: (_) {
                                if (_actionError != null ||
                                    _verifyOtpAttempted) {
                                  setState(() {
                                    _actionError = null;
                                    _verifyOtpAttempted = false;
                                  });
                                }
                              },
                              validator: (value) {
                                if (!_verifyOtpAttempted) return null;
                                final code = value?.trim() ?? '';
                                if (code.length < 6) {
                                  return 'Enter the code from your email.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppPrimaryButton(
                              label: 'Verify email',
                              onPressed: _verifyingEmail
                                  ? null
                                  : _verifyEmailChange,
                              loading: _verifyingEmail,
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  AppPrimaryButton(
                    label: 'Save changes',
                    onPressed: _saving ? null : _save,
                    loading: _saving,
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
