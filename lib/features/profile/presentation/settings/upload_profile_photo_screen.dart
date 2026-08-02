import 'dart:io' show Platform;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/materialize_xfile_for_crop.dart';
import '../../../../core/utils/parkd_image_cropper.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../hosting/presentation/manage_listings/edit/confirmation_success_screen.dart';
import '../../providers/profile_providers.dart';

// New pfp → storage upload → avatar_url, then success screen and bounce back
class UploadProfilePhotoScreen extends ConsumerStatefulWidget {
  const UploadProfilePhotoScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UploadProfilePhotoScreen> createState() =>
      _UploadProfilePhotoScreenState();
}

class _UploadProfilePhotoScreenState
    extends ConsumerState<UploadProfilePhotoScreen> {
  static final ImagePicker _picker = ImagePicker();

  XFile? _pickedImage;
  Uint8List? _previewBytes;
  bool _uploading = false;
  String? _actionError;

  bool get _hasPhoto => _pickedImage != null && _previewBytes != null;

  bool get _isIosSimulator =>
      !kIsWeb &&
      Platform.isIOS &&
      Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _actionError = null);
    if (source == ImageSource.camera && _isIosSimulator) {
      if (!mounted) return;
      setState(
        () => _actionError =
            'The camera is not available in the iOS Simulator. '
            'Use Upload photo, or run the app on an iPhone.',
      );
      return;
    }
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
    } on PlatformException {
      if (!mounted) return;
      setState(
        () => _actionError =
            'Could not open the camera or photo library. Check permissions in Settings.',
      );
      return;
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _actionError =
            'Could not open the camera or photo library. Try again.',
      );
      return;
    }

    if (!mounted || file == null) return;

    late final String cropSourcePath;
    try {
      cropSourcePath = await materializeXFileForImageCrop(file);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _actionError =
            'Could not read the selected image. Try another photo.',
      );
      return;
    }

    String? croppedPath;
    try {
      if (!mounted || !context.mounted) return;
      croppedPath = await cropProfileAvatar(
        context: context,
        sourcePath: cropSourcePath,
      );
    } catch (e, st) {
      assert(() {
        debugPrint('cropProfileAvatar failed: $e\n$st');
        return true;
      }());
      if (!mounted) return;
      setState(
        () => _actionError =
            'Could not open the photo editor. Try another image or restart the app.',
      );
      return;
    }

    if (!mounted) return;
    if (croppedPath == null) return;
    final out = XFile(croppedPath);
    final bytes = await out.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = out;
      _previewBytes = bytes;
    });
  }

  static void _noopClose() {}

  Future<void> _savePhoto() async {
    final path = _pickedImage?.path;
    if (path == null) return;
    setState(() {
      _uploading = true;
      _actionError = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(userId: widget.userId, localFilePath: path);
      invalidateProfileSurfaces(ref, widget.userId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        AppPageRoute<void>(
          builder: (_) => ConfirmationSuccessScreen(
            message: 'Profile photo updated',
            onClose: _noopClose,
            popsOnClose: 2,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _actionError = 'Could not update your photo. Try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Profile photo', showBack: true),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            AppListingPhotoFrame(
              child: Container(
                width: double.infinity,
                color: AppColors.secondaryBlue.withValues(alpha: 0.35),
                child: _previewBytes != null
                    ? Image.memory(
                        _previewBytes!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : _placeholder(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    const AppAnnotatePhotoInstruction(
                      text:
                          'Choose a clear photo of yourself, then crop it to '
                          'the circular frame. Hosts and guests will see this '
                          'on your profile.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppPrimaryButton(
                      label: 'Take photo',
                      icon: Icons.camera_alt_rounded,
                      iconTrailing: true,
                      applyTitleCase: false,
                      onPressed: _uploading
                          ? null
                          : () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppSecondaryButton(
                      label: 'Upload photo',
                      icon: Icons.add_photo_alternate_outlined,
                      applyTitleCase: false,
                      onPressed: _uploading
                          ? null
                          : () => _pickImage(ImageSource.gallery),
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
                  _hasPhoto
                      ? AppPrimaryButton(
                          label: 'Save photo',
                          onPressed: _uploading ? null : _savePhoto,
                          applyTitleCase: false,
                          loading: _uploading,
                        )
                      : const AppPrimaryButton(
                          label: 'Save photo',
                          onPressed: null,
                          applyTitleCase: false,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(Icons.person_rounded, size: 72, color: AppColors.primaryBlue),
    );
  }
}
