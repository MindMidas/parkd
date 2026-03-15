import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.5,
      color: AppColors.secondaryGrey,
    );
  }
}

