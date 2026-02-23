import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_roles.dart';
import '../data/event_repository.dart';
import '../presentation/create_event_screen.dart';
import '../../auth/presentation/auth_controller.dart';
import 'event_state.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AdminEventList extends ConsumerWidget {
  final List<Map<String, dynamic>> events;
  final bool isArchived;

  const AdminEventList(
      {super.key, required this.events, this.isArchived = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(userRoleProvider);
    final isDevice = ref.watch(deviceProvider) != null;
    final displayRole = isDevice ? AppRoles.door : role;
    final isAdmin = displayRole == AppRoles.admin;

    if (events.isEmpty) {
      return Center(
          child: Text(l10n.noEventsFound,
              style: Theme.of(context).textTheme.bodyLarge));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final event = events[index];
        final date = DateTime.parse(event['date']);
        final isActive = event['is_active'] as bool? ?? false;

        final cardContent = GlassCard(
          onTap: () async {
            if (!isAdmin) {
              // RRPP/Door: Select event directly
              ref
                  .read(selectedEventProvider.notifier)
                  .selectEvent(event['id'], event['name'], event['slug'] ?? '');
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${l10n.selected}: ${event['name']}')));
              context.pop();
              return;
            }

            // Admin: Show dialog with all options
            final action = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(event['name']),
                content: Text(l10n.whatToDo),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'select'),
                    child: Text(l10n.selectForScanning),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'edit'),
                    child: Text(l10n.editEvent.toUpperCase()),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'delete'),
                    child: Text(l10n.delete.toUpperCase(),
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );

            if (action == 'select' && context.mounted) {
              ref
                  .read(selectedEventProvider.notifier)
                  .selectEvent(event['id'], event['name'], event['slug'] ?? '');
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${l10n.selected}: ${event['name']}')));
              context.pop();
            } else if (action == 'edit' && context.mounted) {
              Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) => CreateEventScreen(
                          eventId: event['id'], initialData: event)))
                  .then((_) => ref.invalidate(eventsProvider));
            } else if (action == 'delete' && context.mounted) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.deleteEventQuery),
                  content: Text(l10n.deleteEventConfirm),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel)),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.delete.toUpperCase(),
                            style: const TextStyle(color: Colors.red))),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await ref
                      .read(eventRepositoryProvider)
                      .deleteEvent(event['id']);
                  ref.invalidate(eventsProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${l10n.deleteErrorMessage}: $e')));
                  }
                }
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.accentGreen.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isActive
                              ? AppTheme.accentGreen
                              : Colors.transparent)),
                  child: Center(
                    child: Text(
                      date.day.toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event['name'],
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                          "${event['venue']} • ${event['ticket_types']?.length ?? 0} ${l10n.types}",
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                if (isAdmin)
                  const Icon(Icons.edit, color: AppTheme.neonBlue, size: 20)
              ],
            ),
          ),
        ).animate().fade(duration: 300.ms, delay: (100 * index).ms).slideX();

        if (!isAdmin) return cardContent;

        return Dismissible(
          key: Key(event['id']),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: Text(l10n.deleteEventQuery),
                      content: Text(l10n.deleteEventConfirm),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n.cancel)),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n.delete,
                                style: const TextStyle(color: Colors.red))),
                      ],
                    ));
          },
          onDismissed: (_) async {
            try {
              await ref.read(eventRepositoryProvider).deleteEvent(event['id']);
              ref.invalidate(eventsProvider);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.deleteErrorMessage)));
              }
              ref.invalidate(eventsProvider); // Restore item
            }
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.withOpacity(0.2),
            child: const Icon(Icons.delete, color: Colors.red),
          ),
          child: cardContent,
        );
      },
    );
  }
}
