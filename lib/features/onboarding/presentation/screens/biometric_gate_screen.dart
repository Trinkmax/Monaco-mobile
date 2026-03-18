import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/biometric_service.dart';

class BiometricGateScreen extends ConsumerStatefulWidget {
  const BiometricGateScreen({super.key});

  @override
  ConsumerState<BiometricGateScreen> createState() =>
      _BiometricGateScreenState();
}

class _BiometricGateScreenState extends ConsumerState<BiometricGateScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final success = await BiometricService.authenticate(
        reason: 'Verifica tu identidad para continuar',
      );

      if (!mounted) return;

      if (success) {
        await ref.read(authProvider.notifier).completeBiometric();
        if (mounted) context.go('/home');
      } else {
        setState(() {
          _errorMessage = 'No se pudo verificar tu identidad. Intenta de nuevo.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  void _usePin() {
    context.go('/pin');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // --- Biometric icon ---
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: MonacoColors.gold.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MonacoColors.gold.withOpacity(0.15),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 72,
                    color: MonacoColors.gold,
                  ),
                )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.06, 1.06),
                      duration: 1500.ms,
                      curve: Curves.easeInOut,
                    )
                    .then()
                    .animate()
                    .fadeIn(duration: 600.ms),

                const SizedBox(height: 40),

                // --- Title ---
                const Text(
                  'Verifica tu identidad',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

                const SizedBox(height: 12),

                Text(
                  'Usa tu huella dactilar o Face ID\npara acceder a tu cuenta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 350.ms, duration: 500.ms),

                const SizedBox(height: 48),

                // --- Error message ---
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // --- Biometric button ---
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isAuthenticating ? null : _authenticateWithBiometrics,
                    icon: _isAuthenticating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black54,
                              ),
                            ),
                          )
                        : const Icon(Icons.fingerprint_rounded, size: 22),
                    label: Text(
                      _isAuthenticating ? 'Verificando...' : 'Usar biometria',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MonacoColors.gold,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                          MonacoColors.gold.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, duration: 400.ms),

                const SizedBox(height: 16),

                // --- PIN fallback link ---
                TextButton(
                  onPressed: _isAuthenticating ? null : _usePin,
                  child: Text(
                    'Usar PIN',
                    style: TextStyle(
                      fontSize: 15,
                      color: MonacoColors.gold.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
