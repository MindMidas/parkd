import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/country_picker_dialog.dart'
    show PickerDialogStyle;
import 'package:intl_phone_field/helpers.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';
import 'app_divider.dart';

// Country list dialog that actually scrolls (fork of intl_phone_field picker)
class AppCountryPickerDialog extends StatefulWidget {
  const AppCountryPickerDialog({
    super.key,
    required this.countryList,
    required this.selectedCountry,
    required this.onCountryChanged,
    required this.searchText,
    required this.filteredCountries,
    required this.languageCode,
    this.style,
  });

  final List<Country> countryList;
  final Country selectedCountry;
  final ValueChanged<Country> onCountryChanged;
  final String searchText;
  final List<Country> filteredCountries;
  final String languageCode;
  final PickerDialogStyle? style;

  @override
  State<AppCountryPickerDialog> createState() => _AppCountryPickerDialogState();
}

class _AppCountryPickerDialogState extends State<AppCountryPickerDialog> {
  late List<Country> _filteredCountries;

  @override
  void initState() {
    super.initState();
    _filteredCountries = widget.filteredCountries.toList()
      ..sort(
        (a, b) => a
            .localizedName(widget.languageCode)
            .compareTo(b.localizedName(widget.languageCode)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final mediaWidth = media.width;
    final width = widget.style?.width ?? mediaWidth;
    const horizontalPad = 40.0;
    const verticalPad = 24.0;
    final listHeight = (media.height * 0.55).clamp(280.0, 520.0);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        vertical: verticalPad,
        horizontal: mediaWidth > (width + horizontalPad * 2)
            ? (mediaWidth - width) / 2
            : horizontalPad,
      ),
      backgroundColor: widget.style?.backgroundColor ?? AppColors.surface,
      surfaceTintColor: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: SizedBox(
        width: width.clamp(280.0, mediaWidth - horizontalPad * 2),
        height: listHeight + 120,
        child: Padding(
          padding: widget.style?.padding ?? const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: widget.style?.searchFieldPadding ?? EdgeInsets.zero,
                child: TextField(
                  cursorColor: widget.style?.searchFieldCursorColor,
                  decoration:
                      widget.style?.searchFieldInputDecoration ??
                      InputDecoration(
                        suffixIcon: const Icon(Icons.search),
                        labelText: widget.searchText,
                      ),
                  onTapOutside: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  onChanged: (value) {
                    setState(() {
                      _filteredCountries =
                          widget.countryList.stringSearch(value)..sort(
                            (a, b) => a
                                .localizedName(widget.languageCode)
                                .compareTo(
                                  b.localizedName(widget.languageCode),
                                ),
                          );
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredCountries.length,
                  itemBuilder: (ctx, index) {
                    final c = _filteredCountries[index];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: kIsWeb
                              ? Image.asset(
                                  'assets/flags/${c.code.toLowerCase()}.png',
                                  package: 'intl_phone_field',
                                  width: 32,
                                )
                              : Text(
                                  c.flag,
                                  style: AppTypography.emojiFlagList,
                                ),
                          contentPadding: widget.style?.listTilePadding,
                          title: Text(
                            c.localizedName(widget.languageCode),
                            style:
                                widget.style?.countryNameStyle ??
                                AppTypography.bodyStrong,
                          ),
                          trailing: Text(
                            '+${c.dialCode}',
                            style:
                                widget.style?.countryCodeStyle ??
                                AppTypography.bodyStrong,
                          ),
                          onTap: () {
                            widget.onCountryChanged(c);
                            Navigator.of(context).pop();
                          },
                        ),
                        widget.style?.listTileDivider ?? const AppDividerWide(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
