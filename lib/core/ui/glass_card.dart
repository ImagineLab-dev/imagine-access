import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool border;
  final double? height;
  final double? width;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.05,
    this.color,
    this.borderRadius,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.border = true,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderRadius = this.borderRadius ?? BorderRadius.circular(16);

    Widget content = Container(
      margin: margin,
      height: height,
      width: width,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? (isDark ? Colors.white : Colors.black).withOpacity(opacity),
              borderRadius: borderRadius,
              border: border
                  ? Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                      width: 1.0,
                    )
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }
    
    return content;
  }
}
