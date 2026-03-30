import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

DateTime _clampDate(DateTime d, DateTime min, DateTime max) {
  if (d.isBefore(min)) {
    return min;
  }
  if (d.isAfter(max)) {
    return max;
  }
  return d;
}

bool _useCupertinoStyle(BuildContext context) {
  final p = Theme.of(context).platform;
  return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
}

// iOS/macOS = Cupertino wheel; else Material calendar; AppColors theme
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final initial = _clampDate(initialDate, firstDate, lastDate);

  if (!context.mounted) {
    return null;
  }

  if (_useCupertinoStyle(context)) {
    return _showCupertinoDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: firstDate,
    lastDate: lastDate,
    locale: Localizations.localeOf(context),
    builder: (ctx, child) {
      final base = Theme.of(ctx);
      return Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
            primary: AppColors.primaryBlue,
            onPrimary: AppColors.onPrimary,
            onSurface: AppColors.textPrimary,
            surface: AppColors.surface,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: AppColors.surface,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            headerBackgroundColor: AppColors.secondaryBlue,
            headerForegroundColor: AppColors.textPrimary,
            weekdayStyle: AppTypography.calendarWeekdayHeader,
            dayStyle: AppTypography.body,
            yearStyle: AppTypography.body,
            todayForegroundColor: WidgetStateProperty.all(AppColors.primaryBlue),
            dayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.onPrimary;
              }
              if (states.contains(WidgetState.disabled)) {
                return AppColors.textSecondary.withValues(alpha: 0.38);
              }
              return AppColors.textPrimary;
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primaryBlue;
              }
              return AppColors.transparent;
            }),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
            ),
          ),
        ),
        child: child!,
      );
    },
  );
}

Future<DateTime?> _showCupertinoDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  var selected = initialDate;

  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Container(
        padding: EdgeInsets.only(bottom: bottom),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: AppTypography.bodySecondary
                          .copyWith(color: AppColors.iconGrey),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () => Navigator.pop(ctx, selected),
                    child: Text(
                      'Done',
                      style: AppTypography.textAction,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 216,
                child: CupertinoTheme(
                  data: CupertinoTheme.of(ctx).copyWith(
                    primaryColor: AppColors.primaryBlue,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: AppTypography.pickerWheel,
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: initialDate,
                    minimumDate: firstDate,
                    maximumDate: lastDate,
                    onDateTimeChanged: (d) => selected = d,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
