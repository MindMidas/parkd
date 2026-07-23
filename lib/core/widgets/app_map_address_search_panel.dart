import 'dart:async';

import 'package:flutter/material.dart';

import '../models/search_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';
import 'app_divider.dart';
import 'app_map_search_card.dart';
import 'app_map_search_field.dart';

// Floating card search + results; searchFn swaps geocoding vs other sources
class AppMapAddressSearchPanel extends StatefulWidget {
  const AppMapAddressSearchPanel({
    super.key,
    required this.searchFn,
    required this.onResultSelected,
    this.controller,
    this.hintText = 'Search city or address…',
    this.showFilterButton = false,
    this.onFilterTap,
  });

  final TextEditingController? controller;

  // Addresses only (not your app’s listing search)
  final Future<List<SearchResult>> Function(String query) searchFn;

  final ValueChanged<SearchResult> onResultSelected;
  final String hintText;
  final bool showFilterButton;
  final VoidCallback? onFilterTap;

  @override
  State<AppMapAddressSearchPanel> createState() =>
      _AppMapAddressSearchPanelState();
}

class _AppMapAddressSearchPanelState extends State<AppMapAddressSearchPanel> {
  late TextEditingController _controller;
  Timer? _debounce;

  // Freeze field text after pick so we don’t re-search the same string
  String? _committedSearchLabel;
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  bool _searchFailed = false;
  int _searchGeneration = 0;
  String _lastQuery = '';

  static const _debounceMs = 500;
  static const _searchTimeout = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    final q = query.trim();
    if (q.isEmpty) {
      _committedSearchLabel = null;
      setState(() {
        _searchResults = [];
        _showResults = false;
        _isSearching = false;
        _searchFailed = false;
      });
      return;
    }
    if (_committedSearchLabel != null) {
      if (q == _committedSearchLabel) {
        setState(() {
          _searchResults = [];
          _showResults = false;
          _isSearching = false;
          _searchFailed = false;
        });
        return;
      }
      _committedSearchLabel = null;
    }
    setState(() {
      _isSearching = true;
      _searchFailed = false;
      _lastQuery = q;
    });
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      _runSearch(q, generation);
    });
  }

  Future<void> _runSearch(String query, int generation) async {
    try {
      final results = await widget.searchFn(query).timeout(_searchTimeout);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchResults = results;
        _showResults = results.isNotEmpty;
        _isSearching = false;
        _searchFailed = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchResults = [];
        _showResults = false;
        _isSearching = false;
        _searchFailed = true;
      });
    }
  }

  void _retrySearch() {
    final query = _lastQuery.trim();
    if (query.isEmpty) return;
    final generation = ++_searchGeneration;
    setState(() {
      _isSearching = true;
      _searchFailed = false;
    });
    _runSearch(query, generation);
  }

  void _onResultTapped(SearchResult result) {
    final label = result.displayName.trim();
    _committedSearchLabel = label;
    _debounce?.cancel();
    setState(() {
      _showResults = false;
      _searchResults = [];
      _isSearching = false;
      _searchFailed = false;
    });
    _controller.value = TextEditingValue(
      text: result.displayName,
      selection: TextSelection.collapsed(offset: result.displayName.length),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onResultSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    final maxResultsHeight = (MediaQuery.sizeOf(context).height * 0.42).clamp(
      220.0,
      400.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppMapSearchField(
          controller: _controller,
          hintText: widget.hintText,
          onChanged: _onSearchChanged,
          showFilterButton: widget.showFilterButton,
          onFilterTap: widget.onFilterTap,
          isLoading: _isSearching,
        ),
        if (_searchFailed && !_isSearching) ...[
          const SizedBox(height: AppSpacing.xs),
          AppMapSearchCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 20,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Address search is unavailable.',
                      style: AppTypography.caption,
                    ),
                  ),
                  AppPrimaryButton(
                    label: 'Retry',
                    fullWidth: false,
                    compact: true,
                    onPressed: _retrySearch,
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_showResults && _searchResults.isNotEmpty && !_isSearching) ...[
          const SizedBox(height: AppSpacing.xs),
          AppMapSearchCard(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxResultsHeight),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) => const AppDividerWide(),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  final (title, subtitle) = result.listTitleAndSubtitle;
                  return Material(
                    color: AppColors.surface,
                    child: InkWell(
                      onTap: () => _onResultTapped(result),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.location_on_outlined,
                                color: AppColors.primaryBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (title.isNotEmpty)
                                    Text(
                                      title,
                                      style: AppTypography.bodySecondary
                                          .copyWith(
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary,
                                            height: 1.25,
                                          ),
                                    ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: AppTypography.caption.copyWith(
                                        height: 1.25,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (title.isEmpty && subtitle.isEmpty)
                                    Text(
                                      result.displayName,
                                      style: AppTypography.bodySecondary
                                          .copyWith(
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary,
                                            height: 1.25,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}
