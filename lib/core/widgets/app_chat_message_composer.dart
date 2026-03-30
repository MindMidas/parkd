import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// Bottom bar: outline message field + filled send (trip/booking chat)
class AppChatMessageComposer extends StatelessWidget {
  const AppChatMessageComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.enabled = true,
    this.hintText = 'Message',
  });

  final TextEditingController controller;
  final VoidCallback? onSend;
  final bool enabled;
  final String hintText;

  static const double _radius = 12;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            enabled: enabled,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_radius),
                borderSide: const BorderSide(color: AppColors.secondaryGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_radius),
                borderSide: const BorderSide(color: AppColors.secondaryGrey),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_radius),
                borderSide: const BorderSide(color: AppColors.secondaryGrey),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filled(
          onPressed: enabled ? onSend : null,
          icon: const Icon(Icons.send_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.onPrimary,
          ),
        ),
      ],
    );
  }
}
