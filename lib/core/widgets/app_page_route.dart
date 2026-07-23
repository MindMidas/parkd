import 'package:flutter/material.dart';

/// Shared page route — platform Material/Cupertino slide (no custom fade).
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
  });
}
