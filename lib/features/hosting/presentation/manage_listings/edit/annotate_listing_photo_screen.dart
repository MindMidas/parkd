import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../profile/providers/listing_invalidation.dart';
import '../../../../profile/providers/profile_providers.dart';
import '../../create_listing/create_listing_draft.dart';
import 'confirmation_success_screen.dart';
import '../../create_listing/create_listing_flow/set_availability_screen.dart';

// Drag marker on the photo — [createDraft] continues wizard; [listingId] saves immediately
class AnnotateListingPhotoScreen extends ConsumerStatefulWidget {
  const AnnotateListingPhotoScreen({
    super.key,
    this.listingId,
    this.createDraft,
    required this.photoPath,
    this.currentStep,
    this.totalSteps,
    this.selectedAddress,
  }) : assert(
         (listingId != null && createDraft == null) ||
             (listingId == null && createDraft != null),
       );

  final String? listingId;
  final CreateListingDraft? createDraft;
  final String photoPath;
  final int? currentStep;
  final int? totalSteps;
  final String? selectedAddress;

  @override
  ConsumerState<AnnotateListingPhotoScreen> createState() =>
      _AnnotateListingPhotoScreenState();
}

class _AnnotateListingPhotoScreenState
    extends ConsumerState<AnnotateListingPhotoScreen> {
  Offset _markerFraction = const Offset(0.5, 0.5);
  bool _saving = false;
  String? _actionError;

  static void _noopClose() {}

  Future<void> _continue() async {
    final x = _markerFraction.dx.clamp(0.0, 1.0);
    final y = _markerFraction.dy.clamp(0.0, 1.0);
    final draft = widget.createDraft;
    if (widget.currentStep != null && draft != null) {
      draft.markerX = x;
      draft.markerY = y;
      Navigator.of(context).push(
        AppPageRoute<void>(
          builder: (_) => SetAvailabilityScreen(
            draft: draft,
            currentStep: widget.currentStep != null && widget.totalSteps != null
                ? widget.currentStep! + 1
                : null,
            totalSteps: widget.totalSteps,
          ),
        ),
      );
      return;
    }
    final id = widget.listingId;
    if (id == null) return;
    setState(() {
      _saving = true;
      _actionError = null;
    });
    final repo = ref.read(listingsRepositoryProvider);
    try {
      final existing = await repo.getListingPhotos(id);
      for (final p in existing.where((e) => e.sortOrder == 0)) {
        await repo.deleteListingPhoto(p.id);
      }
      await repo.addListingPhotoFromLocalPath(
        listingId: id,
        localFilePath: widget.photoPath,
        sortOrder: 0,
      );
      await repo.setHeroPhotoSpotMarker(listingId: id, markerX: x, markerY: y);
      invalidateListingSurfaces(ref, id);
    } catch (_) {
      if (mounted) {
        setState(
          () => _actionError =
              'Could not update listing photo. Check your connection and try again.',
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => const ConfirmationSuccessScreen(
          message: 'Photo updated',
          onClose: _noopClose,
          popsOnClose: 3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: widget.currentStep != null && widget.totalSteps != null
          ? AppStepTopBar(
              title: 'Mark the spot',
              currentStep: widget.currentStep!,
              totalSteps: widget.totalSteps!,
            )
          : const AppTopBar(
              title: 'Move marker to parking spot',
              showBack: true,
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            AppListingPhotoFrame(
              child: AppAnnotatePhoto(
                markerDiameter: appListingSpotMarkerDiameter,
                markerIconSize: appListingSpotMarkerIconSize,
                borderRadius: 0,
                initialMarkerPosition: _markerFraction,
                onMarkerPositionChanged: (fractional) {
                  setState(() => _markerFraction = fractional);
                },
                image: Image.file(
                  File(widget.photoPath),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.secondaryBlue.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.photo_camera_outlined,
                        size: 40,
                        color: AppColors.primaryBlue,
                      ),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: const AppAnnotatePhotoInstruction(
                  text:
                      'Place the marker on the parking space in the photo. '
                      'Drivers will park at this exact location when they book.',
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
                  widget.currentStep != null
                      ? AppPrimaryButton(
                          label: 'Continue',
                          onPressed: () => _continue(),
                          applyTitleCase: false,
                          loading: _saving,
                        )
                      : AppPrimaryButton(
                          label: 'Confirm',
                          onPressed: () => _continue(),
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
