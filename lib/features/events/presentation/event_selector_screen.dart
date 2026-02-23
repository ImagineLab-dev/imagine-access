import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/glass_scaffold.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_roles.dart';
import '../data/event_repository.dart';
import 'create_event_screen.dart';
import 'admin_event_list.dart';

class EventSelectorScreen extends ConsumerWidget {
  const EventSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final role = ref.watch(userRoleProvider);

    return DefaultTabController(
      length: 2,
      child: GlassScaffold(
        appBar: AppBar(
          title: const Text('Manage Events'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Archived'),
            ],
            indicatorColor: AppTheme.neonBlue,
          ),
          actions: [
            if (role == AppRoles.admin)
              IconButton(
                  onPressed: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => const CreateEventScreen()))
                        .then((_) => ref.invalidate(eventsProvider));
                  },
                  icon: const Icon(Icons.add_circle_outline))
          ],
        ),
        body: eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (events) {
              final activeEvents = events
                  .where((e) => (e['is_archived'] as bool? ?? false) == false)
                  .toList();
              final archivedEvents = events
                  .where((e) => (e['is_archived'] as bool? ?? false) == true)
                  .toList();

              return TabBarView(
                children: [
                  AdminEventList(events: activeEvents),
                  AdminEventList(
                      events: archivedEvents,
                      isArchived: true), // We can add restore logic later
                ],
              );
            }),
      ),
    );
  }
}
