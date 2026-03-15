import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Displays an image with a draggable marker (e.g. car icon) for annotating the parking spot.
/// Reusable for Edit Listing photo and Create Listing. Reports marker position for later submit.
class AppAnnotatePhoto extends StatefulWidget {
  const AppAnnotatePhoto({
    super.key,
    required this.image,
    this.initialMarkerPosition,
    this.onMarkerPositionChanged,
  });

  /// The image to display (Widget so we can use placeholder or Image.file/network).
  final Widget image;

  /// Initial marker position as fraction of width/height (0–1). Defaults to center.
  final Offset? initialMarkerPosition;

  /// Called when the user drags the marker. Offset is fractional (0–1).
  final void Function(Offset fractional)? onMarkerPositionChanged;

  @override
  State<AppAnnotatePhoto> createState() => _AppAnnotatePhotoState();
}

class _AppAnnotatePhotoState extends State<AppAnnotatePhoto> {
  late Offset _fractional;

  @override
  void initState() {
    super.initState();
    _fractional = widget.initialMarkerPosition ?? const Offset(0.5, 0.5);
  }

  @override
  void didUpdateWidget(covariant AppAnnotatePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMarkerPosition != null &&
        widget.initialMarkerPosition != oldWidget.initialMarkerPosition) {
      _fractional = widget.initialMarkerPosition!;
    }
  }

  void _onPanUpdate(Size size, DragUpdateDetails details) {
    final dx = (details.delta.dx / size.width).clamp(-1.0, 1.0);
    final dy = (details.delta.dy / size.height).clamp(-1.0, 1.0);
    setState(() {
      _fractional = Offset(
        (_fractional.dx + dx).clamp(0.0, 1.0),
        (_fractional.dy + dy).clamp(0.0, 1.0),
      );
    });
    widget.onMarkerPositionChanged?.call(_fractional);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final markerX = _fractional.dx * w;
        final markerY = _fractional.dy * h;
        const markerRadius = 28.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: widget.image),
              Positioned(
                left: (markerX - markerRadius).clamp(0.0, w - markerRadius * 2),
                top: (markerY - markerRadius).clamp(0.0, h - markerRadius * 2),
                child: GestureDetector(
                  onPanUpdate: (d) => _onPanUpdate(Size(w, h), d),
                  child: Container(
                    width: markerRadius * 2,
                    height: markerRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: AppColors.primaryBlue,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: AppColors.primaryBlue,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Optional instruction text to show below the annotate area.
class AppAnnotatePhotoInstruction extends StatelessWidget {
  const AppAnnotatePhotoInstruction({
    super.key,
    this.text = 'Place the marker on the parking space. Drivers will park at this exact location.',
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
