import 'package:flutter/material.dart';

// Shared page route with platform-native transitions.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
  });
}
