import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

// Airbnb-style price pill for Mapbox point annotations (Parkd blue).
Future<Uint8List> buildMapPriceMarkerPng({
  required String label,
  required bool selected,
  double devicePixelRatio = 3,
}) async {
  final height = selected ? 40.0 : 36.0;
  const horizontalPad = 14.0;

  final measure = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final width = (measure.width + horizontalPad * 2).clamp(44.0, 120.0);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(devicePixelRatio);

  final textPainter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        fontFamily: AppTypography.fontFamily,
        color: AppColors.onPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, width, height),
    Radius.circular(height / 2),
  );
  canvas.drawRRect(
    rect.shift(const Offset(0, 1.5)),
    Paint()..color = AppColors.shadowFloating,
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..color = selected ? AppColors.primaryBlueDark : AppColors.primaryBlue,
  );
  if (selected) {
    canvas.drawRRect(
      rect,
      Paint()
        ..color = AppColors.onPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
  textPainter.paint(
    canvas,
    Offset((width - textPainter.width) / 2, (height - textPainter.height) / 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (width * devicePixelRatio).round(),
    (height * devicePixelRatio).round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

// Center badge for the approximate “Where you'll be” halo (Parkd blue).
Future<Uint8List> buildApproximateCenterBadgePng({
  double devicePixelRatio = 3,
}) async {
  const size = 28.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(devicePixelRatio);
  final center = const Offset(size / 2, size / 2);
  canvas.drawCircle(center, 11, Paint()..color = AppColors.primaryBlue);
  canvas.drawCircle(
    center,
    11,
    Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  final icon = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(Icons.local_parking_rounded.codePoint),
      style: TextStyle(
        fontSize: 13,
        fontFamily: Icons.local_parking_rounded.fontFamily,
        package: Icons.local_parking_rounded.fontPackage,
        color: AppColors.onPrimary,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  icon.paint(
    canvas,
    Offset(center.dx - icon.width / 2, center.dy - icon.height / 2),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (size * devicePixelRatio).round(),
    (size * devicePixelRatio).round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

String mapPriceMarkerLabel(Listing listing, {int? clusterCount}) {
  if (clusterCount != null && clusterCount > 1) {
    return '$clusterCount';
  }
  final hourly = listing.minHourlyPrice;
  if (hourly == null) return 'P';
  final rounded = hourly == hourly.roundToDouble()
      ? hourly.toStringAsFixed(0)
      : hourly.toStringAsFixed(2);
  return '\$$rounded';
}
