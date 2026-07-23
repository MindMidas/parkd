import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../assets/parkd_assets.dart';
import '../theme/app_colors.dart';

// Login hero photo with dark tint and centered brand logo (no chip)
class AppLoginHeroImage extends StatelessWidget {
  const AppLoginHeroImage({
    super.key,
    required this.height,
    this.assetPath = ParkdAssets.loginHouseJpg,
    this.showBrandLogo = true,
  });

  final double height;
  final String assetPath;
  final bool showBrandLogo;

  @override
  Widget build(BuildContext context) {
    final logoSide = min(72.0, height * 0.24);

    return Container(
      height: height,
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFloating,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(assetPath, fit: BoxFit.cover),
          const Positioned.fill(
            child: ColoredBox(color: AppColors.scrimOnImage),
          ),
          if (showBrandLogo)
            Center(
              child: Image.asset(
                ParkdAssets.logoPng,
                width: logoSide,
                height: logoSide,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );
  }
}
