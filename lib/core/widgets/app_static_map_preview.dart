import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppStaticMapPreview extends StatelessWidget {
  const AppStaticMapPreview({
    super.key,
    this.title = 'Interactive map available on mobile',
    this.message =
        'Browse the parking spots here, or open Parkd on iOS or Android for the interactive map.',
    this.pinCount = 1,
    this.compact = false,
  });

  final String title;
  final String message;
  final int pinCount;
  final bool compact;

  static const _pinAlignments = <Alignment>[
    Alignment(-0.58, -0.38),
    Alignment(0.42, -0.20),
    Alignment(-0.08, 0.18),
    Alignment(0.68, 0.38),
    Alignment(-0.70, 0.48),
  ];

  @override
  Widget build(BuildContext context) {
    final visiblePins = pinCount.clamp(0, _pinAlignments.length);
    return Semantics(
      label: '$title. $message',
      image: true,
      child: DecoratedBox(
        key: const Key('app-static-map-preview'),
        decoration: BoxDecoration(
          color: AppColors.secondaryBlue,
          borderRadius: BorderRadius.circular(compact ? 0 : 16),
          border: compact ? null : Border.all(color: AppColors.secondaryGrey),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 0 : 16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _StaticMapBackdropPainter()),
              for (var index = 0; index < visiblePins; index++)
                Align(
                  alignment: _pinAlignments[index],
                  child: const _StaticMapPin(),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? AppSpacing.sm : AppSpacing.md,
                    vertical: compact ? AppSpacing.xs : AppSpacing.sm,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00FFFFFF), Color(0xF7FFFFFF)],
                      stops: [0, 0.35],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        color: AppColors.primaryBlue,
                        size: compact ? 20 : 24,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        title,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: compact
                            ? AppTypography.captionStrong
                            : AppTypography.bodyStrong,
                      ),
                      if (!compact) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.caption,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaticMapPin extends StatelessWidget {
  const _StaticMapPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 31,
      height: 31,
      decoration: const BoxDecoration(
        color: AppColors.primaryBlue,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowPin,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_parking_rounded,
        size: 18,
        color: AppColors.onPrimary,
      ),
    );
  }
}

class _StaticMapBackdropPainter extends CustomPainter {
  const _StaticMapBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final minorRoad = Paint()
      ..color = const Color(0xA3FFFFFF)
      ..strokeWidth = math.max(8, size.shortestSide * 0.045)
      ..strokeCap = StrokeCap.round;
    final majorRoad = Paint()
      ..color = const Color(0xE6FFFFFF)
      ..strokeWidth = math.max(13, size.shortestSide * 0.075)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(-size.width * 0.05, size.height * 0.24),
      Offset(size.width * 1.05, size.height * 0.62),
      majorRoad,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, -size.height * 0.08),
      Offset(size.width * 0.36, size.height * 1.08),
      minorRoad,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, -size.height * 0.05),
      Offset(size.width * 0.56, size.height * 1.05),
      minorRoad,
    );
    canvas.drawLine(
      Offset(-size.width * 0.05, size.height * 0.78),
      Offset(size.width * 1.04, size.height * 0.45),
      minorRoad,
    );
  }

  @override
  bool shouldRepaint(covariant _StaticMapBackdropPainter oldDelegate) => false;
}
