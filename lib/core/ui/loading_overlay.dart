import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../theme/app_theme.dart';

final loadingProvider = StateProvider<bool>((ref) => false);

class LoadingOverlay extends ConsumerWidget {
  final Widget child;
  const LoadingOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(loadingProvider);
    final theme = Theme.of(context);
    
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: const CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppTheme.neonBlue,
                        ),
                      ).animate(onPlay: (controller) => controller.repeat())
                       .shimmer(duration: 1500.ms, color: AppTheme.neonBlue.withOpacity(0.3)),
                      const SizedBox(height: 24),
                      Text(
                        'PROCESANDO',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ).animate()
                       .fadeIn(duration: 400.ms)
                       .scale(begin: const Offset(0.9, 0.9)),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 200.ms),
      ],
    );
  }
}
