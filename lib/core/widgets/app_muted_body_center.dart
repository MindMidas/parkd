import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

class AppMutedBodyCenter extends StatelessWidget {
  const AppMutedBodyCenter(
    this.message, {
    super.key,
    this.textAlign = TextAlign.center,
    this.padding,
  });

  final String message;
  final TextAlign textAlign;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      message,
      textAlign: textAlign,
      style: AppTypography.bodyMuted,
    );
    return Center(
      child: padding != null ? Padding(padding: padding!, child: text) : text,
    );
  }
}
