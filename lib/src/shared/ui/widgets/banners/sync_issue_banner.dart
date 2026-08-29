import 'dart:async';

import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:flutter/material.dart';

/// How long the success state stays visible before the banner dismisses itself.
const Duration _successBannerDuration = Duration(seconds: 5);

/// Slim, non-blocking banner shown when [SyncManager] has one or more
/// operations that have failed repeatedly (see
/// [SyncManager.stuckAfterAttempts]).
///
/// The app keeps retrying in the background — nothing is lost — but the
/// user needs to know that some of their data has not reached the server
/// yet instead of assuming everything is saved.
///
/// Tapping "Retry" forces a synchronization pass: the banner shows a loading
/// spinner, then a success state (auto-dismissed after a few seconds) when the
/// queue drains, or returns to the error state otherwise.
class SyncIssueBanner extends StatefulWidget {
  const SyncIssueBanner({super.key});

  @override
  State<SyncIssueBanner> createState() => _SyncIssueBannerState();
}

class _SyncIssueBannerState extends State<SyncIssueBanner> {
  bool _showSuccess = false;
  Timer? _successTimer;

  @override
  void initState() {
    super.initState();
    SyncManager.instance.addListener(_onSyncChanged);
  }

  @override
  void dispose() {
    SyncManager.instance.removeListener(_onSyncChanged);
    _successTimer?.cancel();
    super.dispose();
  }

  void _onSyncChanged() {
    if (!mounted) return;
    if (SyncManager.instance.hasStuckOperations && _showSuccess) {
      _cancelSuccessTimer();
      _showSuccess = false;
    }
    // SyncManager can notify during a build pass (a flush started from a
    // service constructor's registerHandler), so defer the rebuild to after
    // the current frame to avoid "setState() called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _retry() async {
    _cancelSuccessTimer();
    setState(() => _showSuccess = false);
    await SyncManager.instance.flush();
    if (!mounted) return;
    if (!SyncManager.instance.hasStuckOperations) {
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
    return ListenableBuilder(
      listenable: SyncManager.instance,
      builder: (context, _) {
        final stuck = SyncManager.instance.hasStuckOperations;
        final syncing = SyncManager.instance.isSyncing;
        if (!stuck && !_showSuccess) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final tr = AppLocalizations.of(context)!;

        final isLoading = syncing;
        final background = (isLoading || _showSuccess)
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.errorContainer;
        final foreground = (isLoading || _showSuccess)
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onErrorContainer;

        return Material(
          color: background,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BudglySpacing.lg,
                vertical: BudglySpacing.sm,
              ),
              child: Row(
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
                  const SizedBox(width: BudglySpacing.sm),
                  Expanded(
                    child: Text(
                      _showSuccess
                          ? tr.syncSuccessBanner
                          : isLoading
                          ? tr.syncSyncingBanner
                          : tr.syncIssueBanner,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground,
                      ),
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
          ),
        );
      },
    );
  }
}
