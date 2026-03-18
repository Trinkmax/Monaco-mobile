import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  static const int _pinLength = 4;

  int _step = 1; // 1 = enter, 2 = confirm
  String _firstPin = '';
  String _currentInput = '';
  String? _error;
  bool _loading = false;

  // ---- Key handlers ----
  void _onDigit(int digit) {
    if (_currentInput.length >= _pinLength || _loading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentInput += digit.toString();
      _error = null;
    });
  }

  void _onDelete() {
    if (_currentInput.isEmpty || _loading) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentInput = _currentInput.substring(0, _currentInput.length - 1);
      _error = null;
    });
  }

  Future<void> _onConfirm() async {
    if (_currentInput.length < _pinLength || _loading) return;
    HapticFeedback.mediumImpact();

    if (_step == 1) {
      // Save first PIN and go to confirmation
      setState(() {
        _firstPin = _currentInput;
        _currentInput = '';
        _step = 2;
      });
      return;
    }

    // Step 2: validate match
    if (_currentInput != _firstPin) {
      setState(() {
        _error = 'Los PIN no coinciden';
        _currentInput = '';
        _firstPin = '';
        _step = 1;
      });
      return;
    }

    // Match! Save to backend.
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.rpc('set_client_pin', params: {'p_pin': _currentInput});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PIN configurado'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() {
        _loading = false;
        _currentInput = '';
        _firstPin = '';
        _step = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        title: const Text('Configurar PIN',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: MonacoColors.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Title
            Text(
              _step == 1 ? 'Ingresa tu PIN' : 'Confirma tu PIN',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ).animate(key: ValueKey(_step)).fadeIn(duration: 300.ms),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              _step == 1
                  ? 'Elegí un PIN de $_pinLength dígitos'
                  : 'Volvé a ingresar tu PIN',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),

            const SizedBox(height: 32),

            // Dots
            _buildDots(),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              )
                  .animate()
                  .fadeIn(duration: 200.ms)
                  .shakeX(amount: 4, duration: 400.ms),
            ],

            // Loading
            if (_loading) ...[
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: MonacoColors.gold, strokeWidth: 2.5),
              ),
            ],

            const Spacer(flex: 2),

            // Numpad
            _buildNumpad(),

            SizedBox(height: bottomPad + 16),
          ],
        ),
      ),
    );
  }

  // ---- Dots ----
  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (i) {
        final filled = i < _currentInput.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: filled ? 18 : 16,
          height: filled ? 18 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                filled ? MonacoColors.gold : Colors.white.withOpacity(0.12),
            border: Border.all(
              color: filled
                  ? MonacoColors.gold
                  : Colors.white.withOpacity(0.2),
              width: 2,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: MonacoColors.gold.withOpacity(0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
        );
      }),
    );
  }

  // ---- Numpad ----
  Widget _buildNumpad() {
    final keys = <_NumpadKey>[
      _NumpadKey(label: '1', onTap: () => _onDigit(1)),
      _NumpadKey(label: '2', onTap: () => _onDigit(2)),
      _NumpadKey(label: '3', onTap: () => _onDigit(3)),
      _NumpadKey(label: '4', onTap: () => _onDigit(4)),
      _NumpadKey(label: '5', onTap: () => _onDigit(5)),
      _NumpadKey(label: '6', onTap: () => _onDigit(6)),
      _NumpadKey(label: '7', onTap: () => _onDigit(7)),
      _NumpadKey(label: '8', onTap: () => _onDigit(8)),
      _NumpadKey(label: '9', onTap: () => _onDigit(9)),
      _NumpadKey(
        icon: Icons.backspace_outlined,
        onTap: _onDelete,
      ),
      _NumpadKey(label: '0', onTap: () => _onDigit(0)),
      _NumpadKey(
        icon: Icons.check_circle,
        iconColor: _currentInput.length == _pinLength
            ? MonacoColors.gold
            : Colors.white24,
        onTap: _onConfirm,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 24,
        childAspectRatio: 1.4,
        children: keys.map((k) => _buildKey(k)).toList(),
      ),
    );
  }

  Widget _buildKey(_NumpadKey key) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: key.onTap,
        splashColor: MonacoColors.gold.withOpacity(0.15),
        child: Center(
          child: key.icon != null
              ? Icon(key.icon,
                  color: key.iconColor ?? Colors.white54, size: 26)
              : Text(
                  key.label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Numpad key model
// ---------------------------------------------------------------------------
class _NumpadKey {
  final String? label;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _NumpadKey({
    this.label,
    this.icon,
    this.iconColor,
    required this.onTap,
  });
}
