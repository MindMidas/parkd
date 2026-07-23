import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// Draggable car marker on a photo; reports 0–1 position for save
class AppAnnotatePhoto extends StatefulWidget {
  const AppAnnotatePhoto({
    super.key,
    required this.image,
    this.initialMarkerPosition,
    this.onMarkerPositionChanged,
    this.markerDiameter = 56,
    this.markerIconSize = 28,
    this.borderRadius = 12,
  });

  // Image widget (file, network, placeholder, etc.)
  final Widget image;

  // 0–1 in the frame; default center
  final Offset? initialMarkerPosition;

  // Fires while dragging; offset is 0–1
  final void Function(Offset fractional)? onMarkerPositionChanged;
  final double markerDiameter;
  final double markerIconSize;
  final double borderRadius;

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
        final markerRadius = widget.markerDiameter / 2;

        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
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
                      color: AppColors.onPrimary,
                      border: Border.all(
                        color: AppColors.primaryBlue,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowPin,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.directions_car_rounded,
                      color: AppColors.primaryBlue,
                      size: widget.markerIconSize,
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

// Hint under the annotate box
class AppAnnotatePhotoInstruction extends StatelessWidget {
  const AppAnnotatePhotoInstruction({
    super.key,
    this.text =
        'Place the marker on the parking space. Drivers will park at this exact location.',
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }
}
