import 'package:flutter/material.dart';

// import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_step_top_bar.dart';
import '../../../../../core/widgets/widgets.dart';
import 'confirmation_success_screen.dart';
import 'set_availability_chooser_screen.dart';

/// Step 2: Annotate the uploaded photo by dragging the marker to the parking spot.
class AnnotateListingPhotoScreen extends StatelessWidget {
  const AnnotateListingPhotoScreen({
    super.key,
    required this.listingId,
    this.currentStep,
    this.totalSteps,
    this.selectedAddress,
  });

  final String listingId;
  final int? currentStep;
  final int? totalSteps;
  final String? selectedAddress;

  static void _noopClose() {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: currentStep != null
          ? AppStepTopBar(
              title: 'Move the marker to the exact parking spot',
              currentStep: currentStep!,
              totalSteps: totalSteps!,
            )
          : const AppTopBar(
              title: 'Move the marker to the exact parking spot',
              showBack: true,
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: AppAnnotatePhoto(
                    image: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/house-with-concrete-driveway-05-090318.jpg',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const AppAnnotatePhotoInstruction(
                text:
                    'Place the marker on the parking space in the photo. '
                    'Drivers will park at this exact location when they book.',
              ),
              const SizedBox(height: AppSpacing.xl),
              currentStep != null
                  ? AppPrimaryButton(
                      label: 'Continue',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SetAvailabilityChooserScreen(
                              listingId: 'temp-id',
                            ),
                          ),
                        );
                      },
                    )
                  : AppPrimaryButton(
                      label: 'Confirm',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ConfirmationSuccessScreen(
                              message: 'Photo updated',
                              onClose: _noopClose,
                              popsOnClose: 3,
                            ),
                          ),
                        );
                      },
                    ),
              // AppPrimaryButton(
              //   label: 'Confirm',
              //   onPressed: () {
              //     Navigator.of(context).push(
              //       MaterialPageRoute<void>(
              //         builder: (_) => const ConfirmationSuccessScreen(
              //           message: 'Photo updated',
              //           onClose: _noopClose,
              //           popsOnClose: 3,
              //         ),
              //       ),
              //     );
              //   },
              // ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
