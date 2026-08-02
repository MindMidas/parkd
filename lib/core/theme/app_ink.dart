import 'package:flutter/material.dart';

import 'app_colors.dart';

// Shared ink / press flash — keep the visible flicker, stay on-brand.
abstract final class AppInk {
  AppInk._();

  // Primary ripple (icons, CTAs, dense controls).
  static final Color splash = AppColors.primaryBlue.withValues(alpha: 0.28);

  // Soft blue wash under the ripple (rows, tiles, filters).
  static final Color splashSoft = AppColors.secondaryBlue.withValues(
    alpha: 0.9,
  );

  // Held-finger fill flash.
  static final Color highlight = AppColors.secondaryBlue.withValues(alpha: 0.7);

  static final Color hover = AppColors.secondaryBlue.withValues(alpha: 0.4);
}
