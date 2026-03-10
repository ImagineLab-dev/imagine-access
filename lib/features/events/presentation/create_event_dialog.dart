import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/custom_input.dart';
import '../../../core/ui/neon_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../data/event_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import 'package:imagine_access/l10n/app_localizations.dart';

class CreateEventDialog extends ConsumerStatefulWidget {
  const CreateEventDialog({super.key});

  @override
  ConsumerState<CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends ConsumerState<CreateEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  String _currency = 'PYG';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _venueCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final orgId = ref.read(organizationIdProvider);
      await ref.read(eventRepositoryProvider).createEvent(
            name: _nameCtrl.text,
            venue: _venueCtrl.text,
            address: _addressCtrl.text,
            city: _cityCtrl.text,
            slug: _slugCtrl.text.toLowerCase().replaceAll(' ', '-'),
            date: _selectedDate,
            currency: _currency,
            organizationId: orgId,
          );

      if (mounted) {
        ref.invalidate(eventsProvider); // Refresh list
        Navigator.of(context).pop();
        ErrorHandler.showSuccessSnackBar(context, l10n.eventCreatedSuccessfully);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, l10n.errorWithDetail(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.neonBlue.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.neonBlue.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 5)
            ]),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.newEvent,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              CustomInput(
                label: l10n.eventName,
                controller: _nameCtrl,
                icon: Icons.event,
                validator: (v) => v!.isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 16),
              CustomInput(
                label: l10n.venueName,
                controller: _venueCtrl,
                icon: Icons.location_on,
                validator: (v) => v!.isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 16),
              CustomInput(
                label: l10n.address,
                controller: _addressCtrl,
                icon: Icons.map,
                validator: (v) => v!.isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 16),
              CustomInput(
                label: l10n.city,
                controller: _cityCtrl,
                icon: Icons.location_city,
                validator: (v) => v!.isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomInput(
                      label: l10n.slug,
                      controller: _slugCtrl,
                      icon: Icons.link,
                      validator: (v) => v!.isEmpty ? l10n.required : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 100,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currency,
                        dropdownColor: theme.scaffoldBackgroundColor,
                        items: ['PYG', 'USD']
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _currency = v!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030));
                  if (d != null) setState(() => _selectedDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: AppTheme.neonBlue),
                      const SizedBox(width: 12),
                      Text(
                          "${l10n.date}: ${_selectedDate.toLocal().toString().split(' ')[0]}")
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              NeonButton(
                  text: l10n.createEvent.toUpperCase(),
                  icon: Icons.check,
                  isLoading: _isLoading,
                  onPressed: _create)
            ],
          ),
        ),
      ),
    );
  }
}
