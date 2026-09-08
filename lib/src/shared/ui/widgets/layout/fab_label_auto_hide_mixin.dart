import 'dart:async';

import 'package:flutter/material.dart';

/// Auto-hides a [BudglyFab]'s label after a short delay, and lets the caller
/// dismiss it immediately (e.g. on tap).
///
/// This was previously duplicated (the `ValueNotifier` + `Timer` + dispose
/// dance) between the settings "add entity" FAB and the overview page's FAB.
/// Mix this in, call [startFabLabelAutoHide] from `initState`, call
/// [disposeFabLabelAutoHide] from `dispose`, and use [showFabLabel] as the
/// `valueListenable` for a [ValueListenableBuilder] around the FAB.
mixin FabLabelAutoHideMixin<T extends StatefulWidget> on State<T> {
  static const Duration _autoHideDelay = Duration(seconds: 8);

  final ValueNotifier<bool> showFabLabel = ValueNotifier(false);
  Timer? _fabLabelTimer;

  /// Call from `initState`. If [visible] is false there is nothing to hide
  /// later, so no timer is scheduled.
  void startFabLabelAutoHide({bool visible = true}) {
    showFabLabel.value = visible;
    if (!visible) return;
    _fabLabelTimer = Timer(_autoHideDelay, () {
      showFabLabel.value = false;
    });
  }

  /// Hides the label immediately and cancels the pending auto-hide, e.g.
  /// when the FAB is pressed.
  void dismissFabLabel() {
    showFabLabel.value = false;
    _fabLabelTimer?.cancel();
  }

  /// Call from `dispose`.
  void disposeFabLabelAutoHide() {
    _fabLabelTimer?.cancel();
    showFabLabel.dispose();
  }
}
