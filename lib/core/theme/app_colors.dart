import 'package:flutter/material.dart';

// Central palette — prefer AppColors in UI (avoid Material Colors.* in feature code)
class AppColors {
  AppColors._();

  static const primaryBlue = Color(0xFF006FFD);
  static const heatmapBooked = Color(0xFFC4665F);
  static const heatmapHostClosed = Color(0xFFD7D8DB);
  static const heatmapFrameStroke = Color(0xFFD4D4D4);
  static const heatmapStripeDivider = Color(0x18000000);

  static const secondaryBlue = Color(0xFFEAF2FF);
  static const secondaryGrey = Color(0xFFD2D3D5);
  static const black = Color(0xFF1F2024);

  static const iconGrey = Color(0xFF71727A);
  static const iconBlue = Color(0xFF006FFD);

  static const textPrimary = black;
  static const textSecondary = iconGrey;

  // Cards, scaffolds, fields — classic white
  static const surface = Color(0xFFFFFFFF);

  // Text/icons on primaryBlue / error fills (same hex as surface in light theme)
  static const onPrimary = Color(0xFFFFFFFF);
  static const onError = Color(0xFFFFFFFF);

  static const transparent = Color(0x00000000);

  // Black + alpha shadows / scrims (replaces black.withValues in UI code)
  static const shadowWisp = Color(0x0A000000);
  static const shadowLow = Color(0x14000000);
  static const shadowMedium = Color(0x1F000000);
  static const shadowFloating = Color(0x24000000);
  static const shadowPin = Color(0x26000000);
  static const shadowElevated = Color(0x2E000000);
  static const scrimOnImage = Color(0x8C000000);
  static const scrimStrong = Color(0x94000000);

  static const overlayBackdrop = Color(0xFF000000);
  static const onOverlayMuted = Color(0x8AFFFFFF);
  static const overlayControlDim = Color(0x73000000);

  static const error = Color(0xFFD92D20);
  static const success = Color(0xFF12B76A);

  static const demoBannerBackground = Color(0xFFFFF4CC);
  static const demoBannerForeground = Color(0xFF5F4300);
}
