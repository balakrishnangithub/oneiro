import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_providers.dart';
import 'data/pin_repository.dart';
import 'domain/pin_lockout_policy.dart';

/// PIN-hash persistence over the platform credential vault. In tests the
/// underlying [secureCredentialsStoreProvider] is replaced with the
/// in-memory fake.
final pinRepositoryProvider = Provider<PinRepository>(
  (ref) => PinRepository(ref.watch(secureCredentialsStoreProvider)),
);

/// Whether PIN lock is currently enabled. Purely for the Settings section —
/// invalidate it after enable/disable/change.
final pinEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(pinRepositoryProvider).isEnabled(),
);

/// Wall clock used by the lockout policy; tests substitute a manual clock.
final appLockClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Lifecycle of the app lock.
enum AppLockStatus {
  /// Reading the credential vault at startup — no journal content may show.
  checking,

  /// A PIN is set and the user has not unlocked this session yet.
  locked,

  /// No PIN, or the PIN was entered correctly.
  unlocked,
}

/// Outcome of one PIN submission on the lock screen.
enum PinSubmitResult {
  unlocked,
  wrongPin,
  cooldownStarted,
  coolingDown,
}

/// Immutable view of the app lock for the gate/lock screen.
class AppLockState {
  const AppLockState({required this.status, this.pinLength});

  final AppLockStatus status;

  /// Stored PIN length (dot count on the pad); null only while checking or
  /// when the stored hash is malformed.
  final int? pinLength;

  AppLockState copyWith({AppLockStatus? status, int? Function()? pinLength}) {
    return AppLockState(
      status: status ?? this.status,
      pinLength: pinLength == null ? this.pinLength : pinLength(),
    );
  }
}

/// Owns the locked/unlocked session state and the brute-force lockout.
///
/// The [PinLockoutPolicy] is in-memory on purpose (see its doc). Enabling,
/// changing or disabling the PIN happens in Settings and does not touch this
/// controller: the lock engages on the next cold start or background return.
class AppLockController extends Notifier<AppLockState> {
  late final PinLockoutPolicy _lockout = PinLockoutPolicy(
    clock: ref.read(appLockClockProvider),
  );

  @override
  AppLockState build() {
    unawaited(_hydrate());
    return const AppLockState(status: AppLockStatus.checking);
  }

  Future<void> _hydrate() async {
    final repo = ref.read(pinRepositoryProvider);
    if (await repo.isEnabled()) {
      state = AppLockState(
        status: AppLockStatus.locked,
        pinLength: await repo.pinLength(),
      );
    } else {
      state = const AppLockState(status: AppLockStatus.unlocked);
    }
  }

  /// Engages the lock (app start with a PIN, or return from background).
  /// No-op unless currently unlocked AND a PIN is still set — disabling the
  /// PIN from Settings must never strand the user on a lock screen.
  Future<void> lock() async {
    if (state.status != AppLockStatus.unlocked) return;
    final repo = ref.read(pinRepositoryProvider);
    if (!await repo.isEnabled()) return;
    state = AppLockState(
      status: AppLockStatus.locked,
      pinLength: await repo.pinLength(),
    );
  }

  /// Lockout policy views for the lock screen (use the injected clock).
  bool get isCoolingDown => _lockout.isCoolingDown;
  Duration get remainingCooldown => _lockout.remainingCooldown;
  int get remainingAttempts => _lockout.remainingAttempts;
  int get consecutiveFailures => _lockout.consecutiveFailures;

  /// Checks [pin] against the stored hash. Honors the lockout policy:
  /// submissions while cooling down never reach the hasher.
  Future<PinSubmitResult> submitPin(String pin) async {
    if (state.status != AppLockStatus.locked) {
      return PinSubmitResult.unlocked;
    }
    if (_lockout.isCoolingDown) return PinSubmitResult.coolingDown;
    final ok = await ref.read(pinRepositoryProvider).verify(pin);
    if (ok) {
      _lockout.recordSuccess();
      state = const AppLockState(status: AppLockStatus.unlocked);
      return PinSubmitResult.unlocked;
    }
    final cooldownStarted = _lockout.recordFailure();
    state = state.copyWith();
    return cooldownStarted
        ? PinSubmitResult.cooldownStarted
        : PinSubmitResult.wrongPin;
  }
}

/// The single app-lock controller.
final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
