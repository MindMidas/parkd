import 'package:flutter/material.dart';
import 'package:parkd/core/theme/app_theme.dart';

Widget buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}
