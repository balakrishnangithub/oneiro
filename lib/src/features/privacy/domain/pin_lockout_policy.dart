/// Brute-force throttle for the PIN lock screen.
///
/// Pure Dart with an injectable clock, so the whole policy is unit-testable
/// without timers: after [maxFailures] consecutive wrong PINs the policy
/// enters a [cooldown] during which no attempt is allowed. Any successful
/// unlock resets the counter and clears the cooldown.
///
/// The policy is session-scoped (held by the app-lock controller in memory);
/// it is deliberately not persisted — a 30-second pause is a courtesy
/// barrier, not a security boundary, and keeping it in memory keeps the
/// threat model honest.
class PinLockoutPolicy {
  PinLockoutPolicy({
    DateTime Function()? clock,
    this.maxFailures = 5,
    this.cooldown = const Duration(seconds: 30),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Consecutive wrong PINs that trigger [cooldown].
  final int maxFailures;

  /// How long attempts are blocked once [maxFailures] is reached.
  final Duration cooldown;

  int _consecutiveFailures = 0;
  DateTime? _cooldownUntil;

  /// Wrong PINs in a row since the last success (or app start).
  int get consecutiveFailures => _consecutiveFailures;

  /// When the active cooldown ends; null while attempts are allowed.
  DateTime? get cooldownUntil => isCoolingDown ? _cooldownUntil : null;

  /// Whether submitting a PIN is currently blocked.
  bool get isCoolingDown {
    final until = _cooldownUntil;
    return until != null && _clock().isBefore(until);
  }

  /// Time left in the active cooldown; [Duration.zero] when not cooling down.
  Duration get remainingCooldown {
    final until = _cooldownUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(_clock());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether another failure is allowed before the cooldown starts.
  int get remainingAttempts => isCoolingDown
      ? 0
      : (maxFailures - _consecutiveFailures).clamp(0, maxFailures);

  /// Records one wrong PIN. Returns true when this failure STARTED the
  /// cooldown (i.e. the UI should switch to the countdown). Calls while
  /// cooling down are ignored.
  bool recordFailure() {
    if (isCoolingDown) return false;
    _consecutiveFailures++;
    if (_consecutiveFailures >= maxFailures) {
      _cooldownUntil = _clock().add(cooldown);
      return true;
    }
    return false;
  }

  /// Records a successful unlock: clears the counter and any cooldown.
  void recordSuccess() {
    _consecutiveFailures = 0;
    _cooldownUntil = null;
  }
}
