import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:imagine_access/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/glass_scaffold.dart';
import '../../../core/ui/neon_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final textColor = isDark ? AppTheme.darkText : AppTheme.lightText;
    final secondaryText = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;

    return GlassScaffold(
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final frameHeight = constraints.maxHeight > 820
                ? 820.0
                : constraints.maxHeight;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  constraints: BoxConstraints(minHeight: frameHeight),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    color: (isDark ? Colors.black : Colors.white)
                        .withValues(alpha: isDark ? 0.2 : 0.55),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.09),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                        blurRadius: 26,
                        spreadRadius: -14,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: _BackgroundOrbs(),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 130,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(34),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(34),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 22,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 94,
                                  height: 94,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppTheme.primaryColor.withValues(alpha: 0.35),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.accentBlue,
                                        AppTheme.neonBlue,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: isDark ? 0.35 : 0.2),
                                        blurRadius: 24,
                                        spreadRadius: -8,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Stack(
                                    children: [
                                      Positioned(
                                        top: -20,
                                        left: 12,
                                        right: 12,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0x33FFFFFF),
                                          ),
                                          child: SizedBox(height: 30),
                                        ),
                                      ),
                                      Center(
                                        child: Icon(
                                          Icons.qr_code_scanner_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ).animate().scale(
                                  duration: 400.ms,
                                  curve: Curves.easeOutBack,
                                ),
                            const SizedBox(height: 18),
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isDark
                                    ? [
                                        Colors.white,
                                        Colors.white.withValues(alpha: 0.7),
                                      ]
                                    : [
                                        textColor,
                                        textColor.withValues(alpha: 0.7),
                                      ],
                              ).createShader(bounds),
                              child: Text(
                                l10n.appTitle,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                  color: Colors.white,
                                  fontSize: 40,
                                  height: 1.05,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ).animate().fade().slideY(begin: 0.2, end: 0),
                            const SizedBox(height: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 270),
                              child: Text(
                                l10n.welcomeTagline,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: secondaryText,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 13.5,
                                ),
                              ),
                            ).animate().fade(delay: 120.ms),
                            const SizedBox(height: 22),
                            GlassCard(
                              borderRadius: BorderRadius.circular(26),
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l10n.welcomeMainFeatures,
                                          style: theme.textTheme.labelLarge?.copyWith(
                                            color: secondaryText,
                                            fontSize: 11,
                                            letterSpacing: 1,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 34,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppTheme.accentBlue,
                                              AppTheme.accentPurple,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  GridView.count(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    childAspectRatio: 1.18,
                                    children: [
                                      _FeatureTile(
                                        icon: Icons.confirmation_number_outlined,
                                        text: l10n.createTicket,
                                        accent: AppTheme.accentBlue,
                                      ),
                                      _FeatureTile(
                                        icon: Icons.qr_code_scanner,
                                        text: l10n.scanner,
                                        accent: AppTheme.accentPurple,
                                      ),
                                      _FeatureTile(
                                        icon: Icons.bar_chart_rounded,
                                        text: l10n.reports,
                                        accent: AppTheme.accentGreen,
                                      ),
                                      _FeatureTile(
                                        icon: Icons.group_outlined,
                                        text: l10n.manageTeam,
                                        accent: AppTheme.accentOrange,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ).animate().fade(delay: 180.ms).slideY(begin: 0.08, end: 0),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 56,
                              child: NeonButton(
                                text: l10n.adminRRPP,
                                icon: Icons.shield_outlined,
                                onPressed: () => context.go('/login?mode=admin'),
                              ),
                            ).animate().fade(delay: 220.ms),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 54,
                              child: NeonButton(
                                text: l10n.doorAccess,
                                icon: Icons.meeting_room_outlined,
                                isSecondary: true,
                                onPressed: () => context.go('/login?mode=door'),
                              ),
                            ).animate().fade(delay: 260.ms),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _PulsingDot(
                                  width: 8,
                                  height: 8,
                                  color: AppTheme.accentGreen,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.systemOnline,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: secondaryText,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.15,
                                  ),
                                ),
                              ],
                            ).animate().fade(delay: 300.ms),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BackgroundOrbs extends StatelessWidget {
  const _BackgroundOrbs();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 40,
          left: -40,
          child: _Orb(
            size: 180,
            color: AppTheme.accentBlue.withValues(alpha: 0.14),
            durationMs: 4200,
          ),
        ),
        Positioned(
          bottom: 170,
          right: -35,
          child: _Orb(
            size: 160,
            color: AppTheme.accentPurple.withValues(alpha: 0.10),
            durationMs: 5000,
          ),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final int durationMs;

  const _Orb({
    required this.size,
    required this.color,
    required this.durationMs,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1.06),
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      onEnd: () {},
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true));
  }
}

class _PulsingDot extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _PulsingDot({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.55),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(begin: 0.85, end: 1.1, duration: 900.ms)
        .fade(begin: 0.7, end: 1.0, duration: 900.ms);
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;

  const _FeatureTile({
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
            blurRadius: 16,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: accent.withValues(alpha: 0.16),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const Spacer(),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white.withValues(alpha: 0.92) : null,
                fontSize: 13,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
