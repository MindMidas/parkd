import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

// Reusable section heading text.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.title);
  }
}
