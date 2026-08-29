import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:flutter/material.dart';

/// Shows a [SnackBar] whenever [viewModel] queues a
/// [BaseViewModel.pendingUserMessage] (error or success), then marks it as
/// consumed so it is not shown again on the next rebuild.
///
/// This is the one place in the app that turns a ViewModel's message into
/// an actual snackbar, so every screen gets the same look, timing and
/// consume-once behaviour instead of each View re-implementing its own
/// try/catch-and-show-a-snackbar logic.
///
/// Usage: wrap the widget a screen's `build()` already returns —
/// `ViewModelFeedback(viewModel: _viewModel, child: ListenableBuilder(...))`
/// — [child] does not need to be listening to the same ViewModel already,
/// this widget listens independently.
class ViewModelFeedback extends StatefulWidget {
  const ViewModelFeedback({
    super.key,
    required this.viewModel,
    required this.child,
  });

  final BaseViewModel viewModel;
  final Widget child;

  @override
  State<ViewModelFeedback> createState() => _ViewModelFeedbackState();
}

class _ViewModelFeedbackState extends State<ViewModelFeedback> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(covariant ViewModelFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_handleChange);
      widget.viewModel.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    final message = widget.viewModel.pendingUserMessage;
    if (message == null) return;
    widget.viewModel.consumeUserMessage();

    // Showing a SnackBar is a side effect: defer it to after the current
    // frame so it never runs while a rebuild triggered by the same
    // notifyListeners() call is still in progress.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAppSnackBar(context, message: message.resolve(context), type: message.type);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
