import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/availability_weekly.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/availability_overlap.dart';
import '../../../../../core/utils/time_step_minutes.dart';
import '../../../../../core/utils/weekday_ui_to_db.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../profile/providers/listing_invalidation.dart';
import '../../../../profile/providers/profile_providers.dart';
import '../../create_listing/create_listing_flow/set_pricing_screen.dart';
import 'confirmation_success_screen.dart';

// Weekly slot editor that merges saved rows with in-memory drafts until confirm.
class _PendingWeeklySlot {
  _PendingWeeklySlot({
    required this.localId,
    required this.dayOfWeekPg,
    required this.startHhMm,
    required this.endHhMm,
  });

  final int localId;
  final int dayOfWeekPg;
  final String startHhMm;
  final String endHhMm;
  double priceHour = 0;
  double? priceDay;
}

class SetAvailabilityWeeklyScreen extends ConsumerStatefulWidget {
  const SetAvailabilityWeeklyScreen({
    super.key,
    required this.listingId,
    this.currentStep,
    this.totalSteps,
  });

  final String listingId;
  final int? currentStep;
  final int? totalSteps;

  @override
  ConsumerState<SetAvailabilityWeeklyScreen> createState() =>
      _SetAvailabilityWeeklyScreenState();
}

class _SetAvailabilityWeeklyScreenState
    extends ConsumerState<SetAvailabilityWeeklyScreen> {
  final Set<int> _selectedDays = {0, 1, 2, 3, 4, 5, 6};
  final List<_PendingWeeklySlot> _pendingSlots = [];
  int _nextLocalId = 1;

  String? _overlapError;

  static const _postgresDow = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  static void _noopClose() {}

  List<
    ({
      String id,
      String day,
      String timeRange,
      double priceHour,
      double? priceDay,
    })
  >
  _mergedRows(List<AvailabilityWeekly> server) {
    final out =
        <
          ({
            String id,
            String day,
            String timeRange,
            double priceHour,
            double? priceDay,
          })
        >[];
    for (final w in server) {
      out.add((
        id: w.id,
        day: w.dayLabel,
        timeRange: w.timeRangeDisplay,
        priceHour: w.priceHour,
        priceDay: w.priceDay,
      ));
    }
    for (final p in _pendingSlots) {
      final day = _postgresDow[p.dayOfWeekPg.clamp(0, 6)];
      final tr =
          '${TimeStepMinutes.formatHhMmOrAmPmToDisplay(p.startHhMm)} – '
          '${TimeStepMinutes.formatHhMmOrAmPmToDisplay(p.endHhMm)}';
      out.add((
        id: 'local-${p.localId}',
        day: day,
        timeRange: tr,
        priceHour: p.priceHour,
        priceDay: p.priceDay,
      ));
    }
    return out;
  }

  bool _allDisplayedSlotsPriced(List<AvailabilityWeekly> server) {
    if (server.any((w) => w.priceHour <= 0)) return false;
    if (_pendingSlots.any((p) => p.priceHour <= 0)) return false;
    return true;
  }

  bool _canConfirm(List<AvailabilityWeekly> server) {
    final hasAny = server.isNotEmpty || _pendingSlots.isNotEmpty;
    if (!hasAny) return true;
    return _allDisplayedSlotsPriced(server);
  }

  Future<void> _openPricingForSlot(
    int index,
    List<
      ({
        String id,
        String day,
        String timeRange,
        double priceHour,
        double? priceDay,
      })
    >
    rows,
  ) async {
    final r = rows[index];
    if (r.id.startsWith('local-')) {
      final lid = int.parse(r.id.substring('local-'.length));
      _PendingWeeklySlot? p;
      for (final x in _pendingSlots) {
        if (x.localId == lid) {
          p = x;
          break;
        }
      }
      if (p == null) return;
      final pending = p;
      final result = await Navigator.push<({double hourly, double? daily})>(
        context,
        AppPageRoute<({double hourly, double? daily})>(
          builder: (_) => SetPricingScreen(
            initialHourly: pending.priceHour > 0 ? pending.priceHour : 10,
            initialDaily: pending.priceDay,
          ),
        ),
      );
      if (result == null || !mounted) return;
      setState(() {
        pending.priceHour = result.hourly;
        pending.priceDay = result.daily;
      });
      return;
    }

    final result = await Navigator.push<({double hourly, double? daily})>(
      context,
      AppPageRoute<({double hourly, double? daily})>(
        builder: (_) => SetPricingScreen(
          initialHourly: r.priceHour,
          initialDaily: r.priceDay,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await ref
        .read(listingsRepositoryProvider)
        .updateAvailabilityWeeklySlotPrices(
          slotId: r.id,
          priceHour: result.hourly,
          priceDay: result.daily,
        );
    invalidateListingSurfaces(ref, widget.listingId);
  }

  Future<void> _removeSlot(int index, List<String> ids) async {
    final id = ids[index];
    if (id.startsWith('local-')) {
      final lid = int.parse(id.substring('local-'.length));
      setState(() {
        _pendingSlots.removeWhere((p) => p.localId == lid);
        _overlapError = null;
      });
      return;
    }
    await ref.read(listingsRepositoryProvider).deleteAvailabilityWeeklySlot(id);
    if (mounted) {
      ref.invalidate(listingAvailabilityWeeklyProvider(widget.listingId));
      setState(() => _overlapError = null);
    }
  }

  List<({int dayPg, int startMin, int endMin})> _weeklyTripleSnapshot(
    List<AvailabilityWeekly> server,
  ) {
    final out = <({int dayPg, int startMin, int endMin})>[];
    for (final w in server) {
      final r = AvailabilityOverlap.weeklyRowToMinutes(
        startHhMm: w.startTime,
        endHhMm: w.endTime,
      );
      if (r != null) {
        out.add((dayPg: w.dayOfWeek, startMin: r.startMin, endMin: r.endMin));
      }
    }
    for (final p in _pendingSlots) {
      final r = AvailabilityOverlap.weeklyRowToMinutes(
        startHhMm: p.startHhMm,
        endHhMm: p.endHhMm,
      );
      if (r != null) {
        out.add((dayPg: p.dayOfWeekPg, startMin: r.startMin, endMin: r.endMin));
      }
    }
    return out;
  }

  void _tryAddWeeklySlot(
    String startLabel,
    String endLabel,
    List<AvailabilityWeekly> server,
  ) {
    final sm = TimeStepMinutes.tryParseMinutesFromAmPm(startLabel);
    final em = TimeStepMinutes.tryParseMinutesFromAmPm(endLabel);
    if (sm == null || em == null || em <= sm) return;
    final startHh = TimeStepMinutes.minutesToHhMm(sm);
    final endHh = TimeStepMinutes.minutesToHhMm(em);
    final indices = _selectedDays.isEmpty
        ? <int>[0]
        : (_selectedDays.toList()..sort());

    var working = List<({int dayPg, int startMin, int endMin})>.from(
      _weeklyTripleSnapshot(server),
    );
    final toAdd = <_PendingWeeklySlot>[];

    for (final dayIndex in indices) {
      final dayOfWeek = weekdayUiMonFirstToPostgres(dayIndex);
      final candidate = (dayPg: dayOfWeek, startMin: sm, endMin: em);
      final trial = [...working, candidate];
      if (AvailabilityOverlap.weeklyAnyPairOverlaps(trial)) {
        setState(() {
          _overlapError = AvailabilityOverlap.userMessageWeekly;
        });
        return;
      }
      working = trial;
      toAdd.add(
        _PendingWeeklySlot(
          localId: _nextLocalId++,
          dayOfWeekPg: dayOfWeek,
          startHhMm: startHh,
          endHhMm: endHh,
        ),
      );
    }

    setState(() {
      _overlapError = null;
      _pendingSlots.addAll(toAdd);
    });
  }

  Future<void> _onConfirm(List<AvailabilityWeekly> server) async {
    if (!_canConfirm(server)) return;
    final toSave = List<_PendingWeeklySlot>.from(_pendingSlots);

    final preInsert = <({int dayPg, int startMin, int endMin})>[];
    for (final w in server) {
      final r = AvailabilityOverlap.weeklyRowToMinutes(
        startHhMm: w.startTime,
        endHhMm: w.endTime,
      );
      if (r != null) {
        preInsert.add((
          dayPg: w.dayOfWeek,
          startMin: r.startMin,
          endMin: r.endMin,
        ));
      }
    }
    for (final p in toSave) {
      final r = AvailabilityOverlap.weeklyRowToMinutes(
        startHhMm: p.startHhMm,
        endHhMm: p.endHhMm,
      );
      if (r != null) {
        preInsert.add((
          dayPg: p.dayOfWeekPg,
          startMin: r.startMin,
          endMin: r.endMin,
        ));
      }
    }
    if (AvailabilityOverlap.weeklyAnyPairOverlaps(preInsert)) {
      setState(() {
        _overlapError = AvailabilityOverlap.userMessageWeekly;
      });
      return;
    }

    if (toSave.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).push(
        AppPageRoute<void>(
          builder: (_) => ConfirmationSuccessScreen(
            message: 'Availability updated',
            onClose: _noopClose,
            popsOnClose: 2,
          ),
        ),
      );
      return;
    }

    final repo = ref.read(listingsRepositoryProvider);
    try {
      for (final p in toSave) {
        await repo.insertAvailabilityWeeklySlot(
          listingId: widget.listingId,
          dayOfWeek: p.dayOfWeekPg,
          startTimeHhMm: p.startHhMm,
          endTimeHhMm: p.endHhMm,
          priceHour: p.priceHour,
          priceDay: p.priceDay,
        );
      }
    } catch (e) {
      if (mounted) {
        final overlap = AvailabilityOverlap.messageForException(e);
        setState(() {
          _overlapError = overlap ?? 'Could not save new slots. Try again.';
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _pendingSlots.clear());
    invalidateListingSurfaces(ref, widget.listingId);

    if (!mounted) return;
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => ConfirmationSuccessScreen(
          message: 'Availability updated',
          onClose: _noopClose,
          popsOnClose: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weeklyAsync = ref.watch(
      listingAvailabilityWeeklyProvider(widget.listingId),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Availability', showBack: true),
      body: SafeArea(
        bottom: false,
        child: weeklyAsync.when(
          loading: () => const AppPageStatus.loading(),
          error: (e, _) =>
              const AppPageStatus.error(title: 'Could not load schedule'),
          data: (slots) {
            final merged = _mergedRows(slots);
            final canConfirm = _canConfirm(slots);
            final ids = merged.map((r) => r.id).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        AppListingWeeklyScheduleInputCard(
                          title: 'Weekly schedule',
                          selectedDayIndices: _selectedDays,
                          onDaysChanged: (v) => setState(() {
                            _selectedDays.clear();
                            _selectedDays.addAll(v);
                          }),
                          onAddSlot: (a, b) => _tryAddWeeklySlot(a, b, slots),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppListingWeeklyScheduledSlotsCard(
                          slots: merged
                              .map(
                                (r) => (
                                  day: r.day,
                                  timeRange: r.timeRange,
                                  priceHour: r.priceHour,
                                  priceDay: r.priceDay,
                                ),
                              )
                              .toList(),
                          onRemove: (i) => _removeSlot(i, ids),
                          onTapSlot: (i) => _openPricingForSlot(i, merged),
                        ),
                        if (_overlapError != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          AppFormErrorCaption(_overlapError!),
                        ],
                        if (merged.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          const AppFormHelperText(
                            'Tap a slot to set its price',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        const AppAnnotatePhotoInstruction(
                          text:
                              'Changes will only apply to future reservations. '
                              'Existing or ongoing bookings will not be affected.',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
                AppStickyFooter(
                  child: AppPrimaryButton(
                    label: 'Confirm',
                    onPressed: canConfirm ? () => _onConfirm(slots) : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
