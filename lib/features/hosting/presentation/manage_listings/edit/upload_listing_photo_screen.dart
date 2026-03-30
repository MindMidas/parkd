import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/messaging/app_messenger.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/materialize_xfile_for_crop.dart';
import '../../../../../core/utils/parkd_image_cropper.dart';
import '../../../../../core/utils/scroll_view_bottom_inset.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../create_listing/create_listing_draft.dart';
import 'annotate_listing_photo_screen.dart';

class UploadListingPhotoScreen extends StatefulWidget {
  const UploadListingPhotoScreen({
    super.key,
    this.listingId,
    this.createDraft,
    this.currentStep,
    this.totalSteps,
    this.selectedAddress,
    this.latitude,
    this.longitude,
  }) : assert(
          (listingId != null && createDraft == null) ||
              (listingId == null && createDraft != null),
        );

  final String? listingId;
  final CreateListingDraft? createDraft;
  final int? currentStep;
  final int? totalSteps;
  final String? selectedAddress;
  final double? latitude;
  final double? longitude;

  @override
  State<UploadListingPhotoScreen> createState() =>
      _UploadListingPhotoScreenState();
}

class _UploadListingPhotoScreenState extends State<UploadListingPhotoScreen> {
  static final ImagePicker _picker = ImagePicker();

  XFile? _pickedImage;
  TextEditingController? _spotNumberController;

  @override
  void initState() {
    super.initState();
    final d = widget.createDraft;
    if (d != null) {
      _spotNumberController =
          TextEditingController(text: d.spotNumber ?? '');
    }
  }

  @override
  void dispose() {
    _spotNumberController?.dispose();
    super.dispose();
  }

  bool get _hasPhoto => _pickedImage != null;

  // sim has no camera; opening it often fails hard (process exit)
  bool get _isIosSimulator =>
      !kIsWeb &&
      Platform.isIOS &&
      Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera && _isIosSimulator) {
      if (!mounted) return;
      AppMessenger.showError(
        context,
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
        maxWidth: 4096,
        maxHeight: 4096,
      );
    } on PlatformException {
      if (!mounted) return;
      AppMessenger.showError(
        context,
        'Could not open the camera or photo library. Check permissions in Settings.',
      );
      return;
    } catch (_) {
      if (!mounted) return;
      AppMessenger.showError(
        context,
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
      AppMessenger.showError(
        context,
        'Could not read the selected image. Try another photo.',
      );
      return;
    }

    String? croppedPath;
    try {
      if (!mounted || !context.mounted) return;
      croppedPath = await cropListingHeroPhoto(
        context: context,
        sourcePath: cropSourcePath,
      );
    } catch (e, st) {
      assert(() {
        debugPrint('cropListingHeroPhoto failed: $e\n$st');
        return true;
      }());
      if (!mounted) return;
      AppMessenger.showError(
        context,
        'Could not open the photo editor. Try another image or restart the app.',
      );
      return;
    }

    if (!mounted) return;
    final outPath = croppedPath;
    if (outPath == null) return;
    setState(() => _pickedImage = XFile(outPath));
  }

  void _onContinue() {
    final path = _pickedImage?.path;
    if (path == null) return;
    final draft = widget.createDraft;
    if (draft != null) {
      draft.photoLocalPath = path;
      final raw = _spotNumberController?.text.trim() ?? '';
      draft.spotNumber = raw.isEmpty ? null : raw;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnnotateListingPhotoScreen(
          listingId: widget.listingId,
          createDraft: draft,
          photoPath: path,
          currentStep: widget.currentStep != null
              ? widget.currentStep! + 1
              : null,
          totalSteps: widget.totalSteps,
          selectedAddress: widget.selectedAddress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad =
        AppSpacing.lg + scrollViewBottomInset(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: widget.currentStep != null && widget.totalSteps != null
          ? AppStepTopBar(
              title: 'Add parking spot photo',
              currentStep: widget.currentStep!,
              totalSteps: widget.totalSteps!,
            )
          : const AppTopBar(
              title: 'Add parking spot photo',
              showBack: true,
            ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            bottomPad,
          ),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppListingPhotoFrame(
                child: Container(
                  width: double.infinity,
                  color: AppColors.secondaryBlue.withValues(alpha: 0.35),
                  child: _hasPhoto
                      ? Image.file(
                          File(_pickedImage!.path),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : const Center(
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 40,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppAnnotatePhotoInstruction(
                text:
                    'Take or upload a clear photo of the parking spot. '
                    'You will crop it to the standard 4:3 frame, then '
                    'place the spot marker. Drivers use this image to '
                    'find the exact location.',
              ),
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                label: 'Take photo',
                icon: Icons.camera_alt_rounded,
                iconTrailing: true,
                applyTitleCase: false,
                onPressed: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppPrimaryButton(
                label: 'Upload photo',
                icon: Icons.add_photo_alternate_outlined,
                iconTrailing: true,
                applyTitleCase: false,
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
              if (widget.createDraft != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Parking spot # (optional)',
                  hint: 'e.g. Stall B2, Unit 4',
                  controller: _spotNumberController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(40),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const AppFormHelperText(
                  'If you have several spaces at the same address, add a '
                  'short label so each listing stays distinct.',
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (_hasPhoto)
                AppPrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _onContinue,
                )
              else
                const AppSecondaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
