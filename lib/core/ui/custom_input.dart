import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final IconData? icon; // Alias for prefixIcon
  final String? prefixText; // New property
  final String? initialValue;
  final bool enabled;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? prefixWidget; // New property

  const CustomInput({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.icon,
    this.prefixText,
    this.initialValue,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.prefixWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.grey).withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            initialValue: controller == null ? initialValue : null,
            enabled: enabled,
            keyboardType: keyboardType,
            obscureText: obscureText,
            validator: validator,
            onChanged: onChanged,
            style: TextStyle(
              color: enabled 
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? Colors.white60 : Colors.black38),
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              prefixText: prefixText,
              prefixStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54, 
                  fontWeight: FontWeight.bold,
                  fontSize: 16
              ),
              prefixIcon: prefixWidget ?? ((prefixIcon ?? icon) != null 
                  ? Icon(
                      prefixIcon ?? icon, 
                      color: enabled 
                        ? (isDark ? Colors.white54 : Colors.black45)
                        : (isDark ? Colors.white24 : Colors.black26)
                    )
                  : null),
              fillColor: isDark 
                ? AppTheme.surfaceColor.withOpacity(enabled ? 0.5 : 0.2)
                : AppTheme.lightInput,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
