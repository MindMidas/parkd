import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Platform-native type scale. Avoids runtime font downloads and stays legible
/// offline while matching each operating system's accessibility metrics.
abstract final class AppTypography {
  static TextStyle _inter({
    required double fontSize,
    required FontWeight fontWeight,
    double height = 1.35,
    Color? color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle get display =>
      _inter(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2);

  static TextStyle get headline =>
      _inter(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25);

  static TextStyle get navTitle =>
      _inter(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3);

  static TextStyle get hubTitle =>
      _inter(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get profileDisplayName =>
      _inter(fontSize: 20, fontWeight: FontWeight.w600, height: 1.25);

  static TextStyle get sectionTitle =>
      _inter(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25);

  static TextStyle get body =>
      _inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4);

  static TextStyle get pickerWheel => body.copyWith(fontSize: 21, height: 1.2);

  static TextStyle get bodyStrong =>
      _inter(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);

  static TextStyle get numericStrong =>
      _inter(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4);

  static TextStyle get bodyMuted =>
      body.copyWith(color: AppColors.textSecondary);

  static TextStyle get bodyDanger => body.copyWith(color: AppColors.error);

  static TextStyle get bodySecondary =>
      _inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4);

  static TextStyle get label => _inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  static TextStyle get caption => _inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: AppColors.textSecondary,
  );

  static TextStyle get captionStrong => _inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static TextStyle get captionLink => caption.copyWith(
    color: AppColors.primaryBlue,
    fontWeight: FontWeight.w600,
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

  static TextStyle get captionPrimary => _inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static TextStyle get overline => _inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textSecondary,
    letterSpacing: 1,
  );

  static TextStyle get calendarWeekdayHeader => _inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  static TextStyle get button =>
      _inter(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2);

  static TextStyle get buttonCompact =>
      _inter(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2);

  static TextStyle get buttonDense =>
      _inter(fontSize: 13, fontWeight: FontWeight.w600, height: 1.2);

  static TextStyle get textAction => _inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.primaryBlue,
  );

  static TextStyle get navBarLabel =>
      _inter(fontSize: 11, fontWeight: FontWeight.w500, height: 1.1);

  static TextStyle get paymentBrandItalic => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
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
