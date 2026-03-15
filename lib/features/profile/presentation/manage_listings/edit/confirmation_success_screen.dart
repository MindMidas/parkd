import 'package:flutter/material.dart';

import '../../../../../core/widgets/widgets.dart';

/// Reusable success/confirmation screen. Only [message] (and optional [title]/[buttonLabel]) change.
/// Used for "Photo updated", "Price updated", etc. [onClose] typically pops back (e.g. pop until Edit Listing).
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
  /// Number of routes to pop when Close is tapped (e.g. 2 for ModifyPrice->Success, 3 for Upload->Annotate->Success).
  final int popsOnClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AppSuccessView(
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
