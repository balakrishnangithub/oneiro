import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../training_providers.dart';

/// Full-screen reality-check ritual, opened from a training notification or
/// from the "Do a reality check now" button in Settings.
///
/// Answering either way counts as one completed reality check; the point of
/// the exercise is the questioning habit, not the answer.
class RealityCheckPage extends ConsumerStatefulWidget {
  const RealityCheckPage({super.key});

  @override
  ConsumerState<RealityCheckPage> createState() => _RealityCheckPageState();
}

class _RealityCheckPageState extends ConsumerState<RealityCheckPage> {
  bool _answered = false;

  Future<void> _complete() async {
    await ref.read(settingsRepositoryProvider).incrementRealityCheckCount();
    if (mounted) setState(() => _answered = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reality check'),
        automaticallyImplyLeading: false,
        leading: _answered
            ? null
            : BackButton(onPressed: () => _finish(context)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _answered ? _buildConfirmation(theme) : _buildPrompt(theme),
        ),
      ),
    );
  }

  Widget _buildPrompt(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(
          Icons.psychology_alt_outlined,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Stop for a moment and look around you.',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Ask yourself, honestly: am I dreaming?\n\n'
          'Try to push a finger through the palm of your other hand. '
          'Read a line of text, look away, then read it again — in dreams, '
          'words rarely stay put.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        FilledButton.tonal(
          onPressed: _complete,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('I was dreaming'),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _complete,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text("I'm awake"),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildConfirmation(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(
          Icons.check_circle_outline,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Logged.',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Every check trains the habit. One day the answer will surprise you.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        FilledButton(
          onPressed: () => _finish(context),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Done'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Leaves the ritual. Pops back to whatever was underneath — and if the
  /// ritual is the app's last route (belt-and-braces for a cold start from
  /// the notification where the shell was never built), lands on the journal
  /// instead of popping into a black screen.
  void _finish(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    GoRouter.of(context).go(AppRoutes.journal);
  }
}
