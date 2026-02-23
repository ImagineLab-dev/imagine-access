import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../events/presentation/event_state.dart';
import 'dashboard_components.dart';

class DoorDashboardView extends ConsumerWidget {
  final Map<String, dynamic> metrics;

  const DoorDashboardView({super.key, required this.metrics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

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
              title: l10n.scanned.toUpperCase(),
              value: (metrics['scanned'] ?? 0).toString(),
              icon: Icons.qr_code_scanner,
              color: AppTheme.accentPurple,
              delay: 100,
            ),
            MetricCard(
              title: "MANUAL",
              value: (metrics['scanned_manual'] ?? 0).toString(),
              icon: Icons.back_hand,
              color: Colors.blueGrey,
              delay: 150,
            ),
            MetricCard(
              title: l10n.toEnter.toUpperCase(),
              value: (metrics['valid'] ?? 0).toString(),
              icon: Icons.hourglass_empty_rounded,
              color: AppTheme.accentYellow,
              delay: 200,
            ),
            MetricCard(
              title: l10n.guestEntry.toUpperCase(),
              value:
                  "${metrics['invitations_scanned'] ?? 0} / ${metrics['invitations_total'] ?? 0}",
              icon: Icons.people_outline_rounded,
              color: AppTheme.accentGreen,
              delay: 300,
            ),
            MetricCard(
              title: l10n.staff.toUpperCase(),
              value:
                  "${metrics['staff_entered'] ?? 0} / ${metrics['staff_created'] ?? 0}",
              icon: Icons.badge_outlined,
              color: Colors.orangeAccent,
              delay: 400,
            ),
            MetricCard(
              title: l10n.guests.toUpperCase(),
              value:
                  "${metrics['guest_entered'] ?? 0} / ${metrics['guest_created'] ?? 0}",
              icon: Icons.star_border,
              color: Colors.pinkAccent,
              delay: 500,
            ),
            MetricCard(
              title: l10n.normal.toUpperCase(),
              value:
                  "${metrics['standard_entered'] ?? 0} / ${metrics['standard_created'] ?? 0}",
              icon: Icons.people_outline,
              color: Colors.cyanAccent,
              delay: 600,
            ),
          ],
        ),
        const SizedBox(height: 32),
        QuickActions(
          actions: [
            ActionItem(
              l10n.scanner,
              Icons.qr_code_scanner,
              '/scanner',
              isPrimary: true,
            ),
            ActionItem(
              l10n.searchTicketBtn.toUpperCase(),
              Icons.search,
              '/document_search',
              color: Colors.blueAccent,
            ),
            ActionItem(
              l10n.viewAllTickets,
              Icons.list_alt,
              '/tickets',
              color: Colors.orangeAccent,
            ),
            ActionItem(
              l10n.refresh.toUpperCase(),
              Icons.refresh,
              '#',
              color: Colors.grey,
            ),
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
