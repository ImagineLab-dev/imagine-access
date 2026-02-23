import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import 'package:flutter_animate/flutter_animate.dart';
import '../data/ticket_repository.dart';
import '../../../core/ui/glass_scaffold.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/custom_input.dart';
import '../../../core/ui/status_badge.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Provider for tickets list
final ticketsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(ticketRepositoryProvider).getTickets();
});

// REALTIME UPDATER for Tickets List
final ticketsRealtimeProvider = Provider.autoDispose<void>((ref) {
  final supabase = Supabase.instance.client;
  final channel = supabase
      .channel('global_tickets_updates')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tickets',
        callback: (payload) {
          dev.log('Realtime change in tickets', name: 'TicketsRealtime');
          ref.invalidate(ticketsProvider);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'checkins',
        callback: (payload) {
          dev.log('Realtime change in checkins', name: 'TicketsRealtime');
          ref.invalidate(ticketsProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
  });
});

class TicketListScreen extends ConsumerStatefulWidget {
  const TicketListScreen({super.key});

  @override
  ConsumerState<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends ConsumerState<TicketListScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(ticketsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    // Start Realtime Listeners
    ref.watch(ticketsRealtimeProvider);

    return GlassScaffold(
      appBar: AppBar(
        title: Text(l10n.guestList,
            style: const TextStyle(letterSpacing: 2, fontSize: 16)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.refresh(ticketsProvider)),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(theme, isDark, l10n),
          Expanded(
            child: ticketsAsync.when(
              data: (tickets) {
                // Filter logic
                final filtered = tickets.where((t) {
                  final matchSearch = t['buyer_name']
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      t['buyer_email']
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase());

                  final hasCheckins =
                      (t['checkins'] as List?)?.isNotEmpty ?? false;
                  final currentStatus = hasCheckins
                      ? 'used'
                      : (t['status'] ?? 'valid').toString().toLowerCase();

                  final matchFilter = _selectedFilter == 'all' ||
                      currentStatus == _selectedFilter;
                  return matchSearch && matchFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 60,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text(l10n.noTicketsFound,
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5))),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _buildTicketCard(filtered[index], theme, l10n)
                        .animate()
                        .fade()
                        .slideX(begin: 0.1, end: 0, delay: (50 * index).ms);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                  child: Text('${l10n.error}: $err',
                      style: TextStyle(color: theme.colorScheme.error))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(
      ThemeData theme, bool isDark, AppLocalizations l10n) {
    return GlassCard(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        children: [
          CustomInput(
            label: l10n.search,
            controller: _searchController,
            hint: l10n.searchHint,
            prefixIcon: Icons.search,
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                    label: l10n.all,
                    value: 'all',
                    groupValue: _selectedFilter,
                    onChanged: (v) => setState(() => _selectedFilter = v)),
                const SizedBox(width: 8),
                _FilterChip(
                    label: l10n.validCaps,
                    value: 'valid',
                    groupValue: _selectedFilter,
                    onChanged: (v) => setState(() => _selectedFilter = v)),
                const SizedBox(width: 8),
                _FilterChip(
                    label: l10n.usedCaps,
                    value: 'used',
                    groupValue: _selectedFilter,
                    onChanged: (v) => setState(() => _selectedFilter = v)),
                const SizedBox(width: 8),
                _FilterChip(
                    label: l10n.voidCaps,
                    value: 'void',
                    groupValue: _selectedFilter,
                    onChanged: (v) => setState(() => _selectedFilter = v)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(
      Map<String, dynamic> ticket, ThemeData theme, AppLocalizations l10n) {
    final buyerName = ticket['buyer_name'] ?? l10n.guest;
    final type = ticket['type'] ?? 'general';
    final id = ticket['id'];

    final hasCheckins = (ticket['checkins'] as List?)?.isNotEmpty ?? false;
    final dbStatus = (ticket['status'] ?? 'valid').toString().toLowerCase();
    final rawStatus = hasCheckins ? 'used' : dbStatus;

    BadgeStatus badgeStatus = BadgeStatus.neutral;
    String statusText = rawStatus.toUpperCase();

    if (rawStatus == 'valid') {
      badgeStatus = BadgeStatus.success;
      statusText = l10n.validCaps;
    } else if (rawStatus == 'used') {
      badgeStatus = BadgeStatus.warning;
      statusText = l10n.usedCaps;
    } else if (rawStatus == 'void') {
      badgeStatus = BadgeStatus.error;
      statusText = l10n.voidCaps;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        onTap: () {
          _showTicketDetails(context, ticket, l10n, ref);
        },
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.confirmation_num_outlined,
                  color: theme.colorScheme.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(buyerName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'Enviado por: ${ticket['users_profile']?['display_name'] ?? 'Sistema'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(type.toString().toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                      const SizedBox(width: 8),
                      Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.3),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(id.toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5)),
                              overflow: TextOverflow.ellipsis)),
                      if (ticket['email_sent_at'] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Tooltip(
                              message: l10n.emailSent,
                              child: Icon(Icons.mark_email_read,
                                  size: 16, color: theme.colorScheme.primary)),
                        ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(text: statusText, status: badgeStatus),
          ],
        ),
      ),
    );
  }

  void _showTicketDetails(BuildContext context, Map<String, dynamic> ticket,
      AppLocalizations l10n, WidgetRef ref) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          final theme = Theme.of(context);
          final id = ticket['id'];
          final status = ticket['status'] ?? 'valid';
          final isVoid = status == 'void';

          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(l10n.ticketDetails,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _detailRow(
                    l10n.buyerInfo, ticket['buyer_name'] ?? 'Guest', theme),
                _detailRow(
                    l10n.email, ticket['buyer_email'] ?? 'Unknown', theme),
                _detailRow(l10n.ticketType,
                    (ticket['type'] ?? '').toString().toUpperCase(), theme),
                _detailRow("ID", id.toString(), theme),
                _detailRow("Status", status.toString().toUpperCase(), theme),
                if (ticket['events'] != null)
                  _detailRow(l10n.event, ticket['events']['name'] ?? '', theme),
                if (ticket['email_sent_at'] != null)
                  _detailRow(l10n.emailSent,
                      _formatDate(ticket['email_sent_at']), theme),

                const SizedBox(height: 32),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.email_outlined),
                        label: Text(l10n.resendEmail),
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.sending)));
                            await ref
                                .read(ticketRepositoryProvider)
                                .resendTicket(id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(l10n.emailResent),
                                      backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red));
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                    if (!isVoid) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.block, color: Colors.white),
                          label: Text(l10n.voidTicket,
                              style: const TextStyle(color: Colors.white)),
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                      title: Text(l10n.voidTicket),
                                      content: Text(l10n.confirmVoid),
                                      actions: [
                                        TextButton(
                                            child: Text(l10n.cancel),
                                            onPressed: () =>
                                                Navigator.pop(ctx)),
                                        TextButton(
                                            child: Text(l10n.confirm,
                                                style: const TextStyle(
                                                    color: Colors.red)),
                                            onPressed: () async {
                                              Navigator.pop(ctx);
                                              Navigator.pop(context);
                                              try {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        content: Text(
                                                            l10n.voiding)));
                                                await ref
                                                    .read(
                                                        ticketRepositoryProvider)
                                                    .voidTicket(id);
                                                ref.invalidate(ticketsProvider);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(l10n
                                                              .ticketVoided),
                                                          backgroundColor:
                                                              Colors.green));
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content:
                                                              Text('Error: $e'),
                                                          backgroundColor:
                                                              Colors.red));
                                                }
                                              }
                                            }),
                                      ],
                                    ));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          );
        });
  }

  Widget _detailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6)))),
          Expanded(
              child: Text(value,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return isoString;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _FilterChip(
      {required this.label,
      required this.value,
      required this.groupValue,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isSelected = groupValue == value;
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (v) => onChanged(value),
      backgroundColor: theme.colorScheme.surface.withOpacity(0.5),
      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withOpacity(0.6),
          fontWeight: FontWeight.bold,
          fontSize: 12),
      side: BorderSide(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withOpacity(0.1),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }
}
