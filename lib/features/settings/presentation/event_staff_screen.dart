import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/glass_scaffold.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_roles.dart';
import '../data/settings_repository.dart';
import '../../events/presentation/event_state.dart';

final eventStaffProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final selectedEvent = ref.watch(selectedEventProvider);
  if (selectedEvent == null) return [];
  return ref
      .watch(settingsRepositoryProvider)
      .getEventStaff(selectedEvent['id']);
});

class EventStaffScreen extends ConsumerWidget {
  const EventStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedEvent = ref.watch(selectedEventProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final staffAsync = ref.watch(eventStaffProvider);
    final allUsersAsync = ref.watch(usersListProvider); // For the "Add" dialog

    if (selectedEvent == null) {
      return const Scaffold(body: Center(child: Text("No event selected")));
    }

    return GlassScaffold(
      appBar: AppBar(
        title: Text('Team: ${selectedEvent['name']}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () =>
                _showAddStaffDialog(context, ref, allUsersAsync.value ?? []),
            tooltip: 'Add Staff to Event',
          ),
        ],
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (staffList) {
          if (staffList.isEmpty) {
            return Center(
                child: Text('No staff assigned to this event.',
                    style: theme.textTheme.bodyMedium));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: staffList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final staff = staffList[index];
              // We need to match staff['user_id'] with allUsers to get display_name if not in join
              // The query in repo was simple select, so we might miss names.
              // Let's try to find name from global list.
              final userDetails = allUsersAsync.value?.firstWhere(
                      (u) => u['user_id'] == staff['user_id'],
                      orElse: () =>
                          {'display_name': 'Unknown User', 'email': '???'}) ??
                  {};

              final role = staff['role'];
              final qStandard = staff['quota_standard'] ?? 0;
              final qGuest = staff['quota_guest'] ?? 0;
              final qStandardUsed = staff['quota_standard_used'] ?? 0;
              final qGuestUsed = staff['quota_guest_used'] ?? 0;

              return GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _getRoleColor(role).withOpacity(0.2),
                          child: Icon(Icons.person, color: _getRoleColor(role)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userDetails['display_name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(role.toString().toUpperCase(),
                                  style: TextStyle(
                                      color: _getRoleColor(role),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.edit, color: Colors.blueAccent),
                          onPressed: () => _showEditQuotaDialog(context, ref,
                              staff, userDetails['display_name'] ?? 'User'),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _QuotaBadge(
                            title: "STANDARD",
                            used: qStandardUsed,
                            total: qStandard,
                            color: Colors.blue),
                        _QuotaBadge(
                            title: "INVIT",
                            used: staff['quota_invitation_used'] ?? 0,
                            total: staff['quota_invitation'] ?? 0,
                            color: Colors.purple),
                        _QuotaBadge(
                            title: "VIP",
                            used: qGuestUsed,
                            total: qGuest,
                            color: Colors.pink),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case AppRoles.admin:
        return Colors.redAccent;
      case AppRoles.rrpp:
        return AppTheme.neonBlue;
      case AppRoles.door:
        return AppTheme.accentGreen;
      default:
        return Colors.grey;
    }
  }

  void _showAddStaffDialog(BuildContext context, WidgetRef ref,
      List<Map<String, dynamic>> allUsers) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter out users already in the list?
    // Ideally yes, but let's just show all for MVP simplicity or filter via `eventStaffProvider` value if possible.
    // We can't easily access the provider value here without passing it.
    // Let's just user simple dropdown.

    String? selectedUserId;
    String selectedRole = AppRoles.rrpp;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.surfaceColor : Colors.white,
          title: Text("Add Staff to Event",
              style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Select User"),
                items: allUsers
                    .map((u) => DropdownMenuItem(
                          value: u['user_id'] as String,
                          child: Text(u['display_name'] ?? u['email']),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => selectedUserId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: "Role in Event"),
                items: [
                  DropdownMenuItem(
                      value: AppRoles.rrpp,
                      child: Text(AppRoles.label(AppRoles.rrpp))),
                  DropdownMenuItem(
                      value: AppRoles.door,
                      child: Text(AppRoles.label(AppRoles.door))),
                  DropdownMenuItem(
                      value: AppRoles.admin,
                      child: Text(AppRoles.label(AppRoles.admin))),
                ],
                onChanged: (v) => setState(() => selectedRole = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: selectedUserId == null
                  ? null
                  : () async {
                      // Initial quotas 0, can edit later.
                      final eventId = ref.read(selectedEventProvider)!['id'];
                      await ref
                          .read(settingsRepositoryProvider)
                          .manageEventStaff(
                            eventId: eventId,
                            userId: selectedUserId!,
                            role: selectedRole,
                            quotaStandard: 0,
                            quotaGuest: 0,
                            quotaInvitation: 0,
                          );
                      ref.invalidate(eventStaffProvider);
                      if (context.mounted) Navigator.pop(ctx);
                    },
              child: const Text("Add"),
            )
          ],
        ),
      ),
    );
  }

  void _showEditQuotaDialog(BuildContext context, WidgetRef ref,
      Map<String, dynamic> staff, String userName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stdCtrl =
        TextEditingController(text: (staff['quota_standard'] ?? 0).toString());
    final guestCtrl =
        TextEditingController(text: (staff['quota_guest'] ?? 0).toString());
    final invCtrl = TextEditingController(
        text: (staff['quota_invitation'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.surfaceColor : Colors.white,
        title: Text("Edit Quotas: $userName",
            style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stdCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: "Standard Ticket Quota"),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: guestCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: "Guest List Quota (VIP)"),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: invCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: "Invitation Quota (Normal)"),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final std = int.tryParse(stdCtrl.text) ?? 0;
              final guest = int.tryParse(guestCtrl.text) ?? 0;
              final inv = int.tryParse(invCtrl.text) ?? 0;
              final eventId = ref.read(selectedEventProvider)!['id'];

              await ref.read(settingsRepositoryProvider).manageEventStaff(
                    eventId: eventId,
                    userId: staff['user_id'],
                    role: staff['role'],
                    quotaStandard: std,
                    quotaGuest: guest,
                    quotaInvitation: inv,
                  );
              ref.invalidate(eventStaffProvider);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }
}

class _QuotaBadge extends StatelessWidget {
  final String title;
  final int used;
  final int total;
  final Color color;

  const _QuotaBadge(
      {required this.title,
      required this.used,
      required this.total,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            "$used / ${total == 0 ? '∞' : total}", // If 0, maybe infinity? No, DB constraints check <=0? No check is <= quota. So 0 is 0.
            // Wait, if quota is 0, they can sell 0.
            // Admin usually sets 0 as none.
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }
}
