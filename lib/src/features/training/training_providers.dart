import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../routing/app_router.dart';
import 'data/dream_clue_player.dart';
import 'data/notification_gateway.dart';
import 'data/notification_permission_service.dart';
import 'data/notification_scheduler.dart';
import 'data/settings_repository.dart';
import 'domain/clue_player.dart';
import 'domain/pause_service.dart';
import 'domain/training_settings.dart';

/// Typed façade over the `app_settings` table.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return DriftSettingsRepository(ref.watch(oneiroDatabaseProvider));
});

/// Live training settings, re-emitting whenever any key changes.
final trainingSettingsProvider = StreamProvider<TrainingSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).watch();
});

/// Pause/resume against the persisted settings.
final pauseServiceProvider = Provider<PauseService>((ref) {
  return PauseService(ref.watch(settingsRepositoryProvider));
});

/// OS notification façade. Overridden in tests with a fake.
final notificationGatewayProvider = Provider<NotificationGateway>((ref) {
  return LocalNotificationGateway();
});

/// Totem audio player. Overridden in tests with a fake.
final cluePlayerProvider = Provider<CluePlayer>((ref) {
  final player = DreamCluePlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Runtime notification permission flow. Overridden in tests with a fake.
final notificationPermissionServiceProvider =
    Provider<NotificationPermissionService>((ref) {
      return FlutterNotificationPermissionService();
    });

/// Current notification permission state; invalidate to re-check.
final notificationPermissionGrantedProvider = FutureProvider<bool>((ref) {
  return ref.watch(notificationPermissionServiceProvider).isGranted();
});

/// Current exact-alarm state; invalidate to re-check.
///
/// Android 14+ denies SCHEDULE_EXACT_ALARM by default, which silently made
/// every reminder fire late (or, before the inexact fallback existed, not at
/// all). The settings page surfaces this as an "approximate times" row.
final exactAlarmsAllowedProvider = FutureProvider<bool>((ref) {
  return ref.watch(notificationPermissionServiceProvider).canExactAlarms();
});

/// Pure planning engine; swaps the whole schedule when settings change.
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler(gateway: ref.watch(notificationGatewayProvider));
});

/// Side-effect provider: watched once by the app widget, it re-plans all
/// training notifications on startup and after every settings change.
final trainingReplanProvider = Provider<void>((ref) {
  final settings = ref.watch(trainingSettingsProvider).valueOrNull;
  if (settings == null) return;
  final scheduler = ref.watch(notificationSchedulerProvider);
  unawaited(
    scheduler.replan(settings).catchError((Object e, StackTrace st) {
      debugPrint('Oneiro: failed to re-plan notifications: $e');
    }),
  );
});

/// Routes a tapped training notification.
///
/// - reality check → opens the full-screen reality-check ritual,
/// - morning reminder → opens an empty dream editor so the dream can be
///   written down while it is still fresh,
/// - dream clue → plays the totem sound and counts it.
///
/// A notification that cold-starts the app is delivered by the gateway
/// during `main()`, BEFORE `runApp`: the router is not attached to a widget
/// tree yet and any navigation would be silently dropped (leaving the page
/// the user asked for never shown — or, on some devices, shown as the only
/// route and popped into a black screen). Navigation payloads are therefore
/// deferred to the first frame, when the shell exists.
Future<void> handleTrainingNotificationTap(
  ProviderContainer container,
  String? payload,
) async {
  final navigates =
      payload == TrainingPayloads.realityCheck ||
      payload == TrainingPayloads.morningReminder;
  if (navigates) {
    final router = container.read(appRouterProvider);
    // An unattached router has not parsed its initial location yet, so its
    // configuration is empty. That is exactly the cold-start state: wait
    // for the first frame instead of navigating into the void.
    if (router.routerDelegate.currentConfiguration.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(handleTrainingNotificationTap(container, payload));
      });
      return;
    }
  }
  switch (payload) {
    case TrainingPayloads.realityCheck:
      container.read(appRouterProvider).push(AppRoutes.realityCheck);
    case TrainingPayloads.morningReminder:
      container.read(appRouterProvider).push(AppRoutes.newDream);
    case TrainingPayloads.dreamClue:
      final repository = container.read(settingsRepositoryProvider);
      final settings = await repository.load();
      await container
          .read(cluePlayerProvider)
          .play(settings.totemSound, settings.clueVolume);
      await repository.incrementDreamClueCount();
  }
}
