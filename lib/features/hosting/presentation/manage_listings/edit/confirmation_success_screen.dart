import 'package:flutter/material.dart';

import '../../../../../core/widgets/widgets.dart';
import '../../../../../core/theme/app_colors.dart';

// Generic checkmark outcome — tweak title/message and how many pops on close
class ConfirmationSuccessScreen extends StatelessWidget {
  const ConfirmationSuccessScreen({
    super.key,
    this.title = 'Success',
    required this.message,
    this.buttonLabel = 'Close',
    required this.onClose,
    this.popsOnClose = 1,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onClose;
  final int popsOnClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: AppOutcomeView(
          kind: AppOutcomeKind.success,
          title: title,
          message: message,
          buttonLabel: buttonLabel,
          onClose: () {
            onClose();
            final navigator = Navigator.of(context);
            for (var i = 0; i < popsOnClose && navigator.canPop(); i++) {
              navigator.pop();
            }
          },
        ),
      ),
    );
  }
}
