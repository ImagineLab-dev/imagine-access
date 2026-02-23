import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/glass_card.dart';
import '../data/scanner_repository.dart';
import '../../events/presentation/event_state.dart';
import '../../../core/utils/device_id_service.dart';
import '../../../core/ui/loading_overlay.dart';
import 'package:imagine_access/features/tickets/presentation/ticket_list_screen.dart';
import 'package:imagine_access/features/dashboard/data/dashboard_repository.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  late MobileScannerController _cameraController;
  bool _isProcessing = false;
  Map<String, dynamic>? _scanResult; // To show overlay

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    super.dispose();
  }

  // Handle Lifecycle changes to stop/start camera
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraController.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _cameraController.start();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _processCode(barcode.rawValue!);
        break; // Process only first code
      }
    }
  }

  Future<void> _processCode(String code) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      ref.read(loadingProvider.notifier).state = true;
      final deviceId = await ref.read(deviceIdProvider.future);
      final selectedEvent = ref.read(selectedEventProvider);

      if (selectedEvent == null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.pleaseSelectEvent)));
          context.pop();
        }
        return;
      }

      final result = await ref
          .read(scannerRepositoryProvider)
          .validateQr(code, deviceId, null, selectedEvent['id'] as String);

      if (mounted) {
        // Refresh Ticket List & Dashboard
        ref.invalidate(ticketsProvider);
        ref.invalidate(dashboardMetricsProvider);
        ref.invalidate(recentActivityProvider);

        setState(() {
          _scanResult = result;
        });

        final allowed = result['allowed'] == true;
        if (allowed) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          HapticFeedback.heavyImpact();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) ref.read(loadingProvider.notifier).state = false;
    }
  }

  void _resetScanner() {
    setState(() {
      _scanResult = null;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // If we have a result, show the Full Screen Result Overlay
    if (_scanResult != null) {
      return _ResultOverlay(scanResult: _scanResult!, onDismiss: _resetScanner);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),

          // Header / Back Button
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => context.pop(),
            ).animate().fade(),
          ),

          // Flash Toggle
          Positioned(
            top: 50,
            right: 20,
            child: ValueListenableBuilder(
              valueListenable: _cameraController,
              builder: (context, value, child) {
                return IconButton(
                  icon: Icon(
                      value.torchState == TorchState.on
                          ? Icons.flash_on
                          : Icons.flash_off,
                      color: Colors.white,
                      size: 30),
                  onPressed: () => _cameraController.toggleTorch(),
                );
              },
            ),
          ),

          // Scanner Frame Overlay (Interactive UI)
          Center(
              child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
                border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.5), width: 2),
                borderRadius: BorderRadius.circular(24)),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Corner(isTop: true, isLeft: true),
                      _Corner(isTop: true, isLeft: false)
                    ]),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Corner(isTop: false, isLeft: true),
                      _Corner(isTop: false, isLeft: false)
                    ]),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))),

          // Footer Status
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_scanner,
                        color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Text(l10n.readyToScan,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ],
                )).animate().slideY(begin: 1, end: 0),
          )
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final bool isTop;
  final bool isLeft;
  const _Corner({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    const double size = 30;
    const double thickness = 4;
    const color = AppTheme.primaryColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? const BorderSide(color: color, width: thickness)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: color, width: thickness)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: color, width: thickness)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: color, width: thickness)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: isTop && isLeft ? const Radius.circular(16) : Radius.zero,
            topRight:
                isTop && !isLeft ? const Radius.circular(16) : Radius.zero,
            bottomLeft:
                !isTop && isLeft ? const Radius.circular(16) : Radius.zero,
            bottomRight:
                !isTop && !isLeft ? const Radius.circular(16) : Radius.zero,
          )),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  final Map<String, dynamic> scanResult;
  final VoidCallback onDismiss;

  const _ResultOverlay({required this.scanResult, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final allowed = scanResult['allowed'] as bool;
    final color = allowed ? AppTheme.accentGreen : AppTheme.errorColor;
    final icon = allowed ? Icons.check_circle : Icons.cancel;
    final ticket = scanResult['ticket'];

    return Scaffold(
      backgroundColor: color, // Full screen color flood
      body: SafeArea(
        child: InkWell(
          onTap: onDismiss,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 120, color: Colors.white)
                        .animate()
                        .scale(duration: 300.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 30),
                    Text(scanResult['message'].toString().toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1))
                        .animate()
                        .fade()
                        .slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 40),

                    // Ticket Details Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 20,
                                offset: Offset(0, 10))
                          ]),
                      child: Column(
                        children: [
                          Text(ticket['buyer_name'],
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(ticket['type'],
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ),
                          if (!allowed &&
                              scanResult['result'] == 'already_used') ...[
                            const Divider(height: 32),
                            Text(l10n.firstEntry,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            Text(ticket['scanned_at'] ?? 'Unknown',
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                          ]
                        ],
                      ),
                    ).animate().slideY(begin: 0.5, end: 0, delay: 100.ms)
                  ],
                ),
              ),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(l10n.tapToDismiss,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              letterSpacing: 2))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fade(begin: 0.5, end: 1),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
