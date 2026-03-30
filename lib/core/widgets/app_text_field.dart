import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

// reusable text input for forms like login and signup
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.showPasswordToggle = false,
    this.validator,
    this.autovalidateMode,
    this.inputFormatters,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.readOnly = false,
    this.onTap,
    this.enabled = true,
    this.suffixIcon,
    this.onChanged,
    this.formFieldKey,
    this.collapseValidationMessage = false,
    this.showValidCheckmark = false,
    this.focusNode,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool showPasswordToggle;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;
  final List<TextInputFormatter>? inputFormatters;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final GlobalKey<FormFieldState<String>>? formFieldKey;
  final bool collapseValidationMessage;
  final bool showValidCheckmark;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.showPasswordToggle && oldWidget.obscureText != widget.obscureText) {
      _obscure = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hidden = widget.showPasswordToggle ? _obscure : widget.obscureText;

    final eyeButton = widget.showPasswordToggle
        ? IconButton(
            tooltip: hidden ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              hidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.iconGrey,
            ),
          )
        : null;

    final Widget? suffix;
    if (widget.showValidCheckmark) {
      const check = Padding(
        padding: EdgeInsets.only(left: 4, right: 2),
        child: Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 22,
        ),
      );
      if (eyeButton != null) {
        suffix = Row(
          mainAxisSize: MainAxisSize.min,
          children: [check, eyeButton],
        );
      } else if (widget.suffixIcon != null) {
        suffix = Row(
          mainAxisSize: MainAxisSize.min,
          children: [check, widget.suffixIcon!],
        );
      } else {
        suffix = check;
      }
    } else if (eyeButton != null) {
      suffix = eyeButton;
    } else {
      suffix = widget.suffixIcon;
    }

    final decoration = InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      suffixIcon: suffix,
      errorStyle: widget.collapseValidationMessage
          ? const TextStyle(fontSize: 0, height: 0, color: AppColors.transparent)
          : null,
    );

    // null = let ancestor Form drive autovalidate (such as after submit))
    final mode = widget.autovalidateMode ??
        (widget.validator != null ? null : AutovalidateMode.disabled);

    return TextFormField(
      key: widget.formFieldKey,
      focusNode: widget.focusNode,
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: hidden,
      validator: widget.validator,
      autovalidateMode: mode,
      autocorrect: widget.autocorrect,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      onTapOutside: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      decoration: decoration,
    );
  }
}
