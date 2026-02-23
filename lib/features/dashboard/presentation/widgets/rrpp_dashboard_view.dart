import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../events/presentation/event_state.dart';
import 'dashboard_components.dart';

class RrppDashboardView extends ConsumerWidget {
  final Map<String, dynamic> metrics;

  const RrppDashboardView({super.key, required this.metrics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // EXTRACT METRICS
    final int paidCount = metrics['paid_tickets_count'] ?? 0;
    final int paidToday = metrics['paid_tickets_today'] ?? 0;
    final int totalIssued = metrics['total_issued'] ?? 0;
    final int invitesCount = metrics['invitations_count'] ?? 0;

    final int quotaStd = metrics['quota_standard'] ?? 0;
    final int quotaStdUsed = metrics['quota_standard_used'] ?? 0;
    final int quotaStdRem = metrics['remaining_standard'] ?? 0;

    final int quotaGuest = metrics['quota_guest'] ?? 0;
    final int quotaGuestUsed = metrics['quota_guest_used'] ?? 0;
    final int quotaGuestRem = metrics['remaining_guest'] ?? 0;

    final int totalEntered = metrics['total_scanned'] ?? 0;
    final int toEnter = totalIssued - totalEntered;

    // Progress calculations
    final double stdProgress = quotaStd > 0 ? (quotaStdUsed / quotaStd) : 0.0;
    final double guestProgress = quotaGuest > 0 ? (quotaGuestUsed / quotaGuest) : 0.0;

    // Entered percentage
    final String enteredPercent = totalIssued > 0
        ? "${((totalEntered / totalIssued) * 100).toStringAsFixed(1)}%"
        : "0%";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            EliteMetricCard(
              title: l10n.salesTitle.toUpperCase(),
              value: paidCount.toString(),
              subValue: "${l10n.today}: $paidToday",
              icon: Icons.confirmation_number_outlined,
              color: AppTheme.accentBlue,
              delay: 0,
            ),
            EliteMetricCard(
              title: l10n.totalIssued.toUpperCase(),
              value: totalIssued.toString(),
              subValue: "${l10n.paidShort}: $paidCount ${l10n.inviteShort}: $invitesCount",
              icon: Icons.all_inbox,
              color: Colors.indigoAccent,
              delay: 100,
            ),
            EliteMetricCard(
              title: l10n.invitationsStandard.toUpperCase(),
              value: "$quotaStdUsed / $quotaStd",
              subValue: "${l10n.remaining}: $quotaStdRem",
              icon: Icons.people_outline,
              color: Colors.tealAccent,
              progress: stdProgress,
              progressColor: Colors.tealAccent,
              delay: 200,
            ),
            EliteMetricCard(
              title: l10n.invitationsGuest.toUpperCase(),
              value: "$quotaGuestUsed / $quotaGuest",
              subValue: "${l10n.remaining}: $quotaGuestRem",
              icon: Icons.star_border,
              color: AppTheme.accentPurple,
              progress: guestProgress,
              progressColor: AppTheme.accentPurple,
              delay: 300,
            ),
            EliteMetricCard(
              title: l10n.entered.toUpperCase(),
              value: totalEntered.toString(),
              subValue: enteredPercent,
              icon: Icons.qr_code_scanner,
              color: AppTheme.accentGreen,
              delay: 400,
            ),
            EliteMetricCard(
              title: l10n.toEnterTitle.toUpperCase(),
              value: toEnter.toString(),
              subValue: "${l10n.remaining}: $toEnter",
              icon: Icons.hourglass_empty_rounded,
              color: AppTheme.accentYellow,
              delay: 500,
            ),
          ],
        ),
        const SizedBox(height: 32),
        QuickActions(
          actions: [
            ActionItem(
              l10n.newTicketInvitation.toUpperCase(),
              Icons.confirmation_number,
              '/create_ticket',
              isPrimary: true,
            ),
            ActionItem(
              l10n.viewAllTickets,
              Icons.list_alt,
              '/tickets',
              color: Colors.orangeAccent,
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
