import 'package:flutter/material.dart';

// iOS-style sheet handle.
class AppBottomSheetGrabber extends StatelessWidget {
  const AppBottomSheetGrabber({super.key});

  static const double _pillWidth = 36;
  static const double _pillHeight = 5;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 10, bottom: 10),
      child: Center(
        child: SizedBox(
          width: _pillWidth,
          height: _pillHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFC6C6C8),
              borderRadius: BorderRadius.all(Radius.circular(2.5)),
            ),
          ),
        ),
      ),
    );
  }
}
