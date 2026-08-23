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
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
            child: _StepEntrance(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
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
                  if (content != null) ...[
                    const SizedBox(height: 4),
                    content!,
                  ],
                ],
              ),
            ),
          ),
        ),
        AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            32,
            12,
            32,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            spacing: 8,
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

class _StepEntrance extends StatelessWidget {
  final Widget child;

  const _StepEntrance({required this.child});

  @override
  Widget build(BuildContext context) {
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
}

class TutorialStepBadge extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double size;

  const TutorialStepBadge({
    super.key,
    required this.child,
    this.color,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [tint.withAlpha(46), tint.withAlpha(0)],
        ),
      ),
      child: Center(child: child),
    );
  }
}

class TutorialPopIn extends StatelessWidget {
  final Widget child;

  const TutorialPopIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.scale(scale: t, child: child),
        );
      },
      child: child,
    );
  }
}
