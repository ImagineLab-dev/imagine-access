import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/glass_card.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final int delay;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(delay: delay.ms).scale();
  }
}

class EliteMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subValue;
  final IconData icon;
  final Color color;
  final int delay;
  final double? progress;
  final Color? progressColor;

  const EliteMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subValue,
    required this.icon,
    required this.color,
    required this.delay,
    this.progress,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              if (progress != null)
                SizedBox(
                  width: 40,
                  height: 4,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                        (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        progressColor ?? color),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subValue,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(delay: delay.ms).scale();
  }
}

class ActionItem {
  final String text;
  final IconData icon;
  final String route;
  final Color? color;
  final bool isPrimary;

  const ActionItem(
    this.text,
    this.icon,
    this.route, {
    this.color,
    this.isPrimary = false,
  });
}

class QuickActions extends StatelessWidget {
  final List<ActionItem> actions;
  final VoidCallback? onActionBeforeNavigate;

  const QuickActions({
    super.key,
    required this.actions,
    this.onActionBeforeNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones Rápidas',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.8,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return ActionCard(
              action: action,
              onBeforeNavigate: onActionBeforeNavigate,
            );
          },
        ),
      ],
    );
  }
}

class ActionCard extends StatelessWidget {
  final ActionItem action;
  final VoidCallback? onBeforeNavigate;

  const ActionCard({
    super.key,
    required this.action,
    this.onBeforeNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = action.color ?? (isDark ? Colors.white : Colors.black);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          if (onBeforeNavigate != null) {
            onBeforeNavigate!();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: action.isPrimary
                ? Border.all(color: AppTheme.accentBlue.withOpacity(0.5), width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(16),
            gradient: action.isPrimary
                ? LinearGradient(
                    colors: [
                      AppTheme.accentBlue.withOpacity(0.1),
                      AppTheme.accentPurple.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                action.icon,
                size: 24,
                color: action.isPrimary
                    ? AppTheme.accentBlue
                    : baseColor.withOpacity(0.8),
              ),
              const SizedBox(height: 8),
              Text(
                action.text.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(delay: 200.ms, duration: 400.ms);
  }
}
