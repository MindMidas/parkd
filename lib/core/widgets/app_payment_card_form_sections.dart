// Titled outline sections for add/edit payment card forms
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_display_fields.dart';
import 'app_segment_control.dart';
import 'app_text_field.dart';

// Card brand + number, name, expiry, CVV in one titled outline card
class AppPaymentCardDetailsFieldsCard extends StatelessWidget {
  const AppPaymentCardDetailsFieldsCard({
    super.key,
    this.title = 'Card fields',
    required this.selectedBrand,
    required this.onBrandChanged,
    required this.numberController,
    required this.nameController,
    required this.expiryController,
    required this.cvvController,
    this.editingLastFour,
  });

  final String title;
  final String selectedBrand;
  final ValueChanged<String> onBrandChanged;
  final TextEditingController numberController;
  final TextEditingController nameController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;

  // edit flow: leave number empty to keep existing last four on file
  final String? editingLastFour;

  @override
  Widget build(BuildContext context) {
    return AppDisplayTitledOutlineCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Card type', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          AppSegmentControl<String>(
            selected: selectedBrand,
            onChanged: onBrandChanged,
            options: const [
              AppSegmentOption(
                value: 'Visa',
                label: 'Visa',
                icon: Icons.credit_card_rounded,
              ),
              AppSegmentOption(
                value: 'Mastercard',
                label: 'Mastercard',
                icon: Icons.credit_card_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: numberController,
            label: 'Card number',
            hint: editingLastFour != null
                ? 'Leave blank to keep •••• $editingLastFour'
                : '1234 5678 9012 3456',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
              LengthLimitingTextInputFormatter(19),
            ],
            validator: (v) {
              final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
              if (editingLastFour != null && d.isEmpty) return null;
              return d.length >= 13 ? null : 'Enter card number';
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: nameController,
            label: 'Cardholder name',
            hint: 'Name on card',
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: expiryController,
                  label: 'Expiry (MM/YY)',
                  hint: '09/28',
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [LengthLimitingTextInputFormatter(5)],
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(s)) {
                      return 'Use MM/YY';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  controller: cvvController,
                  label: 'CVV',
                  hint: '123',
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.length < 3) return 'Required';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Street, city, postal in one titled outline card
class AppBillingAddressFieldsCard extends StatelessWidget {
  const AppBillingAddressFieldsCard({
    super.key,
    this.title = 'Billing address',
    required this.streetController,
    required this.cityController,
    required this.postalController,
  });

  final String title;
  final TextEditingController streetController;
  final TextEditingController cityController;
  final TextEditingController postalController;

  @override
  Widget build(BuildContext context) {
    return AppDisplayTitledOutlineCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: streetController,
            label: 'Street address',
            hint: '123 Main St',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: cityController,
            label: 'City',
            hint: 'City',
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: postalController,
            label: 'Postal code',
            hint: 'A1A 1A1',
            textCapitalization: TextCapitalization.characters,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ],
      ),
    );
  }
}
