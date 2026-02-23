import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/glass_card.dart';
import '../../data/dashboard_repository.dart';

class RecentActivityList extends ConsumerWidget {
  const RecentActivityList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final activityAsync = ref.watch(recentActivityProvider);

    return activityAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Text(
        l10n.couldNotLoadActivity,
        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      ),
      data: (activities) {
        if (activities.isEmpty) {
          return Text(
            l10n.noRecentScans,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          );
        }

        // Show only last 3
        final latestItems = activities.take(3).toList();

        return GlassCard(
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: latestItems.length,
              separatorBuilder: (context, index) => Divider(
                indent: 70,
                endIndent: 20,
                height: 1,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              ),
              itemBuilder: (context, index) {
                final act = latestItems[index];
                final ticket = act['tickets'];
                final buyer = ticket != null ? ticket['buyer_name'] ?? 'Unknown' : 'Unknown';
                final result = act['result'] as String;
                final isSuccess = result == 'allowed' || result == 'Valid' || result == 'Granted';
                final time = DateTime.parse(act['scanned_at']).toLocal();
                final timeStr = "${time.hour}:${time.minute.toString().padLeft(2, '0')}";

                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? AppTheme.accentGreen.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSuccess ? Icons.check : Icons.close,
                      color: isSuccess ? AppTheme.accentGreen : Colors.red,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    (act['method'] as String? ?? 'SCAN').toUpperCase(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    '$buyer • por ${ticket?['users_profile']?['display_name'] ?? 'Sistema'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey : Colors.black54,
                    ),
                  ),
                  trailing: Text(
                    timeStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ).animate().slideX(delay: (200 + (index * 100)).ms);
              },
            ),
          ),
        );
      },
    );
  }
}
