import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isLoading;
  final bool isSecondary;

  const NeonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.color,
    this.isLoading = false,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final baseColor = color ?? (isSecondary 
        ? (isDark ? Colors.white : Colors.black87) 
        : AppTheme.primaryColor);
        
    final textColor = isSecondary 
        ? (isDark ? Colors.white : Colors.black87) 
        : Colors.black;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed == null || isSecondary
            ? []
            : [
                BoxShadow(
                  color: baseColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: isLoading || onPressed == null 
          ? null 
          : () {
              HapticFeedback.lightImpact();
              onPressed!();
            },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? Colors.transparent : baseColor,
          foregroundColor: textColor,
          disabledBackgroundColor: isSecondary ? Colors.transparent : baseColor.withOpacity(0.5),
          shadowColor: Colors.transparent,
          side: isSecondary 
              ? BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.2), width: 1.5) 
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: textColor,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    )
    .animate(target: onPressed == null ? 0 : 1)
    .shimmer(
      duration: 1800.ms, 
      color: Colors.white.withOpacity(0.15),
      stops: [0, 0.5, 1],
    )
    .scale(
      begin: const Offset(1, 1),
      end: const Offset(0.98, 0.98),
      duration: 100.ms,
      curve: Curves.easeInOut,
    );
  }
}
