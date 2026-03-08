import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imagine_access/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/custom_input.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/glass_scaffold.dart';
import '../../../core/utils/device_id_service.dart';
import '../../../core/utils/error_handler.dart';
import '../data/settings_repository.dart';

class DeviceManagementScreen extends ConsumerWidget {
  const DeviceManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesListProvider);
    final currentDeviceAsync = ref.watch(deviceIdProvider);
    final l10n = AppLocalizations.of(context)!;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(l10n.devices),
        actions: [
          IconButton(
            onPressed: () => _showAddDeviceDialog(context, ref, currentDeviceAsync.valueOrNull),
            icon: const Icon(Icons.add_circle_outline),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: devicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('${l10n.error}: $e')),
              data: (devices) {
                if (devices.isEmpty) {
                  return Center(child: Text(l10n.noDevicesRegistered));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final isEnabled = (device['enabled'] as bool?) ?? true;
                    final isCurrent = device['device_id'] == currentDeviceAsync.valueOrNull;

                    return GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mobile_friendly,
                            color: isEnabled ? Colors.green : Colors.grey,
                            size: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device['alias'] ?? l10n.unknown,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  isEnabled ? l10n.active : l10n.disabled,
                                  style: TextStyle(
                                    color: isEnabled ? Colors.green : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                if (isCurrent)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.neonBlue.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      l10n.thisDevice,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.neonBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (!isEnabled)
                                  Text(
                                    '(${l10n.disabled})',
                                    style: const TextStyle(color: Colors.red, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isEnabled,
                            activeThumbColor: AppTheme.neonBlue,
                            onChanged: (val) async {
                              try {
                                await ref.read(settingsRepositoryProvider).toggleDevice(device['device_id'], val);
                                ref.invalidate(devicesListProvider);
                                if (context.mounted) {
                                  ErrorHandler.showSuccessSnackBar(
                                    context,
                                    val ? l10n.deviceEnabled : l10n.deviceDisabled,
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ErrorHandler.showErrorSnackBar(context, '${l10n.error}: $e');
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(
                              context,
                              ref,
                              device['device_id'],
                              device['alias'] ?? l10n.unknown,
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String deviceId, String alias) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDeviceQuestion),
        content: Text(l10n.confirmDeleteAlias(alias)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(settingsRepositoryProvider).deleteDevice(deviceId);
                ref.invalidate(devicesListProvider);
                if (context.mounted) {
                  ErrorHandler.showSuccessSnackBar(context, l10n.deviceDeleted);
                }
              } catch (e) {
                if (context.mounted) {
                  ErrorHandler.showErrorSnackBar(
                    context,
                    l10n.errorDeletingDevice(e.toString()),
                  );
                }
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showAddDeviceDialog(BuildContext context, WidgetRef ref, String? currentDeviceId) {
    final l10n = AppLocalizations.of(context)!;

    final aliasCtrl = TextEditingController();
    final deviceId = currentDeviceId ?? 'DEV-${Random().nextInt(900000) + 100000}';
    final pin = (Random().nextInt(9000) + 1000).toString();
    final formKey = GlobalKey<FormState>();

    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.addNewDevice),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomInput(
                    label: l10n.alias,
                    controller: aliasCtrl,
                    icon: Icons.badge_outlined,
                    validator: (v) => v?.isEmpty == true ? l10n.required : null,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${l10n.pinLabel}: $pin',
                              style: const TextStyle(
                                color: AppTheme.neonBlue,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18, color: AppTheme.neonBlue),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: pin));
                                ErrorHandler.showSuccessSnackBar(context, l10n.pinCopied);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.savePinWarning,
                          style: const TextStyle(color: Colors.amber, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
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
                          await ref.read(settingsRepositoryProvider).createDevice(
                                deviceId: deviceId,
                                alias: aliasCtrl.text.trim(),
                                pinHash: pin,
                              );

                          ref.invalidate(devicesListProvider);

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ErrorHandler.showSuccessSnackBar(context, l10n.deviceCreatedSuccessfully);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setState(() => isLoading = false);
                            ErrorHandler.showErrorSnackBar(
                              context,
                              l10n.failedToCreateDevice(e.toString()),
                              onRetry: () {},
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.create),
              ),
            ],
          );
        },
      ),
    );
  }
}
