import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../settings/presentation/settings_page.dart';
import '../data/secure_credentials_store.dart';
import '../data/sync_settings_repository.dart';
import '../data/webdav_vault_store.dart';
import '../domain/sync_engine.dart';
import '../sync_providers.dart';

/// "Encrypted Sync" settings section: backend connection, vault passphrase
/// with zero-knowledge explanation, and manual sync with status.
class SyncSection extends ConsumerStatefulWidget {
  const SyncSection({super.key});

  @override
  ConsumerState<SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends ConsumerState<SyncSection> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _basePathController = TextEditingController();
  final _localFolderController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passphraseController = TextEditingController();

  /// Controllers are seeded from persisted settings exactly once, so later
  /// stream emissions never clobber in-progress edits.
  bool _seeded = false;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _basePathController.dispose();
    _localFolderController.dispose();
    _passwordController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  void _seedFrom(SyncConnectionSettings settings) {
    if (_seeded) return;
    _seeded = true;
    _urlController.text = settings.url;
    _usernameController.text = settings.username;
    _basePathController.text = settings.basePath;
    _localFolderController.text = settings.localFolderPath;
  }

  Future<void> _saveConnection(SyncConnectionSettings current) async {
    final basePath = _basePathController.text.trim();
    final next = current.copyWith(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      basePath: basePath.isEmpty ? defaultVaultBasePath : basePath,
      localFolderPath: _localFolderController.text.trim(),
    );
    await ref.read(syncSettingsRepositoryProvider).save(next);
    final password = _passwordController.text;
    if (password.isNotEmpty) {
      await ref
          .read(secureCredentialsStoreProvider)
          .write(SecureCredentialKeys.syncPassword, password);
      _passwordController.clear();
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sync connection saved')));
    }
  }

  Future<void> _unlock(SyncConnectionSettings settings) async {
    final passphrase = _passphraseController.text;
    if (passphrase.isEmpty) return;
    final error = await ref
        .read(syncControllerProvider.notifier)
        .unlock(passphrase);
    if (!mounted) return;
    // The passphrase field leaves the tree once the vault is unlocked;
    // without an explicit unfocus the keyboard focus jumps to the WebDAV
    // password field above and the keyboard pops back up for no reason.
    FocusScope.of(context).unfocus();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final secure = ref.read(secureCredentialsStoreProvider);
    if (settings.rememberPassphrase) {
      await secure.write(SecureCredentialKeys.vaultPassphrase, passphrase);
    } else {
      await secure.delete(SecureCredentialKeys.vaultPassphrase);
    }
    if (!mounted) return;
    _passphraseController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Vault unlocked')));
  }

  Future<void> _syncNow() async {
    final report = await ref.read(syncControllerProvider.notifier).syncNow();
    if (!mounted || report == null) return;
    if (report.needsUnlock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault is locked — unlock it to sync')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(syncConnectionSettingsProvider);
    final syncState = ref.watch(syncControllerProvider);
    final settings = settingsAsync.valueOrNull;
    if (settings != null) _seedFrom(settings);
    final backend = settings?.backendType ?? SyncBackendType.webdav;

    return SettingsSectionCard(
      title: 'Encrypted Sync',
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Your dreams are encrypted on this device before anything leaves '
            'it. The server only stores unreadable sealed files — it never '
            'sees your journal or your passphrase. If you lose the '
            'passphrase, the data on the server is lost forever; no one can '
            'recover it, not even us.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<SyncBackendType>(
            segments: const [
              ButtonSegment(
                value: SyncBackendType.webdav,
                label: Text('WebDAV server'),
                icon: Icon(Icons.cloud_outlined),
              ),
              ButtonSegment(
                value: SyncBackendType.localFolder,
                label: Text('Local folder'),
                icon: Icon(Icons.folder_outlined),
              ),
            ],
            selected: {backend},
            onSelectionChanged: (selection) {
              final current = ref
                  .read(syncConnectionSettingsProvider)
                  .valueOrNull;
              if (current == null) return;
              ref
                  .read(syncSettingsRepositoryProvider)
                  .save(current.copyWith(backendType: selection.first));
            },
          ),
        ),
        if (backend == SyncBackendType.webdav) ...[
          _FieldTile(
            controller: _urlController,
            label: 'Server URL',
            hint: 'https://webdav.pcloud.com',
            keyboardType: TextInputType.url,
          ),
          _FieldTile(controller: _usernameController, label: 'Username'),
          _FieldTile(
            controller: _basePathController,
            label: 'Vault folder on server',
            hint: defaultVaultBasePath,
          ),
          _FieldTile(
            controller: _passwordController,
            label: 'Password',
            hint: 'Stored only in the device credential vault',
            obscure: true,
          ),
        ] else ...[
          _FieldTile(
            controller: _localFolderController,
            label: 'Vault folder path',
            hint: 'A folder your sync tool already mirrors',
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: FilledButton.tonalIcon(
            onPressed: settings == null
                ? null
                : () => _saveConnection(settings),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save connection'),
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          leading: Icon(
            syncState.unlocked ? Icons.lock_open : Icons.lock_outline,
          ),
          title: Text(syncState.unlocked ? 'Vault unlocked' : 'Vault locked'),
          subtitle: Text(
            syncState.unlocked
                ? 'Entries will be sealed with your passphrase before upload'
                : 'Enter your passphrase to enable syncing',
          ),
          trailing: syncState.unlocked
              ? TextButton(
                  onPressed: () =>
                      ref.read(syncControllerProvider.notifier).lock(),
                  child: const Text('Lock'),
                )
              : null,
        ),
        if (!syncState.unlocked) ...[
          _FieldTile(
            controller: _passphraseController,
            label: 'Vault passphrase',
            hint: 'Same passphrase on every device',
            obscure: true,
            onChanged: (_) => setState(() {}),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              _strengthHint(_passphraseController.text),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SwitchListTile(
            title: const Text('Remember on this device'),
            subtitle: const Text(
              'Keeps the passphrase in the device credential vault',
            ),
            value: settings?.rememberPassphrase ?? false,
            onChanged: (value) {
              final current = ref
                  .read(syncConnectionSettingsProvider)
                  .valueOrNull;
              if (current == null) return;
              ref
                  .read(syncSettingsRepositoryProvider)
                  .save(current.copyWith(rememberPassphrase: value));
              final scheduler = ref.read(backgroundSyncSchedulerProvider);
              if (!value) {
                ref
                    .read(secureCredentialsStoreProvider)
                    .delete(SecureCredentialKeys.vaultPassphrase);
                // Without a remembered passphrase the background isolate
                // cannot unlock the vault — stop waking up for it.
                unawaited(scheduler.cancel());
              } else {
                unawaited(scheduler.ensureScheduled());
              }
            },
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (!syncState.unlocked)
                FilledButton.tonalIcon(
                  onPressed: settings == null ? null : () => _unlock(settings),
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Set / unlock'),
                ),
              FilledButton.icon(
                onPressed: syncState.syncing ? null : _syncNow,
                icon: const Icon(Icons.sync),
                label: Text(
                  syncState.syncing
                      ? (syncState.paused
                            ? 'Paused…'
                            : _progressText(syncState.progress))
                      : 'Sync now',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            _statusText(syncState),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  static String _strengthHint(String passphrase) {
    if (passphrase.isEmpty) {
      return 'Pick a long, unique passphrase you can remember — it cannot '
          'be recovered or reset.';
    }
    if (passphrase.length < 8) {
      return 'Strength: too short — aim for 12+ characters';
    }
    if (passphrase.length < 12) return 'Strength: fair — longer is better';
    if (passphrase.length < 16) return 'Strength: good';
    return 'Strength: excellent';
  }

  static String _progressText(SyncProgress? progress) {
    if (progress == null) return 'Syncing…';
    return switch (progress.phase) {
      SyncPhase.downloading => 'Downloading vault…',
      SyncPhase.merging => 'Merging ${progress.processed}/${progress.total}…',
      SyncPhase.uploading => 'Uploading archive…',
      SyncPhase.cleaningUp => 'Removing old format…',
    };
  }

  static String _statusText(SyncUiState state) {
    if (state.paused) {
      return 'Paused — sync resumes when you\'re back';
    }
    if (state.syncing) return _progressText(state.progress);
    if (state.lastError != null) return state.lastError!;
    final report = state.lastReport;
    if (report != null && !report.needsUnlock) {
      final time = state.lastSyncAt == null
          ? ''
          : '${DateFormat('EEE d MMM, HH:mm').format(state.lastSyncAt!)} — ';
      final conflicts = report.conflictsResolved == 0
          ? ''
          : ', ${report.conflictsResolved} conflicts resolved';
      final warnings = report.warnings.isEmpty
          ? ''
          : ', ${report.warnings.length} warnings';
      return 'Last sync: ${time}pushed ${report.pushed}, '
          'pulled ${report.pulled}, skipped ${report.skipped}'
          '$conflicts$warnings';
    }
    // A background run may have finished while the app was closed; its
    // persisted summary is the freshest thing we know.
    final summary = state.lastRunSummary;
    if (summary != null) {
      final time = DateFormat('EEE d MMM, HH:mm').format(summary.finishedAt);
      final where = summary.background ? ' (in background)' : '';
      final warnings = summary.warningCount == 0
          ? ''
          : ', ${summary.warningCount} warnings';
      return 'Last sync: $time$where — pushed ${summary.pushed}, '
          'pulled ${summary.pulled}$warnings';
    }
    if (state.lastSyncAt != null) {
      return 'Last sync: '
          '${DateFormat('EEE d MMM, HH:mm').format(state.lastSyncAt!)}';
    }
    return 'Never synced';
  }
}

/// One labelled text field inside the sync section.
///
/// Password-style fields ([obscure]) get an eye toggle in the suffix so the
/// user can double-check what they typed — typos in a WebDAV app password or
/// a vault passphrase are otherwise invisible.
class _FieldTile extends StatefulWidget {
  const _FieldTile({
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  State<_FieldTile> createState() => _FieldTileState();
}

class _FieldTileState extends State<_FieldTile> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: TextField(
        controller: widget.controller,
        obscureText: _obscured,
        keyboardType: widget.keyboardType,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: _obscured ? 'Show' : 'Hide',
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                )
              : null,
        ),
      ),
    );
  }
}
