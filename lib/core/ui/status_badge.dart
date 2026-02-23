import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BadgeStatus { success, warning, error, neutral }

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeStatus status;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    this.status = BadgeStatus.neutral,
    this.icon,
  });

  Color get _color {
    switch (status) {
      case BadgeStatus.success:
        return AppTheme.successColor;
      case BadgeStatus.warning:
        return AppTheme.warningColor;
      case BadgeStatus.error:
        return AppTheme.errorColor;
      case BadgeStatus.neutral:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 0,
            )
          ]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text.toUpperCase(),
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
                fontFamily: 'Inter' // Assuming configured
                ),
          ),
        ],
      ),
    );
  }
}
