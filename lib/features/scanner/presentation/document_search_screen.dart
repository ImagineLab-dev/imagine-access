import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/glass_scaffold.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/neon_button.dart';
import '../../events/presentation/event_state.dart';
import '../data/scanner_repository.dart';
import '../../../core/utils/device_id_service.dart';
import '../../../core/ui/loading_overlay.dart';
import 'package:imagine_access/features/tickets/presentation/ticket_list_screen.dart';
import 'package:imagine_access/features/dashboard/data/dashboard_repository.dart';

class DocumentSearchScreen extends ConsumerStatefulWidget {
  const DocumentSearchScreen({super.key});

  @override
  ConsumerState<DocumentSearchScreen> createState() =>
      _DocumentSearchScreenState();
}

class _DocumentSearchScreenState extends ConsumerState<DocumentSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String _searchType = 'doc'; // 'doc' or 'phone'
  bool _isLoading = false;
  List<Map<String, dynamic>> _foundTickets = [];
  Map<String, dynamic>? _scanResult;

  Future<void> _handleSearch() async {
    if (_queryController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _foundTickets = [];
    });
    try {
      final selectedEvent = ref.read(selectedEventProvider);
      if (selectedEvent == null) throw 'Seleccione un evento';

      final results = await ref.read(scannerRepositoryProvider).searchTickets(
            query: _queryController.text.trim(),
            type: _searchType,
            eventId: selectedEvent['id'],
          );

      setState(() {
        _foundTickets = results;
        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se encontró ningún registro')));
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleValidate(Map<String, dynamic> ticket) async {
    setState(() => _isLoading = true);
    try {
      ref.read(loadingProvider.notifier).state = true;
      final deviceId = await ref.read(deviceIdProvider.future);

      final result = await ref.read(scannerRepositoryProvider).validateById(
            ticketId: ticket['id'],
            reason: _reasonController.text.isEmpty
                ? 'Validación Manual'
                : _reasonController.text,
            deviceId: deviceId,
          );

      // Refresh Ticket List & Dashboard
      ref.invalidate(ticketsProvider);
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(recentActivityProvider);

      setState(() {
        _scanResult = result;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) ref.read(loadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_scanResult != null) {
      return _ManualResultView(
          result: _scanResult!,
          onDismiss: () => setState(() {
                _scanResult = null;
                _foundTickets = [];
                _queryController.clear();
              }));
    }

    return GlassScaffold(
      appBar: AppBar(title: const Text('BÚSQUEDA MANUAL')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleccione el tipo de búsqueda e ingrese los datos para validar la entrada.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Consumer(builder: (context, ref, _) {
              final selectedEvent = ref.watch(selectedEventProvider);

              return Text(
                'EVENTO: ${selectedEvent?['name'] ?? 'NINGUNO'} (ID: ${selectedEvent?['id'] ?? 'N/A'})',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 10),
              );
            }),
            const SizedBox(height: 30),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Dropdown for search type
                  DropdownButtonFormField<String>(
                    value: _searchType,
                    decoration: const InputDecoration(
                      labelText: 'BUSCAR POR',
                      prefixIcon: Icon(Icons.manage_search),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'doc', child: Text('DOCUMENTO (CI / DNI)')),
                      DropdownMenuItem(value: 'phone', child: Text('TELÉFONO')),
                    ],
                    onChanged: (v) => setState(() {
                      _searchType = v!;
                      _foundTickets = [];
                    }),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      labelText: _searchType == 'doc'
                          ? 'NÚMERO DE DOCUMENTO'
                          : 'NÚMERO DE TELÉFONO',
                      prefixIcon: Icon(_searchType == 'doc'
                          ? Icons.badge_outlined
                          : Icons.phone_android),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                text: 'BUSCAR ASISTENTE',
                icon: Icons.search,
                isLoading: _isLoading && _foundTickets.isEmpty,
                onPressed: _handleSearch,
              ),
            ),
            if (_foundTickets.isNotEmpty) ...[
              const SizedBox(height: 30),
              Text('${_foundTickets.length} RESULTADOS ENCONTRADOS:',
                  style: const TextStyle(
                      color: AppTheme.neonBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2)),
              const SizedBox(height: 10),
              ..._foundTickets.map((ticket) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildTicketResultCard(ticket),
                  )),
            ],
          ],
        ).animate().fade().slideY(begin: 0.1, end: 0),
      ),
    );
  }

  Widget _buildTicketResultCard(Map<String, dynamic> ticket) {
    final status = ticket['status'] ?? 'valid';
    final isValid = status == 'valid';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ticket['buyer_name'].toString().toUpperCase(),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(ticket['type'].toString().toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.accentPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const Divider(height: 30),
          _infoRow('DNI/CI:', (ticket['buyer_doc'] ?? 'N/A').toString()),
          _infoRow('TEL:', (ticket['buyer_phone'] ?? 'N/A').toString()),
          if (isValid) ...[
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'MOTIVO DE VALIDACIÓN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.assignment_late_outlined),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'QR no legible', child: Text('QR no legible')),
                DropdownMenuItem(
                    value: 'Email no recibido',
                    child: Text('Email no recibido')),
                DropdownMenuItem(
                    value: 'Validación Manual',
                    child: Text('Otro / Validación Manual')),
              ],
              onChanged: (value) {
                if (value != null) _reasonController.text = value;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                text: 'CONFIRMAR Y VALIDAR',
                icon: Icons.check_circle_outline,
                isLoading: _isLoading,
                onPressed: () => _handleValidate(ticket),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'ESTE TICKET YA FUE UTILIZADO O NO ES VÁLIDO',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12)),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              )),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isValid = status == 'valid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isValid
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isValid ? Colors.green : Colors.red),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: isValid ? Colors.green : Colors.red,
            fontSize: 10,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ManualResultView extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onDismiss;
  const _ManualResultView({required this.result, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final success = result['success'] == true;
    final color = success ? AppTheme.accentGreen : AppTheme.errorColor;
    final ticket = result['ticket'];

    return Scaffold(
      backgroundColor: color,
      body: InkWell(
        onTap: onDismiss,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(success ? Icons.check_circle : Icons.error,
                  size: 100, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                success ? 'INGRESO AUTORIZADO' : 'ERROR DE VALIDACIÓN',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              if (ticket != null) ...[
                const SizedBox(height: 40),
                GlassCard(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(ticket['buyer_name'],
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(ticket['type'],
                          style: const TextStyle(color: Colors.white70)),
                      const Divider(height: 30),
                      const Text('VALIDACIÓN MANUAL AUDITADA',
                          style:
                              TextStyle(fontSize: 10, color: Colors.white54)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 60),
              const Text('TOCA PARA CONTINUAR',
                  style: TextStyle(color: Colors.white54, letterSpacing: 2)),
            ],
          ).animate().scale(),
        ),
      ),
    );
  }
}
