import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/privacy/domain/pin_lockout_policy.dart';

void main() {
  late DateTime now;
  late PinLockoutPolicy policy;

  setUp(() {
    now = DateTime(2026, 3, 1, 12);
    policy = PinLockoutPolicy(clock: () => now);
  });

  void failTimes(int n) {
    for (var i = 0; i < n; i++) {
      policy.recordFailure();
    }
  }

  group('PinLockoutPolicy', () {
    test('spec constants: 5 consecutive failures, 30-second cooldown', () {
      expect(policy.maxFailures, 5);
      expect(policy.cooldown, const Duration(seconds: 30));
    });

    test('failures below the threshold never cool down', () {
      failTimes(4);
      expect(policy.consecutiveFailures, 4);
      expect(policy.isCoolingDown, isFalse);
      expect(policy.cooldownUntil, isNull);
      expect(policy.remainingAttempts, 1);
      expect(policy.remainingCooldown, Duration.zero);
    });

    test('the fifth failure starts the cooldown', () {
      for (var i = 0; i < 4; i++) {
        expect(policy.recordFailure(), isFalse);
      }
      expect(policy.recordFailure(), isTrue);
      expect(policy.isCoolingDown, isTrue);
      expect(policy.cooldownUntil, now.add(const Duration(seconds: 30)));
      expect(policy.remainingAttempts, 0);
    });

    test('the countdown ticks down with the injected clock', () {
      failTimes(5);
      now = now.add(const Duration(seconds: 10));
      expect(policy.remainingCooldown, const Duration(seconds: 20));
      now = now.add(const Duration(seconds: 19));
      expect(policy.remainingCooldown, const Duration(seconds: 1));
      expect(policy.isCoolingDown, isTrue);
    });

    test('the cooldown expires and attempts are allowed again', () {
      failTimes(5);
      now = now.add(const Duration(seconds: 31));
      expect(policy.isCoolingDown, isFalse);
      expect(policy.cooldownUntil, isNull);
      expect(policy.remainingCooldown, Duration.zero);
    });

    test('failures during the cooldown are ignored (no stacking)', () {
      failTimes(5);
      final until = policy.cooldownUntil;
      expect(policy.recordFailure(), isFalse);
      expect(policy.consecutiveFailures, 5);
      expect(policy.cooldownUntil, until);
    });

    test('failures stay sticky after expiry: the next one re-locks', () {
      failTimes(5);
      now = now.add(const Duration(seconds: 31));
      expect(policy.isCoolingDown, isFalse);
      // The counter was never reset, so one more failure immediately
      // starts a fresh cooldown — no free 5 attempts every 30 seconds.
      expect(policy.recordFailure(), isTrue);
      expect(policy.isCoolingDown, isTrue);
    });

    test('success resets the counter', () {
      failTimes(3);
      policy.recordSuccess();
      expect(policy.consecutiveFailures, 0);
      expect(policy.remainingAttempts, 5);
      // Back to a full fresh budget.
      failTimes(4);
      expect(policy.isCoolingDown, isFalse);
    });

    test('success clears an active cooldown too', () {
      failTimes(5);
      expect(policy.isCoolingDown, isTrue);
      policy.recordSuccess();
      expect(policy.isCoolingDown, isFalse);
      expect(policy.consecutiveFailures, 0);
      expect(policy.cooldownUntil, isNull);
    });
  });
}
