import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_helper.dart';
import '../../../events/presentation/event_state.dart';
import '../../../settings/data/settings_repository.dart';
import 'dashboard_components.dart';

class AdminDashboardView extends ConsumerWidget {
  final Map<String, dynamic> metrics;

  const AdminDashboardView({super.key, required this.metrics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final defaultCurrency = ref.watch(defaultCurrencyProvider).value ?? 'PYG';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.75,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            MetricCard(
              title: l10n.totalTickets,
              value: (metrics['total_sold'] ?? 0).toString(),
              icon: Icons.confirmation_number_outlined,
              color: AppTheme.accentBlue,
              delay: 0,
            ),
            MetricCard(
              title: l10n.valid,
              value: (metrics['valid'] ?? 0).toString(),
              icon: Icons.check_circle_outline,
              color: AppTheme.accentGreen,
              delay: 100,
            ),
            MetricCard(
              title: l10n.scanned,
              value: (metrics['scanned'] ?? 0).toString(),
              icon: Icons.qr_code_scanner,
              color: AppTheme.accentPurple,
              delay: 200,
            ),
            MetricCard(
              title: l10n.sales,
              value: CurrencyHelper.format(
                  (metrics['revenue'] as num? ?? 0).toDouble(), defaultCurrency),
              icon: CurrencyHelper.getIcon(defaultCurrency),
              color: AppTheme.accentYellow,
              delay: 300,
            ),
            MetricCard(
              title: "${l10n.staff} (IN/TOT)",
              value:
                  "${metrics['staff_entered'] ?? 0} / ${metrics['staff_created'] ?? 0}",
              icon: Icons.badge_outlined,
              color: Colors.orangeAccent,
              delay: 400,
            ),
            MetricCard(
              title: "${l10n.guests} (IN/TOT)",
              value:
                  "${metrics['guest_entered'] ?? 0} / ${metrics['guest_created'] ?? 0}",
              icon: Icons.star_border,
              color: Colors.pinkAccent,
              delay: 500,
            ),
            MetricCard(
              title: "${l10n.normal} (IN/TOT)",
              value:
                  "${metrics['standard_entered'] ?? 0} / ${metrics['standard_created'] ?? 0}",
              icon: Icons.people_outline,
              color: Colors.cyanAccent,
              delay: 600,
            ),
            GestureDetector(
              onTap: () {
                final selectedEvent = ref.read(selectedEventProvider);
                if (selectedEvent != null) {
                  context.push('/stats/${selectedEvent['id']}');
                }
              },
              child: MetricCard(
                title: l10n.statistics.toUpperCase(),
                value: l10n.view.toUpperCase(),
                icon: Icons.bar_chart_rounded,
                color: Colors.tealAccent,
                delay: 700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        QuickActions(
          actions: [
            ActionItem(l10n.newTicket, Icons.confirmation_number, '/create_ticket',
                isPrimary: true),
            ActionItem(l10n.manageTeam, Icons.groups, '/event_staff',
                color: Colors.blueAccent),
            ActionItem(l10n.scanner, Icons.qr_code_scanner, '/scanner',
                color: Colors.purpleAccent),
            ActionItem(l10n.viewAllTickets, Icons.list_alt, '/tickets',
                color: Colors.orangeAccent),
          ],
          onActionBeforeNavigate: () => _checkEventSelected(context, ref),
        ),
      ],
    );
  }

  void _checkEventSelected(BuildContext context, WidgetRef ref) {
    final selectedEvent = ref.read(selectedEventProvider);
    if (selectedEvent == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectEvent)),
      );
    }
  }
}
