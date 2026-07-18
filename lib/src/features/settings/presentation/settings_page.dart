import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../routing/app_router.dart';
import '../../training/domain/pause_service.dart';
import '../../training/domain/training_settings.dart';
import '../../training/training_providers.dart';

/// Training, reminder and notification settings.
///
/// Every control persists straight into the `app_settings` table via
/// [settingsRepositoryProvider]; the notification schedule is re-planned
/// automatically because [trainingReplanProvider] watches the same stream.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(trainingSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            const Center(child: Text('Could not load settings')),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _RealityCheckSection(settings: settings),
            const SizedBox(height: 16),
            _DreamClueSection(settings: settings),
            const SizedBox(height: 16),
            _MorningReminderSection(settings: settings),
            const SizedBox(height: 16),
            _PauseSection(settings: settings),
            const SizedBox(height: 16),
            const _PermissionSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Card with a section title, used by every settings group.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Base class giving sections a `save` shortcut.
abstract class _SettingsSection extends ConsumerWidget {
  const _SettingsSection({required this.settings});

  final TrainingSettings settings;

  Future<void> save(WidgetRef ref, TrainingSettings next) =>
      ref.read(settingsRepositoryProvider).save(next);

  Future<void> pickTime(
    BuildContext context,
    WidgetRef ref, {
    required int currentMinutes,
    required TrainingSettings Function(int minutes) apply,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
    );
    if (picked == null) return;
    await save(ref, apply(picked.hour * 60 + picked.minute));
  }
}

class _RealityCheckSection extends _SettingsSection {
  const _RealityCheckSection({required super.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionCard(
      title: 'Reality checks',
      children: [
        SwitchListTile(
          title: const Text('Daytime reminders'),
          subtitle: const Text('Random prompts to question your reality'),
          value: settings.realityChecksEnabled,
          onChanged: (value) =>
              save(ref, settings.copyWith(realityChecksEnabled: value)),
        ),
        ListTile(
          title: Text('${settings.checksPerDay} checks per day'),
          subtitle: Slider(
            value: settings.checksPerDay.toDouble(),
            min: TrainingSettings.minChecksPerDay.toDouble(),
            max: TrainingSettings.maxChecksPerDay.toDouble(),
            divisions:
                TrainingSettings.maxChecksPerDay -
                TrainingSettings.minChecksPerDay,
            label: '${settings.checksPerDay}',
            onChanged: settings.realityChecksEnabled
                ? (value) =>
                      save(ref, settings.copyWith(checksPerDay: value.round()))
                : null,
          ),
        ),
        ListTile(
          title: const Text('Daytime window'),
          subtitle: Text(
            '${formatMinutesOfDay(settings.dayStartMinutes)} – '
            '${formatMinutesOfDay(settings.dayEndMinutes)}',
          ),
          trailing: const Icon(Icons.schedule),
          onTap: () async {
            await pickTime(
              context,
              ref,
              currentMinutes: settings.dayStartMinutes,
              apply: (minutes) => settings.copyWith(dayStartMinutes: minutes),
            );
            if (!context.mounted) return;
            await pickTime(
              context,
              ref,
              currentMinutes: settings.dayEndMinutes,
              apply: (minutes) => settings.copyWith(dayEndMinutes: minutes),
            );
          },
        ),
        SwitchListTile(
          title: const Text('Sound with alerts'),
          value: settings.dayAlertSound,
          onChanged: (value) =>
              save(ref, settings.copyWith(dayAlertSound: value)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.realityCheck),
            icon: const Icon(Icons.psychology_alt_outlined),
            label: const Text('Do a reality check now'),
          ),
        ),
      ],
    );
  }
}

class _DreamClueSection extends _SettingsSection {
  const _DreamClueSection({required super.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionCard(
      title: 'Dream clues',
      children: [
        SwitchListTile(
          title: const Text('Night-time audio cues'),
          subtitle: const Text('Soft totem sounds that can slip into dreams'),
          value: settings.dreamCluesEnabled,
          onChanged: (value) =>
              save(ref, settings.copyWith(dreamCluesEnabled: value)),
        ),
        ListTile(
          title: Text('${settings.cluesPerNight} clues per night'),
          subtitle: Slider(
            value: settings.cluesPerNight.toDouble(),
            min: TrainingSettings.minCluesPerNight.toDouble(),
            max: TrainingSettings.maxCluesPerNight.toDouble(),
            divisions:
                TrainingSettings.maxCluesPerNight -
                TrainingSettings.minCluesPerNight,
            label: '${settings.cluesPerNight}',
            onChanged: settings.dreamCluesEnabled
                ? (value) =>
                      save(ref, settings.copyWith(cluesPerNight: value.round()))
                : null,
          ),
        ),
        ListTile(
          title: const Text('Night window'),
          subtitle: Text(
            '${formatMinutesOfDay(settings.nightStartMinutes)} – '
            '${formatMinutesOfDay(settings.nightEndMinutes)}',
          ),
          trailing: const Icon(Icons.schedule),
          onTap: () async {
            await pickTime(
              context,
              ref,
              currentMinutes: settings.nightStartMinutes,
              apply: (minutes) => settings.copyWith(nightStartMinutes: minutes),
            );
            if (!context.mounted) return;
            await pickTime(
              context,
              ref,
              currentMinutes: settings.nightEndMinutes,
              apply: (minutes) => settings.copyWith(nightEndMinutes: minutes),
            );
          },
        ),
        ListTile(
          title: const Text('Totem sound'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<TotemSound>(
              segments: const [
                ButtonSegment(value: TotemSound.chime, label: Text('Chime')),
                ButtonSegment(value: TotemSound.bell, label: Text('Bell')),
                ButtonSegment(value: TotemSound.drop, label: Text('Drop')),
              ],
              selected: {settings.totemSound},
              onSelectionChanged: (selection) =>
                  save(ref, settings.copyWith(totemSound: selection.first)),
            ),
          ),
          trailing: IconButton(
            tooltip: 'Preview totem sound',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => ref
                .read(cluePlayerProvider)
                .play(settings.totemSound, settings.clueVolume),
          ),
        ),
        ListTile(
          title: Text(
            'Volume ${(settings.clueVolume * 100).round()}%',
          ),
          subtitle: Slider(
            value: settings.clueVolume,
            min: 0,
            max: 1,
            divisions: 20,
            label: '${(settings.clueVolume * 100).round()}%',
            onChanged: settings.dreamCluesEnabled
                ? (value) => save(ref, settings.copyWith(clueVolume: value))
                : null,
          ),
        ),
      ],
    );
  }
}

class _MorningReminderSection extends _SettingsSection {
  const _MorningReminderSection({required super.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionCard(
      title: 'Morning journal reminder',
      children: [
        SwitchListTile(
          title: const Text('Silent morning reminder'),
          subtitle: const Text('Keeps firing even while training is paused'),
          value: settings.morningReminderEnabled,
          onChanged: (value) =>
              save(ref, settings.copyWith(morningReminderEnabled: value)),
        ),
        ListTile(
          title: const Text('Reminder time'),
          subtitle: Text(formatMinutesOfDay(settings.morningMinutes)),
          trailing: const Icon(Icons.schedule),
          onTap: () => pickTime(
            context,
            ref,
            currentMinutes: settings.morningMinutes,
            apply: (minutes) => settings.copyWith(morningMinutes: minutes),
          ),
        ),
      ],
    );
  }
}

class _PauseSection extends _SettingsSection {
  const _PauseSection({required super.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = PauseService.isPaused(settings, DateTime.now());
    return _SectionCard(
      title: 'Training pause',
      children: [
        if (paused) ...[
          ListTile(
            leading: const Icon(Icons.pause_circle_outline),
            title: const Text('Training is paused'),
            subtitle: Text(
              'Until ${DateFormat('EEE d MMM, HH:mm').format(settings.pausedUntil!)}',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: FilledButton.icon(
              onPressed: () => ref.read(pauseServiceProvider).resume(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume training'),
            ),
          ),
        ] else ...[
          const ListTile(
            leading: Icon(Icons.pause_circle_outlined),
            title: Text('Take a break'),
            subtitle: Text(
              'Reality checks and dream clues stop; the morning reminder '
              'keeps going.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final days in const [1, 3, 7])
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(pauseServiceProvider).pauseFor(days),
                    child: Text('Pause $days day${days == 1 ? '' : 's'}'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PermissionSection extends ConsumerWidget {
  const _PermissionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = ref.watch(notificationPermissionGrantedProvider);
    return _SectionCard(
      title: 'Notifications',
      children: [
        granted.when(
          loading: () => const ListTile(title: Text('Checking permission…')),
          error: (error, _) => const ListTile(
            leading: Icon(Icons.error_outline),
            title: Text('Permission status unavailable'),
          ),
          data: (isGranted) => ListTile(
            leading: Icon(
              isGranted ? Icons.notifications_active : Icons.notifications_off,
            ),
            title: Text(
              isGranted
                  ? 'Notifications are allowed'
                  : 'Notifications are blocked',
            ),
            subtitle: isGranted
                ? null
                : const Text('Reminders cannot appear without permission'),
            trailing: isGranted
                ? null
                : TextButton(
                    onPressed: () async {
                      await ref
                          .read(notificationPermissionServiceProvider)
                          .request();
                      ref.invalidate(notificationPermissionGrantedProvider);
                    },
                    child: const Text('Request'),
                  ),
          ),
        ),
      ],
    );
  }
}
