import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/pin_hasher.dart';
import '../privacy_providers.dart';

/// Full-screen PIN pad, served as the /unlock route whenever the session is
/// locked (the router redirects to it; unlocking bounces back to the
/// journal via the same redirect).
///
/// Auto-submits once the stored PIN length is reached. A wrong entry shakes
/// the dots, shows how many attempts remain and clears the input; after
/// [PinLockoutPolicy.maxFailures] consecutive failures the pad is replaced by
/// a 30-second countdown (driven by the controller's injectable clock).
class PinLockPage extends ConsumerStatefulWidget {
  const PinLockPage({super.key});

  @override
  ConsumerState<PinLockPage> createState() => _PinLockPageState();
}

class _PinLockPageState extends ConsumerState<PinLockPage>
    with SingleTickerProviderStateMixin {
  String _entered = '';
  String? _message;
  Timer? _cooldownTimer;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void initState() {
    super.initState();
    _ensureCooldownTimer();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _shake.dispose();
    super.dispose();
  }

  AppLockController get _controller =>
      ref.read(appLockControllerProvider.notifier);

  /// Keeps a 1-second ticker alive exactly while the lockout cooldown runs.
  /// The countdown reads the controller's injectable clock, so tests advance
  /// a manual clock instead of waiting real seconds.
  void _ensureCooldownTimer() {
    final cooling = _controller.isCoolingDown;
    if (cooling && _cooldownTimer == null) {
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(_ensureCooldownTimer);
      });
    } else if (!cooling && _cooldownTimer != null) {
      _cooldownTimer!.cancel();
      _cooldownTimer = null;
      if (_message != null && _message!.startsWith('Too many')) {
        _message = null;
      }
    }
  }

  void _onDigit(int digit) {
    if (_controller.isCoolingDown) return;
    final target =
        ref.read(appLockControllerProvider).pinLength ?? PinHasher.maxPinLength;
    if (_entered.length >= target) return;
    setState(() {
      _message = null;
      _entered += '$digit';
    });
    if (_entered.length == target) {
      _submit();
    }
  }

  void _onBackspace() {
    if (_controller.isCoolingDown || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit() async {
    final pin = _entered;
    final result = await _controller.submitPin(pin);
    if (!mounted) return;
    switch (result) {
      case PinSubmitResult.unlocked:
        // The router's redirect (refreshListenable) leaves /unlock as soon
        // as the state flips to unlocked.
        return;
      case PinSubmitResult.wrongPin:
        final left = _controller.remainingAttempts;
        setState(() {
          _entered = '';
          _message =
              'Incorrect PIN — $left ${left == 1 ? 'attempt' : 'attempts'} left';
        });
        _shake.forward(from: 0);
      case PinSubmitResult.cooldownStarted:
      case PinSubmitResult.coolingDown:
        setState(() {
          _entered = '';
          _ensureCooldownTimer();
        });
        _shake.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureCooldownTimer();
    final theme = Theme.of(context);
    final lockState = ref.watch(appLockControllerProvider);
    final target = lockState.pinLength ?? PinHasher.maxPinLength;
    final cooling = _controller.isCoolingDown;
    final message = cooling
        ? 'Too many attempts — try again in '
              '${_controller.remainingCooldown.inSeconds} s'
        : _message;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primaryContainer,
                    ),
                    child: const Icon(
                      Icons.nightlight_round,
                      size: 44,
                      color: AppTheme.lucidAccent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Oneiro is locked',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter your PIN to open your journal',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AnimatedBuilder(
                    animation: _shake,
                    builder: (context, child) {
                      final t = _shake.value;
                      final dx = math.sin(t * math.pi * 4) * 12 * (1 - t);
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < target; i++)
                          _PinDot(filled: i < _entered.length),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: Center(
                      child: message == null
                          ? null
                          : Text(
                              message,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cooling
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.error,
                              ),
                            ),
                    ),
                  ),
                  _PinPad(
                    enabled: !cooling,
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDot extends StatelessWidget {
  const _PinDot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppTheme.lucidAccent : Colors.transparent,
        border: Border.all(
          color: filled
              ? AppTheme.lucidAccent
              : theme.colorScheme.outlineVariant,
          width: 2,
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final digit in row)
                  _DigitKey(digit: digit, enabled: enabled, onTap: onDigit),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72, height: 72),
              _DigitKey(digit: 0, enabled: enabled, onTap: onDigit),
              SizedBox(
                width: 72,
                height: 72,
                child: IconButton(
                  tooltip: 'Delete',
                  onPressed: enabled ? onBackspace : null,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({
    required this.digit,
    required this.enabled,
    required this.onTap,
  });

  final int digit;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        shape: const CircleBorder(),
        color: theme.colorScheme.surfaceContainerHigh,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? () => onTap(digit) : null,
          child: Center(
            child: Text('$digit', style: theme.textTheme.headlineSmall),
          ),
        ),
      ),
    );
  }
}
