import 'package:flutter/material.dart';

class SwipeActionBackground extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final Color color;
  final Color foregroundColor;

  const SwipeActionBackground({
    super.key,
    required this.alignment,
    required this.icon,
    required this.color,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: Icon(icon, color: foregroundColor, size: 24),
    );
  }
}
