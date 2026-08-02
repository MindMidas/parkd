import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_page_status.dart';

// Maps AsyncValue to shared loading/empty/error/data chrome.
class AppAsyncBody<T> extends StatelessWidget {
  const AppAsyncBody({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyIcon,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.errorTitle,
    this.errorMessage,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool Function(T data)? isEmpty;
  final String emptyTitle;
  final String? emptyMessage;
  final IconData? emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final String? errorTitle;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const AppPageStatus.loading(),
      error: (_, _) => AppPageStatus.error(
        title: errorTitle ?? 'Something went wrong',
        message: errorMessage ?? 'Check your connection and try again.',
        actionLabel: onRetry != null ? retryLabel : null,
        onAction: onRetry,
      ),
      data: (item) {
        if (isEmpty != null && isEmpty!(item)) {
          return AppPageStatus.empty(
            title: emptyTitle,
            message: emptyMessage,
            icon: emptyIcon,
            actionLabel: emptyActionLabel,
            onAction: onEmptyAction,
          );
        }
        return data(item);
      },
    );
  }
}
