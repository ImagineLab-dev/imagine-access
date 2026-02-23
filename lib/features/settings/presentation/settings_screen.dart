import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/glass_scaffold.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_roles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/i18n/locale_provider.dart';
import 'package:imagine_access/features/dashboard/data/dashboard_repository.dart';
import 'package:imagine_access/features/auth/presentation/auth_controller.dart';
import 'package:imagine_access/features/settings/data/settings_repository.dart';
import 'package:imagine_access/features/events/data/event_repository.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyAsync = ref.watch(defaultCurrencyProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(userRoleProvider);

    return GlassScaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Global Config
          Text(l10n.general,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppTheme.accentBlue)),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.defaultCurrency),
                Consumer(builder: (ctx, ref, _) {
                  final isDark = theme.brightness == Brightness.dark;
                  final dropdownColor = isDark ? Colors.black87 : Colors.white;
                  final textColor = isDark ? Colors.white : Colors.black87;

                  return DropdownButton<String>(
                      value: currencyAsync.value ?? 'PYG',
                      dropdownColor: dropdownColor,
                      style: TextStyle(color: textColor, fontSize: 16),
                      underline: const SizedBox(),
                      iconEnabledColor:
                          isDark ? Colors.white70 : Colors.black87,
                      items: [
                        DropdownMenuItem(
                            value: 'PYG',
                            child: Text('GS (PYG)',
                                style: TextStyle(color: textColor))),
                        DropdownMenuItem(
                            value: 'USD',
                            child: Text('USD (\$ )',
                                style: TextStyle(color: textColor))),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await ref
                              .read(settingsRepositoryProvider)
                              .updateDefaultCurrency(val);
                          ref.invalidate(defaultCurrencyProvider);
                        }
                      });
                })
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Theme Mode Toggle
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.brightness_6, color: AppTheme.accentBlue),
                    const SizedBox(width: 12),
                    Text(l10n.themeMode),
                  ],
                ),
                Consumer(builder: (ctx, ref, _) {
                  final themeMode = ref.watch(themeNotifierProvider);
                  final isDark = themeMode == ThemeMode.dark;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isDark ? 'Dark' : 'Light',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(width: 8),
                      Switch(
                        value: isDark,
                        onChanged: (val) {
                          ref
                              .read(themeNotifierProvider.notifier)
                              .setTheme(val ? ThemeMode.dark : ThemeMode.light);
                        },
                        activeColor: AppTheme.neonBlue,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Language Selector
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.language, color: AppTheme.accentBlue),
                    const SizedBox(width: 12),
                    Text(l10n.language),
                  ],
                ),
                Consumer(builder: (ctx, ref, _) {
                  final locale = ref.watch(localeProvider);
                  final isDark = theme.brightness == Brightness.dark;
                  final dropdownColor = isDark ? Colors.black87 : Colors.white;
                  final textColor = isDark ? Colors.white : Colors.black87;

                  return DropdownButton<String>(
                    value: locale.languageCode,
                    dropdownColor: dropdownColor,
                    style: TextStyle(color: textColor, fontSize: 16),
                    underline: const SizedBox(),
                    iconEnabledColor: isDark ? Colors.white70 : Colors.black87,
                    items: [
                      DropdownMenuItem(
                          value: 'en',
                          child: Text('🇺🇸 English',
                              style: TextStyle(color: textColor))),
                      DropdownMenuItem(
                          value: 'es',
                          child: Text('🇪🇸 Español',
                              style: TextStyle(color: textColor))),
                      DropdownMenuItem(
                          value: 'pt',
                          child: Text('🇧🇷 Português',
                              style: TextStyle(color: textColor))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref
                            .read(localeProvider.notifier)
                            .changeLocale(Locale(val));
                      }
                    },
                  );
                }),
              ],
            ),
          ),

          if (role == AppRoles.admin) ...[
            const SizedBox(height: 32),

            // 2. Access Management
            Text(l10n.accessControl,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: AppTheme.accentBlue)),
            const SizedBox(height: 12),

            _SettingsTile(
              icon: Icons.people,
              title: l10n.userManagement,
              subtitle: l10n.userManagementDesc,
              onTap: () => context.push('/settings/users'),
            ),

            const SizedBox(height: 12),

            _SettingsTile(
              icon: Icons.devices,
              title: l10n.deviceManagement,
              subtitle: l10n.deviceManagementDesc,
              onTap: () => context.push('/settings/devices'),
            ),
          ],

          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.refresh,
            title: l10n.forceRefresh,
            subtitle: l10n.language == 'Español'
                ? 'Recargar datos e interfaz'
                : 'Reload locale & data',
            onTap: () async {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.refreshing)));

              // Force invalidate providers
              ref.invalidate(localeProvider);
              ref.invalidate(themeNotifierProvider);
              ref.invalidate(defaultCurrencyProvider);
              ref.invalidate(eventsProvider); // Reload events list
              ref.invalidate(dashboardMetricsProvider); // Reset metrics

              await Future.delayed(const Duration(seconds: 1)); // UX delay

              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.language == 'Español'
                        ? '¡Actualizado!'
                        : 'Updated!'),
                    backgroundColor: Colors.green));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const _SettingsTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap,
      // ignore: unused_element_parameter
      this.color = AppTheme.neonBlue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: color)),
                Text(subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey)
        ],
      ),
    );
  }
}
