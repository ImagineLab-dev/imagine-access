import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/glass_scaffold.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/custom_input.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../data/settings_repository.dart';
import '../../../core/utils/device_id_service.dart';

class DeviceManagementScreen extends ConsumerWidget {
  const DeviceManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesListProvider);
    final currentDeviceAsync = ref.watch(deviceIdProvider);

    return GlassScaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
              onPressed: () => _showAddDeviceDialog(
                  context, ref, currentDeviceAsync.valueOrNull),
              icon: const Icon(Icons.add_circle_outline))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: devicesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
                data: (devices) {
                  if (devices.isEmpty) {
                    return const Center(child: Text('No devices registered.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final isEnabled = (device['enabled'] as bool?) ?? true;
                      final isCurrent =
                          device['device_id'] == currentDeviceAsync.valueOrNull;

                      return GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.mobile_friendly,
                                color: isEnabled ? Colors.green : Colors.grey,
                                size: 30),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(device['alias'] ?? 'Unknown',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  Text(isEnabled ? 'Active' : 'Disabled',
                                      style: TextStyle(
                                          color: isEnabled
                                              ? Colors.green
                                              : Colors.grey,
                                          fontSize: 12)),
                                  if (isCurrent)
                                    Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: AppTheme.neonBlue
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        child: const Text("THIS DEVICE",
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.neonBlue,
                                                fontWeight: FontWeight.bold))),
                                  if (!isEnabled)
                                    const Text("(Disabled)",
                                        style: TextStyle(
                                            color: Colors.red, fontSize: 12)),
                                ],
                              ),
                            ),
                            Switch(
                                value: isEnabled,
                                activeColor: AppTheme.neonBlue,
                                onChanged: (val) async {
                                  try {
                                    await ref
                                        .read(settingsRepositoryProvider)
                                        .toggleDevice(device['device_id'], val);
                                    ref.invalidate(devicesListProvider);
                                    if (context.mounted) {
                                      ErrorHandler.showSuccessSnackBar(
                                          context,
                                          val
                                              ? 'Device enabled'
                                              : 'Device disabled');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ErrorHandler.showErrorSnackBar(
                                          context, 'Error: $e');
                                    }
                                  }
                                }),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(context, ref,
                                  device['device_id'], device['alias']),
                            )
                          ],
                        ),
                      );
                    },
                  );
                }),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String deviceId, String alias) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Device?'),
        content: Text('Are you sure you want to delete "$alias"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(settingsRepositoryProvider)
                    .deleteDevice(deviceId);
                ref.invalidate(devicesListProvider);
                if (context.mounted) {
                  ErrorHandler.showSuccessSnackBar(context, 'Device deleted');
                }
              } catch (e) {
                if (context.mounted) {
                  ErrorHandler.showErrorSnackBar(context, 'Error deleting: $e');
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddDeviceDialog(
      BuildContext context, WidgetRef ref, String? currentDeviceId) {
    final aliasCtrl = TextEditingController();
    // Auto-generate device UUID internally
    final deviceId =
        currentDeviceId ?? 'DEV-${Random().nextInt(900000) + 100000}';
    final pin = (Random().nextInt(9000) + 1000).toString();
    final formKey = GlobalKey<FormState>();

    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add New Device'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomInput(
                    label: 'Alias (e.g. Gate 1)',
                    controller: aliasCtrl,
                    icon: Icons.badge_outlined,
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('PIN: $pin',
                                style: const TextStyle(
                                    color: AppTheme.neonBlue,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.copy,
                                  size: 18, color: AppTheme.neonBlue),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: pin));
                                ErrorHandler.showSuccessSnackBar(
                                    context, 'PIN copied!');
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                            '⚠️ Save this PIN now. It cannot be viewed again.',
                            style: TextStyle(color: Colors.amber, fontSize: 12),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setState(() => isLoading = true);

                        try {
                          await ref
                              .read(settingsRepositoryProvider)
                              .createDevice(
                                  deviceId: deviceId,
                                  alias: aliasCtrl.text.trim(),
                                  pinHash: pin);

                          ref.invalidate(devicesListProvider);

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ErrorHandler.showSuccessSnackBar(
                                context, 'Device created successfully!');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setState(() => isLoading = false);
                            ErrorHandler.showErrorSnackBar(
                              context,
                              'Failed to create device: $e',
                              onRetry: () {},
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }
}
