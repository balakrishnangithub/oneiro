import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../privacy_providers.dart';
import 'pin_lock_page.dart';

/// Router-level guard: blocks the whole shell until the journal is unlocked.
///
/// Wraps the app's navigator (via `MaterialApp.router`'s `builder`) and:
///
/// - shows a blank night-indigo surface while the credential vault is being
///   read at startup, so journal content never flashes before the lock,
/// - overlays the [PinLockPage] whenever [AppLockController] is locked,
/// - re-locks when the app goes to the background (paused/inactive), wired
///   through [WidgetsBindingObserver] — NOT on rebuilds, so navigating or
///   rotating the phone never re-locks an unlocked session.
///
/// Widget tests are unaffected unless they opt in: the lock state comes from
/// [appLockControllerProvider] over the (fakeable) secure store, and pages
/// pumped directly never mount this gate.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        unawaited(ref.read(appLockControllerProvider.notifier).lock());
      case AppLifecycleState.resumed:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider);
    final background = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      children: [
        if (lockState.status == AppLockStatus.checking)
          Positioned.fill(child: ColoredBox(color: background))
        else
          widget.child,
        if (lockState.status == AppLockStatus.locked)
          const Positioned.fill(child: PinLockPage()),
      ],
    );
  }
}
