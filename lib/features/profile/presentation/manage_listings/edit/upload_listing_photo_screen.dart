import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/widgets.dart';
import 'annotate_listing_photo_screen.dart';

/// Step 1: Upload or take a photo. Continue is disabled until a photo is selected.
class UploadListingPhotoScreen extends StatefulWidget {
  const UploadListingPhotoScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<UploadListingPhotoScreen> createState() =>
      _UploadListingPhotoScreenState();
}

class _UploadListingPhotoScreenState extends State<UploadListingPhotoScreen> {
  bool _hasPhoto = false;

  void _onContinue() {
    if (!_hasPhoto) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnnotateListingPhotoScreen(listingId: widget.listingId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(
        title: 'Upload a photo',
        showBack: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBlue.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _hasPhoto
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Icon(
                            Icons.image_rounded,
                            size: 80,
                            color: AppColors.primaryBlue.withOpacity(0.6),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 64,
                            color: AppColors.primaryBlue.withOpacity(0.5),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppPhotoActionButton(
                label: 'Take photo',
                icon: Icons.camera_alt_rounded,
                onPressed: () {
                  setState(() => _hasPhoto = true);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppPhotoActionButton(
                label: 'Upload photo',
                icon: Icons.add_rounded,
                onPressed: () {
                  setState(() => _hasPhoto = true);
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_hasPhoto)
                AppPrimaryButton(
                  label: 'Continue',
                  onPressed: _onContinue,
                )
              else
                AppSecondaryButton(
                  label: 'Continue',
                  onPressed: null,
                ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
