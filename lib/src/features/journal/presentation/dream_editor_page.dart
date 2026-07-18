import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/db/oneiro_database.dart';
import '../../../data/providers.dart';

/// Create or edit a single dream entry.
class DreamEditorPage extends ConsumerStatefulWidget {
  const DreamEditorPage({super.key, this.entryId});

  /// Null when recording a new dream.
  final String? entryId;

  @override
  ConsumerState<DreamEditorPage> createState() => _DreamEditorPageState();
}

class _DreamEditorPageState extends ConsumerState<DreamEditorPage> {
  final _textController = TextEditingController();

  DreamEntry? _existing;
  late DateTime _dreamDate = DateTime.now().startOfDay;
  bool _isLucid = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.entryId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final entry = await ref.read(dreamRepositoryProvider).getById(id);
    if (!mounted) return;
    if (entry != null) {
      _existing = entry;
      _dreamDate = DateTime.fromMillisecondsSinceEpoch(entry.dreamDate);
      _isLucid = entry.isLucid;
      _textController.text = entry.body;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dreamDate,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dreamDate = picked.startOfDay);
    }
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Write a few words about your dream first')),
        );
      return;
    }
    setState(() => _saving = true);
    final repository = ref.read(dreamRepositoryProvider);
    final existing = _existing;
    if (existing == null) {
      await repository.createEntry(
        dreamDate: _dreamDate,
        text: text,
        isLucid: _isLucid,
      );
    } else {
      await repository.updateEntry(
        existing.copyWith(
          dreamDate: _dreamDate.dayMillis,
          body: text,
          isLucid: _isLucid,
        ),
      );
    }
    if (mounted && context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.entryId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit dream' : 'Record a dream'),
        actions: [
          IconButton(
            tooltip: 'Save dream',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.calendar_month_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Night of'),
                  subtitle: Text(formatDreamDateLong(_dreamDate)),
                  onTap: _pickDate,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.nightlight_round,
                    color: _isLucid
                        ? AppTheme.lucidAccent
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('I knew I was dreaming'),
                  subtitle: const Text('Mark this dream as lucid'),
                  value: _isLucid,
                  onChanged: (value) => setState(() => _isLucid = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _textController,
                  autofocus: !editing,
                  minLines: 8,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'What happened in your dream?',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
    );
  }
}
