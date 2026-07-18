import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/db/oneiro_database.dart';
import '../../../data/providers.dart';
import '../../speech/domain/speech_recognizer.dart';
import '../../speech/speech_providers.dart';

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

  // Dictation state: while listening, the field shows [_dictationBase]
  // (committed text) plus the live [_currentUtterance] partial.
  bool _dictating = false;
  String _dictationBase = '';
  String _currentUtterance = '';

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
    if (_dictating) {
      ref.read(speechRecognizerProvider).stop();
    }
    _textController.dispose();
    super.dispose();
  }

  /// Joins committed text and the live utterance with exactly one space.
  static String _joinDictation(String committed, String utterance) {
    if (committed.isEmpty) return utterance;
    if (utterance.isEmpty) return committed;
    return '$committed $utterance';
  }

  Future<void> _toggleDictation() async {
    final recognizer = ref.read(speechRecognizerProvider);
    if (_dictating) {
      await recognizer.stop();
      if (!mounted) return;
      setState(() {
        _dictating = false;
        // Commit whatever partial utterance was still on screen.
        _dictationBase = _joinDictation(_dictationBase, _currentUtterance);
        _currentUtterance = '';
        _replaceEditorText(_dictationBase);
      });
      return;
    }
    final available = await recognizer.initialize();
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone access is needed to dictate your dream — '
              'allow it in the app settings.',
            ),
          ),
        );
      return;
    }
    setState(() {
      _dictating = true;
      _dictationBase = _textController.text.trimRight();
      _currentUtterance = '';
    });
    await recognizer.start(
      onPhrase: _onDictationPhrase,
      onSessionEnd: () {
        if (mounted) setState(() => _dictating = false);
      },
    );
  }

  void _onDictationPhrase(SpeechPhrase phrase) {
    if (!mounted) return;
    setState(() {
      if (phrase.isFinal) {
        _dictationBase = _joinDictation(_dictationBase, phrase.words);
        _currentUtterance = '';
      } else {
        _currentUtterance = phrase.words;
      }
      _replaceEditorText(_joinDictation(_dictationBase, _currentUtterance));
    });
  }

  void _replaceEditorText(String text) {
    _textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
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
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
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
            tooltip: _dictating ? 'Stop dictation' : 'Dictate dream',
            onPressed: _toggleDictation,
            icon: Icon(_dictating ? Icons.mic : Icons.mic_none_outlined),
            color: _dictating ? theme.colorScheme.error : null,
          ),
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
                if (_dictating)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Listening… speak your dream',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
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
