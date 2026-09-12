import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class TutorialStepScaffold extends StatelessWidget {
  final Widget? badge;
  final String title;
  final String subtitle;
  final Widget? content;
  final Widget primaryAction;
  final Widget? secondaryAction;

  const TutorialStepScaffold({
    super.key,
    this.badge,
    required this.title,
    required this.subtitle,
    this.content,
    required this.primaryAction,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(BudglySpacing.xxl, BudglySpacing.sm, BudglySpacing.xxl, BudglySpacing.lg),
            child: _buildStepEntrance(
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BudglySpacing.xl,
                children: [
                  if (badge != null) Center(child: badge!),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  ?content,
                ],
              ),
            ),
          ),
        ),
        AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            BudglySpacing.xxl,
            BudglySpacing.md,
            BudglySpacing.xxl,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            spacing: BudglySpacing.sm,
            children: [
              primaryAction,
              ?secondaryAction,
            ],
          ),
        ),
      ],
    );
  }
}

Widget _buildStepEntrance(Widget child) {
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
    builder: (context, t, child) {
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      );
    },
    child: child,
  );
}

