import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/presentation/settings_page.dart';
import '../domain/pin_hasher.dart';
import '../privacy_providers.dart';

/// "Privacy" settings section: optional PIN lock for the journal.
///
/// All three flows (enable, change, disable) are short dialog chains; the
/// PIN itself is only ever passed to [PinRepository], which stores nothing
/// but a salted scrypt hash in the platform credential vault.
class PrivacySection extends ConsumerWidget {
  const PrivacySection({super.key});

  Future<void> _enableFlow(BuildContext context, WidgetRef ref) async {
    final pin = await _askPin(
      context,
      title: 'Create a PIN',
      hint: '4–8 digits. You will need it every time Oneiro opens.',
    );
    if (pin == null || !context.mounted) return;
    final confirmed = await _askPin(
      context,
      title: 'Confirm your PIN',
      hint: 'Enter the same PIN again.',
    );
    if (confirmed == null || !context.mounted) return;
    if (confirmed != pin) {
      _toast(context, 'PINs did not match — nothing was saved');
      return;
    }
    await ref.read(pinRepositoryProvider).setPin(pin);
    ref.invalidate(pinEnabledProvider);
    if (context.mounted) _toast(context, 'PIN lock enabled');
  }

  Future<void> _disableFlow(BuildContext context, WidgetRef ref) async {
    final current = await _askPin(
      context,
      title: 'Disable PIN lock',
      hint: 'Enter your current PIN to confirm.',
    );
    if (current == null || !context.mounted) return;
    final ok = await ref.read(pinRepositoryProvider).verify(current);
    if (!context.mounted) return;
    if (!ok) {
      _toast(context, 'Incorrect PIN — PIN lock stays on');
      return;
    }
    await ref.read(pinRepositoryProvider).clearPin();
    ref.invalidate(pinEnabledProvider);
    if (context.mounted) _toast(context, 'PIN lock disabled');
  }

  Future<void> _changeFlow(BuildContext context, WidgetRef ref) async {
    final current = await _askPin(
      context,
      title: 'Change PIN',
      hint: 'Enter your current PIN first.',
    );
    if (current == null || !context.mounted) return;
    final ok = await ref.read(pinRepositoryProvider).verify(current);
    if (!context.mounted) return;
    if (!ok) {
      _toast(context, 'Incorrect PIN — nothing was changed');
      return;
    }
    final next = await _askPin(
      context,
      title: 'Choose a new PIN',
      hint: '4–8 digits.',
    );
    if (next == null || !context.mounted) return;
    final confirmed = await _askPin(
      context,
      title: 'Confirm the new PIN',
      hint: 'Enter the new PIN again.',
    );
    if (confirmed == null || !context.mounted) return;
    if (confirmed != next) {
      _toast(context, 'PINs did not match — nothing was changed');
      return;
    }
    await ref.read(pinRepositoryProvider).setPin(next);
    ref.invalidate(pinEnabledProvider);
    if (context.mounted) _toast(context, 'PIN changed');
  }

  Future<String?> _askPin(
    BuildContext context, {
    required String title,
    required String hint,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _PinEntryDialog(title: title, hint: hint),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(pinEnabledProvider);
    final enabled = enabledAsync.valueOrNull ?? false;
    return SettingsSectionCard(
      title: 'Privacy',
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'A PIN keeps your journal private when someone picks up your '
            'phone. Only a salted hash is stored — never the PIN itself. '
            'If you forget the PIN, the journal cannot be unlocked.',
          ),
        ),
        SwitchListTile(
          secondary: Icon(enabled ? Icons.lock : Icons.lock_open_outlined),
          title: const Text('PIN lock'),
          subtitle: Text(
            enabled
                ? 'Oneiro asks for your PIN on open'
                : 'Journal opens freely',
          ),
          value: enabled,
          onChanged: enabledAsync.isLoading
              ? null
              : (value) => value
                    ? _enableFlow(context, ref)
                    : _disableFlow(context, ref),
        ),
        if (enabled)
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text('Change PIN'),
            subtitle: const Text('Requires your current PIN'),
            onTap: () => _changeFlow(context, ref),
          ),
      ],
    );
  }
}

/// One step of a PIN dialog chain: a single obscured numeric field whose
/// Continue button unlocks once the input is a valid 4–8 digit PIN.
class _PinEntryDialog extends StatefulWidget {
  const _PinEntryDialog({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pin = _controller.text;
    final valid = PinHasher.isValidPin(pin);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.hint),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: PinHasher.maxPinLength,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'PIN',
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: valid ? () => Navigator.of(context).pop(pin) : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
