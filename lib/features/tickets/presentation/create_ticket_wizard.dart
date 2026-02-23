import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../events/presentation/event_state.dart';
import '../../../core/ui/glass_scaffold.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/custom_input.dart';
import '../../../core/ui/neon_button.dart';
import '../../../core/theme/app_theme.dart';
import '../data/ticket_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/ui/loading_overlay.dart';
import '../../../core/constants/app_roles.dart';
import 'ticket_list_screen.dart'; // Import to access ticketsProvider
import '../../auth/presentation/auth_controller.dart';
import '../../settings/data/settings_repository.dart';

// State for the wizard
final ticketTypeProvider = StateProvider<String?>((ref) => null);
final ticketPriceProvider = StateProvider<double>((ref) => 0); // Default price

class CreateTicketWizard extends ConsumerStatefulWidget {
  const CreateTicketWizard({super.key});

  @override
  ConsumerState<CreateTicketWizard> createState() => _CreateTicketWizardState();
}

class _CreateTicketWizardState extends ConsumerState<CreateTicketWizard> {
  int _currentStep = 0;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _docController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _docController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (!_formKey.currentState!.validate()) return;
    }
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submit() async {
    final selectedEvent = ref.read(selectedEventProvider);
    final l10n = AppLocalizations.of(context)!;

    if (selectedEvent == null || selectedEvent['slug'] == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.pleaseSelectEvent)));
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      ref.read(loadingProvider.notifier).state = true;
      final type = ref.read(ticketTypeProvider);
      if (type == null) throw l10n.pleaseSelectTicketType;
      final price = ref.read(ticketPriceProvider);

      // Call the Repository which calls the Edge Function
      await ref.read(ticketRepositoryProvider).createTicket(
          eventSlug: selectedEvent['slug'],
          type: type,
          price: price,
          buyerName: _nameController.text.trim(),
          buyerEmail: _emailController.text.trim(),
          buyerDoc: _docController.text.trim(),
          buyerPhone: _phoneController.text.trim());

      if (mounted) {
        // Refresh ALL data providers to ensure reactivity
        ref.invalidate(dashboardMetricsProvider);
        ref.invalidate(recentActivityProvider);
        // We also invalidate ticketsProvider if it exists in the app
        try {
          // Use a dynamic check or import if possible, but since we know it exists:
          ref.invalidate(ticketsProvider);
        } catch (_) {}

        setState(() => _isLoading = false);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) ref.read(loadingProvider.notifier).state = false;
    }
  }

  void _showSuccessDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
              backgroundColor: isDark ? AppTheme.surfaceColor : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: AppTheme.successColor.withOpacity(0.5))),
              title: Column(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppTheme.successColor, size: 60),
                  const SizedBox(height: 16),
                  Text(l10n.ticketCreated,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              content: Text(l10n.pdfGeneratedDesc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54)),
              actions: [
                TextButton(
                    onPressed: () => context.go('/dashboard'),
                    child: Text(l10n.dashboard)),
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        // Reset
                        _currentStep = 0;
                        _nameController.clear();
                        _emailController.clear();
                        _phoneController.clear();
                        _docController.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor),
                    child: Text(l10n.createAnother)),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(l10n.createTicket),
      ),
      body: Column(
        children: [
          // STEPS INDICATOR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                _StepIndicator(
                    index: 0, current: _currentStep, label: l10n.ticketType),
                const Expanded(child: Divider(color: Colors.grey)),
                _StepIndicator(
                    index: 1,
                    current: _currentStep,
                    label: l10n.details), // Fallback to details if not in l10n
                const Expanded(child: Divider(color: Colors.grey)),
                _StepIndicator(
                    index: 2, current: _currentStep, label: l10n.confirm),
              ],
            ),
          ),

          Expanded(
            child: GlassCard(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepContent(theme),
                ),
              ),
            ),
          ),

          // ACTIONS
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                      child: TextButton(
                          onPressed: _prevStep, child: Text(l10n.back))),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: NeonButton(
                    text: _currentStep == 2 ? l10n.createAndSend : l10n.next,
                    isLoading: _isLoading,
                    onPressed: (_currentStep == 0 &&
                            ref.watch(ticketTypeProvider) == null)
                        ? null
                        : (_currentStep == 2 ? _submit : _nextStep),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStepContent(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return const _StepOneType();
      case 1:
        return _StepTwoDetails(
          nameController: _nameController,
          emailController: _emailController,
          phoneController: _phoneController,
          docController: _docController,
          formKey: _formKey,
        );
      case 2:
        return _StepThreeConfirm(
          ref: ref,
          name: _nameController.text,
          email: _emailController.text,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StepIndicator extends StatelessWidget {
  final int index;
  final int current;
  final String label;
  const _StepIndicator(
      {required this.index, required this.current, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = index <= current;
    final isCompleted = index < current;
    final color = isActive
        ? AppTheme.primaryColor
        : (isDark ? Colors.white24 : Colors.black12);

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.2) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2)),
          child: Center(
              child: isCompleted
                  ? Icon(Icons.check, size: 16, color: color)
                  : Text('${index + 1}',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12))
      ],
    );
  }
}

final myEventStaffProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final selectedEvent = ref.watch(selectedEventProvider);
  final user = ref.watch(userProvider);
  if (selectedEvent == null || user == null) return null;
  return ref
      .watch(settingsRepositoryProvider)
      .getMyEventStaff(selectedEvent['id'], user.id);
});

class _StepOneType extends ConsumerWidget {
  const _StepOneType();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedEvent = ref.watch(selectedEventProvider);
    final ticketTypesAsync =
        ref.watch(ticketTypesProvider(selectedEvent?['id'] ?? ''));
    final selectedType = ref.watch(ticketTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(userRoleProvider);
    final myStaffAsync = ref.watch(myEventStaffProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.selectTicketType,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            )),
        const SizedBox(height: 20),
        ticketTypesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Text('${l10n.error}: $e',
              style: const TextStyle(color: Colors.red)),
          data: (types) {
            if (types.isEmpty) {
              return Text(l10n.noTicketTypesAvailable,
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54));
            }

            // Permission Filter
            final isAdmin = role == AppRoles.admin;

            final allTypes = types.where((t) {
              if (isAdmin) return true;
              // Filter out Staff for non-admins
              if (t['category'] == 'staff') return false;
              return true;
            }).toList();

            // Sort: Special/Invited first, then Standard
            // Or keep them mixed but sorted by category priority?
            // User wants "symmetrical". GridView works best with a single list.
            // But maybe section headers are better?
            // Let's use two Grids or one Grid with sections.
            // User said "aesthetic symmetrical". One big grid is often most symmetrical.

            // Let's split but use same GridDelegate
            var specialTypes = allTypes
                .where((t) =>
                    ['staff', 'guest', 'invitation'].contains(t['category']))
                .toList();
            final standardTypes = allTypes
                .where((t) =>
                    !['staff', 'guest', 'invitation'].contains(t['category']))
                .toList();

            // Sort order for special: Staff, Guest, Invitation
            specialTypes.sort((a, b) {
              final order = {'staff': 0, 'guest': 1, 'invitation': 2};
              return (order[a['category']] ?? 99)
                  .compareTo(order[b['category']] ?? 99);
            });

            final myStaffRecord = myStaffAsync.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (specialTypes.isNotEmpty) ...[
                  const Text("Special Access",
                      style: TextStyle(
                          color: AppTheme.accentPurple,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.15, // Reduced from 1.3
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16),
                      itemCount: specialTypes.length,
                      itemBuilder: (context, index) {
                        final t = specialTypes[index];
                        return _buildChip(t, selectedType, ref, isDark,
                            myStaffRecord, isAdmin);
                      }),
                  const SizedBox(height: 24),
                ],
                if (standardTypes.isNotEmpty) ...[
                  Text(l10n.ticketType,
                      style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.15, // Reduced from 1.3
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16),
                      itemCount: standardTypes.length,
                      itemBuilder: (context, index) {
                        final t = standardTypes[index];
                        return _buildChip(t, selectedType, ref, isDark,
                            myStaffRecord, isAdmin);
                      }),
                ]
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildChip(Map<String, dynamic> t, String? selectedType, WidgetRef ref,
      bool isDark, Map<String, dynamic>? myStaffRecord, bool isAdmin) {
    final category = t['category'];

    bool enabled = true;
    String? subtitle;

    if (!isAdmin && myStaffRecord != null) {
      if (category == 'guest') {
        final used = myStaffRecord['quota_guest_used'] ?? 0;
        final total = myStaffRecord['quota_guest'] ?? 0;
        if (used >= total) enabled = false;
        subtitle = "$used / $total (VIP)";
      } else if (category == 'invitation') {
        final used = myStaffRecord['quota_invitation_used'] ?? 0;
        final total = myStaffRecord['quota_invitation'] ?? 0;
        if (used >= total) enabled = false;
        subtitle = "$used / $total";
      } else if (category == 'standard') {
        final used = myStaffRecord['quota_standard_used'] ?? 0;
        final total = myStaffRecord['quota_standard'] ?? 0;
        if (used >= total) enabled = false;
        subtitle = "$used / $total";
      }
    }

    IconData icon = Icons.airplane_ticket;
    if (category == 'staff') {
      icon = Icons.badge;
    } else if (category == 'guest') {
      icon = Icons.star;
    } else if (category == 'invitation') {
      icon = Icons.mail;
    }

    // Color Parsing
    Color ticketColor = AppTheme.primaryColor;
    if (t['color'] != null) {
      try {
        final hex = t['color'].toString().replaceAll('#', '');
        ticketColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    } else {
      // Fallback for special types if database color is missing
      if (category == 'staff') {
        ticketColor = const Color(0xFF3B82F6); // Blue
      } else if (category == 'invitation') {
        ticketColor = const Color(0xFFA855F7); // Purple
      } else if (category == 'guest') {
        ticketColor = const Color(0xFFEC4899); // Pink
      }
    }

    return _TypeChip(
      label: t['name'],
      price: (t['price'] as num).toDouble(),
      selected: selectedType == t['name'],
      ref: ref,
      icon: icon,
      isSpecial: ['staff', 'guest', 'invitation'].contains(category),
      enabled: enabled,
      subtitle: subtitle,
      color: ticketColor, // Pass the color
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final double price;
  final bool selected;
  final WidgetRef ref;
  final IconData? icon;
  final bool isSpecial;
  final bool enabled;
  final String? subtitle;
  final Color color;

  const _TypeChip({
    required this.label,
    required this.price,
    required this.selected,
    required this.ref,
    this.icon,
    this.isSpecial = false,
    this.enabled = true,
    this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use the passed color as the base
    final baseColor = enabled ? color : Colors.grey.withOpacity(0.3);

    return GestureDetector(
      onTap: enabled
          ? () {
              ref.read(ticketTypeProvider.notifier).state = label;
              ref.read(ticketPriceProvider.notifier).state = price;
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // Padding managed by Grid layout essentially, but internal padding needed
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: selected
                ? baseColor.withOpacity(0.15)
                : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected
                    ? baseColor
                    : (isDark ? Colors.white10 : Colors.black12),
                width: selected ? 2 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: baseColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ]
                : null),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  color: enabled ? baseColor : Colors.grey,
                  size: 24), // Reduced from 28
              const SizedBox(height: 6), // Reduced from 8
            ],
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 4),
            Text(price == 0 ? 'FREE' : '\$${price.toStringAsFixed(0)}',
                style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 12)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: TextStyle(
                      color: enabled ? baseColor : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }
}

class _StepTwoDetails extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController docController;
  final GlobalKey<FormState> formKey;

  const _StepTwoDetails(
      {required this.nameController,
      required this.emailController,
      required this.phoneController,
      required this.docController,
      required this.formKey});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: formKey,
      child: Column(
        children: [
          CustomInput(
              label: l10n.fullName,
              controller: nameController,
              prefixIcon: Icons.person,
              validator: (v) => v!.isEmpty ? l10n.required : null),
          const SizedBox(height: 16),
          CustomInput(
              label: l10n.email,
              controller: emailController,
              prefixIcon: Icons.email,
              validator: (v) =>
                  v!.contains('@') ? null : '${l10n.error}: ${l10n.email}'),
          const SizedBox(height: 16),
          CustomInput(
              label: l10n.phoneNumber,
              controller: phoneController,
              prefixIcon: Icons.phone,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          CustomInput(
              label: l10n.idNumber,
              controller: docController,
              prefixIcon: Icons.badge),
        ],
      ),
    );
  }
}

class _StepThreeConfirm extends StatelessWidget {
  final WidgetRef ref;
  final String name;
  final String email;

  const _StepThreeConfirm(
      {required this.ref, required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(ticketTypeProvider);
    final price = ref.watch(ticketPriceProvider);
    final selectedEvent = ref.watch(selectedEventProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        const Icon(Icons.receipt_long, size: 60, color: AppTheme.accentPurple),
        const SizedBox(height: 20),
        Text(l10n.reviewDetails,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            )),
        const SizedBox(height: 24),
        _rowInfo(l10n.event, selectedEvent?['name'] ?? 'N/A', isDark),
        _rowInfo(l10n.ticketType, type ?? 'N/A', isDark),
        _rowInfo(l10n.price, '\$${price.toStringAsFixed(0)}', isDark),
        const Divider(height: 32),
        _rowInfo(l10n.guest, name, isDark),
        _rowInfo(l10n.email, email, isDark),
      ],
    );
  }

  Widget _rowInfo(String label, String value, bool isDark,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
