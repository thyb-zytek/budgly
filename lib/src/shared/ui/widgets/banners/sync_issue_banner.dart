import 'dart:async';

import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/services/offline/sync_manager_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long the success state stays visible before the banner dismisses itself.
const Duration _successBannerDuration = Duration(seconds: 5);

/// Slim, non-blocking banner shown when [SyncStatusNotifier] reports one or
/// more operations that have failed repeatedly.
///
/// The app keeps retrying in the background — nothing is lost — but the
/// user needs to know that some of their data has not reached the server
/// yet instead of assuming everything is saved.
///
/// Tapping "Retry" forces a synchronization pass: the banner shows a loading
/// spinner, then a success state (auto-dismissed after a few seconds) when the
/// queue drains, or returns to the error state otherwise.
class SyncIssueBanner extends ConsumerStatefulWidget {
  const SyncIssueBanner({super.key});

  @override
  ConsumerState<SyncIssueBanner> createState() => _SyncIssueBannerState();
}

class _SyncIssueBannerState extends ConsumerState<SyncIssueBanner> {
  bool _showSuccess = false;
  Timer? _successTimer;

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    _cancelSuccessTimer();
    setState(() => _showSuccess = false);
    // An explicit user retry also gives permanently rejected operations
    // another chance (background triggers never replay them).
    await ref
        .read(syncManagerProvider)
        .flush(forceRetry: true, retryPermanent: true);
    if (!mounted) return;
    if (!ref.read(syncStatusProvider).hasStuckOperations) {
      setState(() => _showSuccess = true);
      _successTimer = Timer(_successBannerDuration, () {
        if (!mounted) return;
        setState(() => _showSuccess = false);
      });
    }
  }

  void _cancelSuccessTimer() {
    _successTimer?.cancel();
    _successTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    // A fresh failure while a previous success toast is still showing should
    // replace it with the error state immediately.
    ref.listen(syncStatusProvider, (_, next) {
      if (next.hasStuckOperations && _showSuccess) {
        _cancelSuccessTimer();
        setState(() => _showSuccess = false);
      }
    });

    final status = ref.watch(syncStatusProvider);
    if (!status.hasStuckOperations && !_showSuccess) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    final isLoading = status.isSyncing;
    final background = (isLoading || _showSuccess)
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.errorContainer;
    final foreground = (isLoading || _showSuccess)
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onErrorContainer;

    return Material(
      color: background,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: BudglySpacing.lg,
          vertical: BudglySpacing.sm,
        ),
        child: Row(
          spacing: BudglySpacing.sm,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else
              Icon(
                _showSuccess
                    ? Icons.check_circle_rounded
                    : Icons.sync_problem_rounded,
                color: foreground,
                size: 20,
              ),
            Expanded(
              child: Text(
                _showSuccess
                    ? tr.syncSuccessBanner
                    : isLoading
                    ? tr.syncSyncingBanner
                    : tr.syncIssueBanner,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ),
            if (!isLoading && !_showSuccess)
              TextButton(
                onPressed: _retry,
                child: Text(
                  tr.syncIssueRetry,
                  style: TextStyle(color: foreground),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
