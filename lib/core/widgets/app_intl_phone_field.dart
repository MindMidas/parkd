import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/country_picker_dialog.dart'
    show PickerDialogStyle;
import 'package:intl_phone_field/phone_number.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/nanp_phone_input_formatter.dart';
import 'app_country_picker_dialog.dart';

bool _isNanp(Country country) => country.code == 'CA' || country.code == 'US';

String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

// Parse E.164 into country ISO + national digits for prefilling the field
({String iso, String nationalDigits})? decodeE164ForIntlPhoneField(
  String? e164,
) {
  if (e164 == null || e164.trim().isEmpty) return null;
  var d = _digitsOnly(e164);
  if (d.isEmpty) return null;
  final sorted = List<Country>.from(countries)
    ..sort((a, b) {
      final la = _digitsOnly(a.dialCode).length;
      final lb = _digitsOnly(b.dialCode).length;
      return lb.compareTo(la);
    });
  for (final c in sorted) {
    final dc = _digitsOnly(c.dialCode);
    if (dc.isNotEmpty && d.startsWith(dc)) {
      final national = d.substring(dc.length);
      return (iso: c.code, nationalDigits: national);
    }
  }
  return null;
}

// Phone field + country picker; NANP formatting for CA/US; matches AppTextField theme
class AppIntlPhoneField extends StatefulWidget {
  const AppIntlPhoneField({
    super.key,
    required this.controller,
    required this.onPhoneChanged,
    this.enabled = true,
    this.initialCountryCode = 'CA',
    this.autovalidateMode,
    this.invalidNumberMessage,
    this.phoneRequired = true,
    this.labelText,
  });

  final TextEditingController controller;
  final ValueChanged<PhoneNumber> onPhoneChanged;
  final bool enabled;
  final String initialCountryCode;
  final AutovalidateMode? autovalidateMode;
  final String? invalidNumberMessage;

  // false = empty OK (e.g. optional on edit profile)
  final bool phoneRequired;

  // null -> "Phone number"
  final String? labelText;

  @override
  State<AppIntlPhoneField> createState() => _AppIntlPhoneFieldState();
}

class _AppIntlPhoneFieldState extends State<AppIntlPhoneField> {
  late Country _country;

  @override
  void initState() {
    super.initState();
    _country = countries.firstWhere(
      (c) => c.code == widget.initialCountryCode,
      orElse: () => countries.firstWhere((c) => c.code == 'US'),
    );
    widget.controller.addListener(_emit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void didUpdateWidget(AppIntlPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_emit);
      widget.controller.addListener(_emit);
      _emit();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_emit);
    super.dispose();
  }

  void _emit() {
    final digits = _digitsOnly(widget.controller.text);
    widget.onPhoneChanged(
      PhoneNumber(
        countryISOCode: _country.code,
        countryCode: '+${_country.fullCountryCode}',
        number: digits,
      ),
    );
  }

  Future<void> _openPicker() async {
    if (!widget.enabled) {
      return;
    }
    final theme = Theme.of(context);
    final base = theme.inputDecorationTheme;
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AppCountryPickerDialog(
        languageCode: 'en',
        searchText: 'Search country',
        countryList: countries,
        selectedCountry: _country,
        filteredCountries: countries,
        style: PickerDialogStyle(
          backgroundColor: AppColors.surface,
          countryNameStyle: AppTypography.bodySecondary,
          countryCodeStyle: AppTypography.caption,
          searchFieldInputDecoration: InputDecoration(
            hintText: 'Search country',
          ).applyDefaults(base),
        ),
        onCountryChanged: (c) {
          setState(() {
            _country = c;
            widget.controller.clear();
          });
          _emit();
        },
      ),
    );
  }

  String? _syncValidator(String? value) {
    final digits = _digitsOnly(value ?? '');
    if (!widget.phoneRequired && digits.isEmpty) {
      return null;
    }
    if (digits.isEmpty) {
      return 'Enter your mobile number.';
    }
    if (digits.length < _country.minLength ||
        digits.length > _country.maxLength) {
      return widget.invalidNumberMessage ??
          'Enter a valid mobile number for this country.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.inputDecorationTheme;
    final nanp = _isNanp(_country);
    final bodyStyle = AppTypography.body;

    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.phone,
      autovalidateMode: widget.autovalidateMode,
      style: bodyStyle,
      onTapOutside: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      maxLength: nanp ? 14 : _country.maxLength,
      inputFormatters: nanp
          ? <TextInputFormatter>[NanpPhoneInputFormatter()]
          : <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_country.maxLength),
            ],
      decoration: InputDecoration(
        labelText: widget.labelText ?? 'Phone number',
        hintText: nanp ? '(234) 567-8901' : 'Mobile number',
        counterText: '',
        suffixIcon: Icon(
          Icons.smartphone_outlined,
          color: widget.enabled ? AppColors.iconGrey : AppColors.textSecondary,
        ),
        prefixIcon: _PhoneLeadingPrefix(
          country: _country,
          enabled: widget.enabled,
          onTap: _openPicker,
          dialLabel: '(+${_country.dialCode}) ',
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 0,
          minHeight: 52,
          maxHeight: 52,
        ),
      ).applyDefaults(base),
      validator: _syncValidator,
    );
  }
}

class _PhoneLeadingPrefix extends StatelessWidget {
  const _PhoneLeadingPrefix({
    required this.country,
    required this.enabled,
    required this.onTap,
    required this.dialLabel,
  });

  final Country country;
  final bool enabled;
  final VoidCallback onTap;
  final String dialLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kIsWeb)
                    Image.asset(
                      'assets/flags/${country.code.toLowerCase()}.png',
                      package: 'intl_phone_field',
                      width: 26,
                      height: 18,
                      fit: BoxFit.cover,
                    )
                  else
                    Text(country.flag, style: AppTypography.emojiFlagDense),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: enabled
                        ? AppColors.iconGrey
                        : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 26,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.secondaryGrey,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            dialLabel,
            style: AppTypography.bodySecondary.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
