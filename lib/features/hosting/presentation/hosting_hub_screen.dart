import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'hosting_menu_body.dart';

// tab hub for hosts, same destinations as the pushed menu but no back bar
class HostingHubScreen extends StatelessWidget {
  const HostingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(
        title: 'Hosting',
        showBack: false,
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            const Expanded(
              child: SingleChildScrollView(
                child: HostingMenuBody(topSpacing: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
