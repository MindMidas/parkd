import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_ink.dart';
import 'app_motion.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  static Color? _filledOverlay(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return AppColors.transparent;
    if (states.contains(WidgetState.pressed)) {
      return AppColors.primaryBlueDark.withValues(alpha: 0.32);
    }
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return AppColors.onPrimary.withValues(alpha: 0.12);
    }
    return null;
  }

  static Color? _outlinedOverlay(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return AppColors.transparent;
    if (states.contains(WidgetState.pressed)) {
      return AppColors.secondaryBlue.withValues(alpha: 0.85);
    }
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return AppColors.secondaryBlue.withValues(alpha: 0.45);
    }
    return null;
  }

  static Color? _textOverlay(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return AppColors.transparent;
    if (states.contains(WidgetState.pressed)) {
      return AppColors.secondaryBlue.withValues(alpha: 0.7);
    }
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return AppColors.secondaryBlue.withValues(alpha: 0.4);
    }
    return null;
  }

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryBlue,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondaryBlue,
      onSecondary: AppColors.black,
      error: AppColors.error,
      onError: AppColors.onError,
      surface: AppColors.surface,
      onSurface: AppColors.black,
    );

    final radiusMd = BorderRadius.circular(AppRadius.md);
    final radiusCard = BorderRadius.circular(AppRadius.card);

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.secondaryBlue,
      textTheme: AppTypography.textTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.black,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        showDragHandle: false,
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.black,
        contentTextStyle: AppTypography.snackBarContent,
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
        elevation: 2,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        floatingLabelStyle: AppTypography.label,
        hintStyle: AppTypography.bodyMuted,
        labelStyle: AppTypography.label,
        // Keep hints inside the field while the floating label is visible.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(color: AppColors.secondaryGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(color: AppColors.secondaryGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: AppColors.onPrimary,
              minimumSize: Size(64, AppSpacing.primaryButtonMinHeight),
              shape: RoundedRectangleBorder(borderRadius: radiusMd),
              textStyle: AppTypography.button,
              animationDuration: AppMotion.press,
              splashFactory: InkRipple.splashFactory,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(_filledOverlay),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        // Secondary CTAs use a filled style distinct from the surface.
        style:
            OutlinedButton.styleFrom(
              minimumSize: Size(64, AppSpacing.primaryButtonMinHeight),
              backgroundColor: AppColors.secondaryBlue,
              foregroundColor: AppColors.primaryBlue,
              disabledForegroundColor: AppColors.iconGrey,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: radiusMd),
              textStyle: AppTypography.button,
              animationDuration: AppMotion.press,
              splashFactory: InkRipple.splashFactory,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(_outlinedOverlay),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          textStyle: AppTypography.textAction,
          animationDuration: AppMotion.press,
          splashFactory: InkRipple.splashFactory,
        ).copyWith(overlayColor: WidgetStateProperty.resolveWith(_textOverlay)),
      ),
      listTileTheme: ListTileThemeData(
        selectedTileColor: AppColors.secondaryBlue.withValues(alpha: 0.35),
        selectedColor: AppColors.primaryBlue,
        iconColor: AppColors.iconGrey,
        enableFeedback: true,
      ),
      splashColor: AppInk.splashSoft,
      highlightColor: AppInk.highlight,
      splashFactory: InkRipple.splashFactory,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        // [AppBottomNav] is custom (top-aligned); theme still applies if a screen uses [NavigationBar]
        indicatorColor: AppColors.secondaryBlue,
        labelTextStyle: WidgetStateProperty.all(AppTypography.navBarLabel),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? AppColors.iconBlue : AppColors.iconGrey,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radiusCard,
          side: const BorderSide(color: AppColors.secondaryGrey),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.onPrimary;
          }
          return AppColors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryBlue;
          }
          return AppColors.secondaryGrey;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.transparent;
          }
          return AppColors.iconGrey.withValues(alpha: 0.45);
        }),
      ),
    );
  }
}
