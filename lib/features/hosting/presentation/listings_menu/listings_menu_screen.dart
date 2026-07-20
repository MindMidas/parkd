import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';
import '../hosting_menu_body.dart';
import '../../../../core/theme/app_colors.dart';

// Full-screen hosting entry with a back bar (deep links etc) — body is HostingMenuBody
class HostingMenuScreen extends StatelessWidget {
  const HostingMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Hosting', showBack: true),
      body: const HostingMenuBody(),
    );
  }
}
