import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// Shared Riverpod feedback widget
/// for one-shot messages emitted by migrated Notifiers.
///
/// Shows a [SnackBar] whenever [messageListenable] fires a non-null value,
/// then calls [onConsume] so it is not shown again on the next rebuild —
/// the same consume-once contract. Built on
/// `ref.listen`, Riverpod's idiomatic mechanism for one-shot side effects
/// triggered by a state transition (as opposed to `ref.watch`, which is for
/// values the build method itself needs).
///
/// Usage: wrap what a migrated page's `build()` already returns —
/// ```dart
/// RiverpodFeedback(
///   messageListenable: profileSettingsProvider.select((s) => s.pendingMessage),
///   onConsume: (ref) => ref.read(profileSettingsProvider.notifier).consumeMessage(),
///   child: ...,
/// )
/// ```
class RiverpodFeedback extends ConsumerWidget {
  const RiverpodFeedback({
    super.key,
    required this.messageListenable,
    required this.onConsume,
    required this.child,
  });

  final ProviderListenable<AppUserMessage?> messageListenable;
  final void Function(WidgetRef ref) onConsume;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(messageListenable, (previous, next) {
      if (next == null) return;
      onConsume(ref);

      // Showing a SnackBar is a side effect: defer it to after the current
      // frame so it never runs while the rebuild that produced this message
      // is still in progress. the same lifecycle reasoning.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showAppSnackBar(
          context,
          message: next.resolve(context),
          type: next.type,
        );
      });
    });
    return child;
  }
}
