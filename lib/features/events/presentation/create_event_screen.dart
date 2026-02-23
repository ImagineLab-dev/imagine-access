import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/glass_scaffold.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/custom_input.dart';
import '../../../core/ui/neon_button.dart';
import '../../../core/theme/app_theme.dart';
import '../data/event_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../tickets/data/ticket_repository.dart';
import '../../settings/data/settings_repository.dart'; // To get default currency
import 'ticket_types_widget.dart';
import 'event_state.dart'; // To access selectedEventProvider

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  final String? eventId; // If null, create mode. If set, edit mode.
  final Map<String, dynamic>? initialData;

  const CreateEventScreen({super.key, this.eventId, this.initialData});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _slugCtrl;
  late TextEditingController _venueCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0);
  String _currency = 'PYG';

  List<Map<String, dynamic>> _ticketTypes = [];
  final List<String> _deletedTicketTypeIds = []; // Track deletions
  bool _isLoading = false;

  // Professional Features
  bool _hasStaffTicket = false;
  bool _hasGuestTicket = false;
  bool _hasInvitationTicket = false;
  TimeOfDay? _invitationValidUntil; // Time limit for invitations

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? {};

    _nameCtrl = TextEditingController(text: data['name']);
    _slugCtrl = TextEditingController(text: data['slug']);
    _venueCtrl = TextEditingController(text: data['venue']);
    _addressCtrl = TextEditingController(text: data['address']);
    _cityCtrl = TextEditingController(text: data['city']);
    _currency = data['currency'] ?? 'PYG';

    if (data['date'] != null) {
      _selectedDate = DateTime.parse(data['date']);
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate.toLocal());
    }

    // If editing, we would fetch types here. For now start empty or from passed data.
    if (data['ticket_types'] != null) {
      final rawTypes = List<Map<String, dynamic>>.from(data['ticket_types']);
      // Detect special types
      _hasStaffTicket = rawTypes.any((t) => t['category'] == 'staff');
      _hasGuestTicket = rawTypes.any((t) => t['category'] == 'guest');
      _hasInvitationTicket = rawTypes.any((t) => t['category'] == 'invitation');

      if (_hasInvitationTicket) {
        final invType = rawTypes.cast<Map<String, dynamic>?>().firstWhere(
            (t) => t!['category'] == 'invitation',
            orElse: () => null);
        if (invType != null && invType['valid_until'] != null) {
          final dt = DateTime.parse(invType['valid_until']).toLocal();
          _invitationValidUntil = TimeOfDay.fromDateTime(dt);
        }
      }

      // Filter out special types from manual list
      _ticketTypes = rawTypes
          .where((t) =>
              t['category'] != 'staff' &&
              t['category'] != 'guest' &&
              t['category'] != 'invitation')
          .toList();
    }

    // Default currency from settings if creating new
    if (widget.eventId == null) {
      Future.microtask(() async {
        final defaultCurrency =
            await ref.read(settingsRepositoryProvider).getDefaultCurrency();
        if (mounted) {
          setState(() => _currency = defaultCurrency);
        }
      });
    }

    // Auto-generate slug listener
    _nameCtrl.addListener(() {
      if (widget.eventId == null && _nameCtrl.text.isNotEmpty) {
        // Only auto-generate on create
        _slugCtrl.text = _nameCtrl.text
            .toLowerCase()
            .replaceAll(' ', '-')
            .replaceAll(RegExp(r'[^a-z0-9-]'), '');
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _venueCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Combine Date & Time
      final fullDate = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, _selectedTime.hour, _selectedTime.minute);

      String newEventId;

      if (widget.eventId == null) {
        // Create — associate with user's organization
        final orgId = ref.read(organizationIdProvider);
        final res = await ref.read(eventRepositoryProvider).createEvent(
              name: _nameCtrl.text,
              venue: _venueCtrl.text,
              address: _addressCtrl.text,
              city: _cityCtrl.text,
              slug: _slugCtrl.text,
              date: fullDate,
              currency: _currency,
              organizationId: orgId,
            );
        newEventId = res['id'];
      } else {
        // Update
        await ref.read(eventRepositoryProvider).updateEvent(widget.eventId!, {
          'name': _nameCtrl.text,
          'venue': _venueCtrl.text,
          'address': _addressCtrl.text,
          'city': _cityCtrl.text,
          'slug': _slugCtrl.text,
          'date': fullDate.toIso8601String(),
          'currency': _currency,
        });
        newEventId = widget.eventId!;
      }

      // 1. Handle Deletions
      for (var id in _deletedTicketTypeIds) {
        await ref.read(eventRepositoryProvider).deleteTicketType(id);
      }

      // 2. Save Ticket Types (Create & Update)
      for (var type in _ticketTypes) {
        if (type['is_new'] == true) {
          await ref.read(eventRepositoryProvider).createTicketType(
                eventId: newEventId,
                name: type['name'],
                price: (type['price'] as num).toDouble(),
                currency: _currency,
                color: type['color'],
              );
        } else if (type['id'] != null) {
          // Update existing
          await ref.read(eventRepositoryProvider).updateTicketType(type['id'], {
            'name': type['name'],
            'price': (type['price'] as num).toDouble(),
            'currency': _currency,
            'color': type['color'],
          });
        }
      }

      // 3. Handle Professional Tickets (Staff/Guest)
      Future<void> handleSpecialType(String category, String name) async {
        // Check if exists in original data to get ID
        final original = ((widget.initialData?['ticket_types'] ?? []) as List)
            .firstWhere((t) => t['category'] == category, orElse: () => null);

        DateTime? validUntilDate;
        if (category == 'invitation' && _invitationValidUntil != null) {
          // Use event date but override time
          validUntilDate = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              _invitationValidUntil!.hour,
              _invitationValidUntil!.minute);
        }

        // Default Colors
        String color = '#4F46E5'; // Default
        if (category == 'staff') {
          color = '#3B82F6'; // Blue
        } else if (category == 'invitation') {
          color = '#A855F7'; // Purple
        } else if (category == 'guest') {
          color = '#EC4899'; // Pink
        }

        if (original != null) {
          // Already exists. Ensure it's active.
          await ref
              .read(eventRepositoryProvider)
              .updateTicketType(original['id'], {
            'name': name,
            'price': 0,
            'currency': _currency,
            'category': category,
            'is_active': true,
            'valid_until': validUntilDate?.toIso8601String(),
            'color': color
          });
        } else {
          // Create New
          await ref.read(eventRepositoryProvider).createTicketType(
              eventId: newEventId,
              name: name,
              price: 0,
              currency: _currency,
              category: category,
              validUntil: validUntilDate,
              color: color);
        }
      }

      Future<void> deleteSpecialType(String category) async {
        final original = ((widget.initialData?['ticket_types'] ?? []) as List)
            .firstWhere((t) => t['category'] == category, orElse: () => null);
        if (original != null) {
          await ref
              .read(eventRepositoryProvider)
              .deleteTicketType(original['id']);
        }
      }

      if (_hasStaffTicket) {
        await handleSpecialType('staff', 'Staff Access');
      } else {
        await deleteSpecialType('staff');
      }

      if (_hasInvitationTicket) {
        await handleSpecialType('invitation', 'Invitation');
      } else {
        await deleteSpecialType('invitation');
      }

      if (_hasGuestTicket) {
        await handleSpecialType('guest', 'Invitado Especial');
      } else {
        await deleteSpecialType('guest');
      }

      ref.invalidate(eventsProvider);
      // Also invalidate price provider for the wizard
      ref.invalidate(ticketTypesProvider(newEventId));

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${l10n.error}: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (context.mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(widget.eventId == null ? l10n.newEvent : l10n.editEvent),
        actions: [
          if (widget.eventId != null)
            IconButton(
              icon: const Icon(Icons.archive, color: Colors.amber),
              onPressed: () {
                // Archive logic
                ref.read(eventRepositoryProvider).archiveEvent(widget.eventId!);
                ref.invalidate(eventsProvider);
                context.pop();
              },
            ),
          if (widget.eventId != null)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              onPressed: () async {
                final l10n = AppLocalizations.of(context)!;
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
                        .deleteEvent(widget.eventId!);
                    ref.invalidate(eventsProvider);
                    if (context.mounted) context.pop();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${l10n.deleteErrorMessage}: $e')));
                    }
                  }
                }
              },
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Basic Info
              Text(l10n.eventDetails, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              CustomInput(
                  label: l10n.eventName,
                  controller: _nameCtrl,
                  icon: Icons.event,
                  validator: (v) => v!.isEmpty ? l10n.required : null),
              const SizedBox(height: 12),
              CustomInput(
                  label: '${l10n.slug} (URL ID)',
                  controller: _slugCtrl,
                  icon: Icons.link,
                  validator: (v) => v!.isEmpty ? l10n.required : null),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030));
                        if (d != null) setState(() => _selectedDate = d);
                      },
                      child: CustomInput(
                          key: ValueKey(_selectedDate), // Force rebuild
                          label: l10n.date,
                          icon: Icons.calendar_today,
                          enabled: false,
                          initialValue:
                              "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: _selectedTime);
                        if (t != null) setState(() => _selectedTime = t);
                      },
                      child: CustomInput(
                          key: ValueKey(_selectedTime), // Force rebuild
                          label: l10n.time,
                          icon: Icons.access_time,
                          enabled: false,
                          initialValue: _selectedTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location Section
              Text(l10n.location,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: AppTheme.accentBlue)),
              const SizedBox(height: 12),
              CustomInput(
                  label: l10n.venueName,
                  controller: _venueCtrl,
                  icon: Icons.stadium,
                  validator: (v) => v!.isEmpty ? l10n.required : null),
              const SizedBox(height: 12),
              CustomInput(
                  label: l10n.address,
                  controller: _addressCtrl,
                  icon: Icons.location_on,
                  validator: (v) => v!.isEmpty ? l10n.required : null),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: 3,
                      child: CustomInput(
                          label: l10n.city,
                          controller: _cityCtrl,
                          icon: Icons.location_city)),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            l10n.currencyLabel,
                            style: TextStyle(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          value: _currency,
                          dropdownColor: theme.brightness == Brightness.dark
                              ? Colors.black87
                              : Colors.white,
                          style: TextStyle(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            fillColor: theme.brightness == Brightness.dark
                                ? AppTheme.surfaceColor.withOpacity(0.5)
                                : AppTheme.lightInput,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: (theme.brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black)
                                      .withOpacity(0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: (theme.brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black)
                                      .withOpacity(0.1)),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'PYG', child: Text('GS (PYG)')),
                            DropdownMenuItem(
                                value: 'USD', child: Text('USD (\$ )')),
                          ],
                          onChanged: (v) => setState(() => _currency = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 2. Ticket Types
              TicketTypesWidget(
                initialTypes: _ticketTypes,
                currency: _currency, // Pass currency down
                onChanged: (types) => _ticketTypes = types,
                onDeleted: (id) => _deletedTicketTypeIds.add(id),
              ),
              _PricingCard(
                title: "Professional Access (Staff)",
                subtitle: "Creates 'Staff Access' ticket (Price: 0)",
                icon: Icons.badge,
                color: Colors.blueAccent,
                value: _hasStaffTicket,
                onChanged: (v) => setState(() => _hasStaffTicket = v),
              ),
              const SizedBox(height: 16),
              _PricingCard(
                title: "Enable Invitations (Normal)",
                subtitle:
                    "Creates 'Invitation' ticket (Price: 0) - For RRPP Quotas",
                icon: Icons.mail,
                color: Colors.purpleAccent,
                value: _hasInvitationTicket,
                onChanged: (v) => setState(() => _hasInvitationTicket = v),
                child: InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context,
                        initialTime: _invitationValidUntil ??
                            const TimeOfDay(hour: 23, minute: 59));
                    if (t != null) setState(() => _invitationValidUntil = t);
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 16, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(
                          _invitationValidUntil == null
                              ? "Set Valid Until Time (Optional)"
                              : "Valid until: ${_invitationValidUntil!.format(context)}",
                          style: TextStyle(
                              color: _invitationValidUntil == null
                                  ? Colors.white54
                                  : Colors.purpleAccent,
                              fontWeight: _invitationValidUntil == null
                                  ? FontWeight.normal
                                  : FontWeight.bold)),
                      if (_invitationValidUntil != null)
                        IconButton(
                          icon: const Icon(Icons.clear,
                              size: 16, color: Colors.red),
                          onPressed: () =>
                              setState(() => _invitationValidUntil = null),
                        )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _PricingCard(
                title: "Enable VIP Guest List",
                subtitle:
                    "Creates 'Invitado Especial' ticket (Price: 0) - For VIP Quotas",
                icon: Icons.star,
                color: Colors.pinkAccent,
                value: _hasGuestTicket,
                onChanged: (v) => setState(() => _hasGuestTicket = v),
              ),
              const SizedBox(height: 40),

              NeonButton(
                  text: l10n.saveEvent,
                  icon: Icons.save,
                  isLoading: _isLoading,
                  onPressed: _save),
              const SizedBox(height: 24),
              if (widget.eventId != null)
                TextButton.icon(
                  onPressed: _deleteEvent,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: Text(l10n.delete,
                      style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEvent() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.confirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(l10n.no)),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l10n.yes, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);
        await ref.read(eventRepositoryProvider).deleteEvent(widget.eventId!);

        // Clear selected event if it's the one we just deleted
        final selected = ref.read(selectedEventProvider);
        if (selected != null && selected['id'] == widget.eventId) {
          await ref.read(selectedEventProvider.notifier).clearEvent();
        }

        if (mounted) {
          context.pop(); // Close screen
          // Refresh list
          ref.invalidate(eventsProvider);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? child;

  const _PricingCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.value,
    required this.onChanged,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4, left: 28),
              child: Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            value: value,
            activeColor: color,
            onChanged: onChanged,
          ),
          if (value && child != null) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 8),
              child: child!,
            ),
          ]
        ],
      ),
    );
  }
}
