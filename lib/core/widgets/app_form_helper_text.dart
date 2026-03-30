import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

// Small grey helper under/over fields
class AppFormHelperText extends StatelessWidget {
  const AppFormHelperText(
    this.text, {
    super.key,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption,
      textAlign: textAlign,
    );
  }
}

// Red caption under fields when overlap or val blows up
class AppFormErrorCaption extends StatelessWidget {
  const AppFormErrorCaption(
    this.text, {
    super.key,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(color: AppColors.error),
      textAlign: textAlign,
    );
  }
}
