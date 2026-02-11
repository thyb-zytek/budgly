import 'package:flutter/material.dart';
import 'tab_switcher.dart';

class SwipeTabs extends StatefulWidget {
  final int initialIndex;
  final List<Widget> children;
  final List<Widget> tabs;
  final ValueChanged<int>? onIndexChanged;

  const SwipeTabs({
    super.key,
    this.initialIndex = 0,
    required this.children,
    required this.tabs,
    this.onIndexChanged,
  }) : assert(
         children.length == tabs.length,
         'Children and tabs must have the same length',
       );

  @override
  State<SwipeTabs> createState() => _SwipeTabsState();
}

class _SwipeTabsState extends State<SwipeTabs> with TickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;
  late TabController _tabController;
  Duration _animationDuration = const Duration(milliseconds: 500);
  Curve _animationCurve = Curves.fastLinearToSlowEaseIn;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.children.length - 1);
    _pageController = PageController(
      initialPage: _currentIndex,
      keepPage: false,
    );
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: _currentIndex,
    );
  }

  @override
  void didUpdateWidget(SwipeTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex &&
        widget.initialIndex != _currentIndex) {
      _handleTabChange(widget.initialIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int index) {
    if (_currentIndex == index) return;

    _pageController
        .animateToPage(
          index,
          duration: _animationDuration,
          curve: _animationCurve,
        )
        .then((_) {
          setState(() => _currentIndex = index);
          widget.onIndexChanged?.call(index);
        });
  }

  void _handleTabChange(int index) {
    if (_currentIndex == index) return;

    _tabController.animateTo(
      index,
      duration: _animationDuration,
      curve: _animationCurve,
    );

    _pageController.jumpToPage(index);

    setState(() => _currentIndex = index);
    widget.onIndexChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: _handlePageChanged,
            physics: const BouncingScrollPhysics(),
            pageSnapping: true,
            children: widget.children,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: TabSwitcher(
            selectedIndex: _currentIndex,
            onTabSelected: _handleTabChange,
            tabs: widget.tabs,
          ),
        ),
      ],
    );
  }
}
