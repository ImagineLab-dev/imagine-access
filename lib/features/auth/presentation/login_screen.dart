import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_controller.dart';
import '../../../core/ui/glass_scaffold.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/custom_input.dart';
import '../../../core/ui/neon_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/error_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRegistering = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _orgController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _pinController = TextEditingController();

  final _formKeyUser = GlobalKey<FormState>();
  final _formKeyDevice = GlobalKey<FormState>();

  // Rate limiting
  int _loginAttempts = 0;
  DateTime? _lockoutEnd;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild to switch tab content
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _orgController.dispose();
    _deviceIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  bool _isLockedOut() {
    if (_lockoutEnd != null && DateTime.now().isBefore(_lockoutEnd!)) {
      final remaining = _lockoutEnd!.difference(DateTime.now()).inSeconds;
      ErrorHandler.showErrorSnackBar(
        context,
        'Demasiados intentos. Espere ${remaining}s.',
      );
      return true;
    }
    // Reset lockout if expired
    if (_lockoutEnd != null && DateTime.now().isAfter(_lockoutEnd!)) {
      _loginAttempts = 0;
      _lockoutEnd = null;
    }
    return false;
  }

  void _registerFailedAttempt() {
    _loginAttempts++;
    if (_loginAttempts >= 5) {
      _lockoutEnd = DateTime.now().add(const Duration(seconds: 30));
    }
  }

  Future<void> _handleUserAuth() async {
    if (!_formKeyUser.currentState!.validate()) return;
    if (_isLockedOut()) return;
    try {
      if (_isRegistering) {
        await ref.read(authControllerProvider.notifier).signUpEmail(
              _emailController.text.trim(),
              _passwordController.text.trim(),
              _nameController.text.trim(),
              _orgController.text.trim(),
            );
      } else {
        await ref.read(authControllerProvider.notifier).loginEmail(
              _emailController.text.trim(),
              _passwordController.text.trim(),
            );
      }
      _loginAttempts = 0; // Reset on success
      if (mounted) context.go('/dashboard');
    } catch (e) {
      _registerFailedAttempt();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ErrorHandler.showErrorSnackBar(context, '${l10n.error}: $e');
      }
    }
  }

  Future<void> _loginDevice() async {
    if (!_formKeyDevice.currentState!.validate()) return;
    if (_isLockedOut()) return;

    // TEMP: Bypass login para testing (ONLY in debug mode)
    if (kDebugMode &&
        _deviceIdController.text == 'test' &&
        _pinController.text == '1234') {
      // Crear sesión de dispositivo simulada
      await ref
          .read(deviceProvider.notifier)
          .setSession('test-device', 'test', '1234');
      if (mounted) {
        ErrorHandler.showSuccessSnackBar(context, 'Login exitoso (modo test)');
        context.go('/dashboard');
      }
      return;
    }

    try {
      await ref.read(authControllerProvider.notifier).loginDevice(
            _deviceIdController.text.trim(),
            _pinController.text.trim(),
          );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      _registerFailedAttempt();
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Credenciales inválidas. Usa test/1234 para pruebas.',
          onRetry: _loginDevice,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final textColor = isDark ? AppTheme.darkText : AppTheme.lightText;

    return GlassScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                Icon(Icons.qr_code_scanner_rounded,
                        size: 56, color: theme.colorScheme.primary)
                    .animate()
                    .scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 24),
                Text(l10n.appTitle,
                        style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            letterSpacing: 0.5))
                    .animate()
                    .fade()
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 32),
                GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 40,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: textColor.withOpacity(0.6),
                          labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              fontSize: 13),
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          overlayColor:
                              MaterialStateProperty.all(Colors.transparent),
                          tabs: [
                            Tab(text: l10n.adminRRPP),
                            Tab(text: l10n.doorAccess),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _tabController.index == 0
                            ? Form(
                                key: _formKeyUser,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isRegistering) ...[
                                      CustomInput(
                                        label: l10n.displayName,
                                        controller: _nameController,
                                        prefixIcon: Icons.person_outline,
                                        validator: (v) => v?.isNotEmpty == true
                                            ? null
                                            : l10n.required,
                                      ),
                                      const SizedBox(height: 12),
                                      CustomInput(
                                        label: 'Nombre de la Empresa',
                                        controller: _orgController,
                                        prefixIcon: Icons.business_outlined,
                                        validator: (v) => v?.isNotEmpty == true
                                            ? null
                                            : 'Ingrese el nombre de su empresa',
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    CustomInput(
                                      label: l10n.email,
                                      controller: _emailController,
                                      prefixIcon: Icons.email_outlined,
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return l10n.required;
                                        }
                                        final emailRegex = RegExp(
                                            r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
                                        if (!emailRegex.hasMatch(v)) {
                                          return 'Email inválido';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    CustomInput(
                                      label: l10n.password,
                                      controller: _passwordController,
                                      prefixIcon: Icons.lock_outline,
                                      obscureText: true,
                                      validator: (v) {
                                        if (v?.isNotEmpty != true) {
                                          return l10n.required;
                                        }
                                        if (_isRegistering && v!.length < 6) {
                                          return 'La contraseña debe tener al menos 6 caracteres';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    NeonButton(
                                      text: (_isRegistering
                                              ? l10n.register
                                              : l10n.login)
                                          .toUpperCase(),
                                      isLoading: isLoading,
                                      onPressed: _handleUserAuth,
                                    ),
                                    const SizedBox(height: 4),
                                    TextButton(
                                      onPressed: () => setState(() =>
                                          _isRegistering = !_isRegistering),
                                      child: Text(
                                        _isRegistering
                                            ? l10n.alreadyHaveAccount
                                            : l10n.doNotHaveAccount,
                                        style: TextStyle(
                                            color: textColor.withOpacity(0.7),
                                            fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Form(
                                key: _formKeyDevice,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CustomInput(
                                      label: l10n.deviceID,
                                      controller: _deviceIdController,
                                      prefixIcon: Icons.devices,
                                      validator: (v) => v?.isNotEmpty == true
                                          ? null
                                          : l10n.required,
                                    ),
                                    const SizedBox(height: 12),
                                    CustomInput(
                                      label: l10n.pinCode,
                                      controller: _pinController,
                                      prefixIcon: Icons.pin,
                                      obscureText: true,
                                      keyboardType: TextInputType.number,
                                      validator: (v) => v?.isNotEmpty == true
                                          ? null
                                          : l10n.required,
                                    ),
                                    const SizedBox(height: 24),
                                    NeonButton(
                                      text: l10n.startAccess.toUpperCase(),
                                      isLoading: isLoading,
                                      onPressed: _loginDevice,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wb_sunny_rounded,
                              size: 18,
                              color: isDark
                                  ? textColor.withOpacity(0.3)
                                  : AppTheme.accentOrange),
                          const SizedBox(width: 12),
                          Switch(
                            value: isDark,
                            onChanged: (v) {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(themeNotifierProvider.notifier)
                                  .toggleTheme();
                            },
                            activeColor: AppTheme.accentBlue,
                            activeTrackColor:
                                AppTheme.accentBlue.withOpacity(0.2),
                            inactiveThumbColor: AppTheme.accentOrange,
                            inactiveTrackColor:
                                AppTheme.accentOrange.withOpacity(0.2),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.nightlight_round,
                              size: 18,
                              color: isDark
                                  ? AppTheme.accentBlue
                                  : textColor.withOpacity(0.3)),
                        ],
                      ).animate().fade(delay: 200.ms),
                    ],
                  ),
                ).animate().fade(delay: 100.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
