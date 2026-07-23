import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Parkd type scale — bundled **DM Sans** (UI-friendly geometric sans).
abstract final class AppTypography {
  static const String fontFamily = 'DM Sans';

  static TextStyle _base({
    required double fontSize,
    required FontWeight fontWeight,
    double height = 1.35,
    Color? color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle get display =>
      _base(fontSize: 28, fontWeight: FontWeight.w600, height: 1.2);

  static TextStyle get headline =>
      _base(fontSize: 22, fontWeight: FontWeight.w600, height: 1.25);

  static TextStyle get navTitle =>
      _base(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get hubTitle =>
      _base(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get profileDisplayName =>
      _base(fontSize: 18, fontWeight: FontWeight.w600, height: 1.25);

  static TextStyle get sectionTitle =>
      _base(fontSize: 15, fontWeight: FontWeight.w500, height: 1.25);

  static TextStyle get body =>
      _base(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4);

  static TextStyle get pickerWheel => body.copyWith(fontSize: 21, height: 1.2);

  /// Emphasized body — medium, not heavy (hub rows, labels).
  static TextStyle get bodyStrong =>
      _base(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4);

  static TextStyle get numericStrong =>
      _base(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);

  static TextStyle get bodyMuted =>
      body.copyWith(color: AppColors.textSecondary);

  static TextStyle get bodyDanger => body.copyWith(color: AppColors.error);

  static TextStyle get bodySecondary =>
      _base(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4);

  static TextStyle get label => _base(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  static TextStyle get caption => _base(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: AppColors.textSecondary,
  );

  static TextStyle get captionStrong => _base(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static TextStyle get captionLink => caption.copyWith(
    color: AppColors.primaryBlue,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get monoCaption =>
      caption.copyWith(fontFamily: 'monospace', letterSpacing: 0.5);

  static TextStyle get monoBodyDense =>
      bodySecondary.copyWith(fontFamily: 'monospace', letterSpacing: 0.5);

  static TextStyle get snackBarContent => bodySecondary.copyWith(
    color: AppColors.onPrimary,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle emojiFlagList = TextStyle(fontSize: 18);

  static const TextStyle emojiFlagDense = TextStyle(fontSize: 20);

  static TextStyle get captionPrimary => _base(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static TextStyle get overline => _base(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.textSecondary,
    letterSpacing: 0.6,
  );

  static TextStyle get calendarWeekdayHeader => _base(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  static TextStyle get button =>
      _base(fontSize: 15, fontWeight: FontWeight.w500, height: 1.2);

  static TextStyle get buttonCompact =>
      _base(fontSize: 14, fontWeight: FontWeight.w500, height: 1.2);

  static TextStyle get buttonDense =>
      _base(fontSize: 13, fontWeight: FontWeight.w500, height: 1.2);

  static TextStyle get textAction => _base(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.primaryBlue,
  );

  static TextStyle get navBarLabel =>
      _base(fontSize: 11, fontWeight: FontWeight.w500, height: 1.1);

  static TextStyle get paymentBrandItalic => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontStyle: FontStyle.italic,
    height: 1.4,
    color: AppColors.primaryBlue,
  );

  static TextStyle get paymentPanBlue =>
      bodyStrong.copyWith(color: AppColors.primaryBlue);

  static TextTheme get textTheme => TextTheme(
    displayLarge: display,
    headlineMedium: headline,
    headlineSmall: sectionTitle,
    titleLarge: navTitle,
    titleMedium: hubTitle,
    titleSmall: label,
    bodyLarge: body,
    bodyMedium: bodySecondary,
    bodySmall: caption,
    labelLarge: label,
    labelSmall: caption,
  );
}
