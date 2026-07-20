import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

// Grey caption label above a field group
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.caption);
  }
}
