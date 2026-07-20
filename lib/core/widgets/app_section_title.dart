import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

// Section heading (16/600), optional alignment
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(this.text, {super.key, this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.sectionTitle, textAlign: textAlign);
  }
}
