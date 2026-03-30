import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_divider.dart';

// List rows with AppDividerWide between each (and one above the first row)
class AppDividerSeparatedListView extends StatelessWidget {
  const AppDividerSeparatedListView({
    super.key,
    required this.itemCount,
    required this.rowBuilder,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) rowBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: itemCount * 2 + 1,
      itemBuilder: (context, index) {
        if (index.isEven) {
          return const AppDividerWide();
        }
        return rowBuilder(context, index ~/ 2);
      },
    );
  }
}
