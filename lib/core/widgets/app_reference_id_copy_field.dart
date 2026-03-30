import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../messaging/app_messenger.dart';
import 'app_readonly_copy_field.dart';

// ref UUID with copy, same shell as AppReadonlyCopyField
class AppReferenceIdCopyField extends StatelessWidget {
  const AppReferenceIdCopyField({super.key, required this.referenceId});

  final String referenceId;

  @override
  Widget build(BuildContext context) {
    final id = referenceId.trim();
    if (id.isEmpty) return const SizedBox.shrink();
    return AppReadonlyCopyField(
      label: 'Reference ID',
      value: id,
      onCopy: () async {
        await Clipboard.setData(ClipboardData(text: id));
        if (context.mounted) {
          AppMessenger.showSuccess(context, 'Reference ID copied');
        }
      },
    );
  }
}
