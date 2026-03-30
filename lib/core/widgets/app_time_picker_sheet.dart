import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/time_step_minutes.dart';

// Cupertino wheel; returns minutes since midnight or null if cancelled
Future<int?> showAppTimePickerMinutes({
  required BuildContext context,
  required int initialMinutes,
}) async {
  final raw =
      (initialMinutes / TimeStepMinutes.step).round() * TimeStepMinutes.step;
  final clamped = raw.clamp(0, TimeStepMinutes.maxMinutes);
  final initial = DateTime(2000, 1, 1, clamped ~/ 60, clamped % 60);

  return showCupertinoModalPopup<int>(
    context: context,
    builder: (ctx) {
      var selected = initial;
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
                    onPressed: () {
                      final m = selected.hour * 60 + selected.minute;
                      Navigator.pop(
                        ctx,
                        m.clamp(0, TimeStepMinutes.maxMinutes),
                      );
                    },
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
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: false,
                    minuteInterval: TimeStepMinutes.step,
                    initialDateTime: initial,
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

// Same wheel but only lets you pick from allowed minute values
Future<int?> showAppTimePickerAllowedMinutes({
  required BuildContext context,
  required int initialMinutes,
  required List<int> allowedMinutes,
}) async {
  final sorted = allowedMinutes.toSet().toList()..sort();
  if (sorted.isEmpty) return null;

  var bestIdx = 0;
  var bestDiff = 1 << 30;
  for (var i = 0; i < sorted.length; i++) {
    final d = (sorted[i] - initialMinutes).abs();
    if (d < bestDiff) {
      bestDiff = d;
      bestIdx = i;
    }
  }

  return showCupertinoModalPopup<int>(
    context: context,
    builder: (ctx) {
      return _AllowedMinutesPickerSheet(
        allowedMinutes: sorted,
        initialIndex: bestIdx,
      );
    },
  );
}

class _AllowedMinutesPickerSheet extends StatefulWidget {
  const _AllowedMinutesPickerSheet({
    required this.allowedMinutes,
    required this.initialIndex,
  });

  final List<int> allowedMinutes;
  final int initialIndex;

  @override
  State<_AllowedMinutesPickerSheet> createState() =>
      _AllowedMinutesPickerSheetState();
}

class _AllowedMinutesPickerSheetState extends State<_AllowedMinutesPickerSheet> {
  late int _selectedIndex;
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, widget.allowedMinutes.length - 1);
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
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
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTypography.bodySecondary
                        .copyWith(color: AppColors.iconGrey),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  onPressed: () => Navigator.pop(
                    context,
                    widget.allowedMinutes[_selectedIndex],
                  ),
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
                data: CupertinoTheme.of(context).copyWith(
                  primaryColor: AppColors.primaryBlue,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: AppTypography.pickerWheel,
                  ),
                ),
                child: CupertinoPicker(
                  scrollController: _controller,
                  itemExtent: 40,
                  onSelectedItemChanged: (i) => _selectedIndex = i,
                  children: widget.allowedMinutes
                      .map(
                        (m) => Center(
                          child: Text(TimeStepMinutes.formatAmPm(m)),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
