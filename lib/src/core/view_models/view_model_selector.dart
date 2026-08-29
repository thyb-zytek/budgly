import 'package:flutter/widgets.dart';

typedef ViewModelValueSelector<TModel extends Listenable, TValue> =
    TValue Function(TModel model);

typedef ViewModelValueBuilder<TValue> = Widget Function(
  BuildContext context,
  TValue value,
);

class ViewModelSelector<TModel extends Listenable, TValue> extends StatefulWidget {
  final TModel model;
  final ViewModelValueSelector<TModel, TValue> selector;
  final ViewModelValueBuilder<TValue> builder;

  const ViewModelSelector({
    super.key,
    required this.model,
    required this.selector,
    required this.builder,
  });

  @override
  State<ViewModelSelector<TModel, TValue>> createState() =>
      _ViewModelSelectorState<TModel, TValue>();
}

class _ViewModelSelectorState<TModel extends Listenable, TValue>
    extends State<ViewModelSelector<TModel, TValue>> {
  late TValue _value;

  @override
  void initState() {
    super.initState();
    _value = widget.selector(widget.model);
    widget.model.addListener(_onModelChanged);
  }

  @override
  void didUpdateWidget(ViewModelSelector<TModel, TValue> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.model, widget.model)) {
      oldWidget.model.removeListener(_onModelChanged);
      _value = widget.selector(widget.model);
      widget.model.addListener(_onModelChanged);
      return;
    }

    final nextValue = widget.selector(widget.model);
    if (nextValue != _value) {
      _value = nextValue;
    }
  }

  void _onModelChanged() {
    if (!mounted) return;
    final nextValue = widget.selector(widget.model);
    if (nextValue == _value) return;
    setState(() => _value = nextValue);
  }

  @override
  void dispose() {
    widget.model.removeListener(_onModelChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
