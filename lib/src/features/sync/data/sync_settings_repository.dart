import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/db/oneiro_database.dart';
import 'webdav_vault_store.dart';

/// Which remote backend the vault lives on.
enum SyncBackendType {
  webdav('webdav'),
  localFolder('localFolder');

  const SyncBackendType(this.name);

  final String name;

  static SyncBackendType fromName(String? name) => switch (name) {
    'localFolder' => SyncBackendType.localFolder,
    _ => SyncBackendType.webdav,
  };
}

/// Non-secret sync connection settings (persisted in `app_settings`).
///
/// The WebDAV password and the vault passphrase are deliberately NOT here:
/// they live exclusively in the platform credential vault behind
/// `SecureCredentialsStore`.
class SyncConnectionSettings {
  const SyncConnectionSettings({
    this.backendType = SyncBackendType.webdav,
    this.url = '',
    this.username = '',
    this.basePath = defaultVaultBasePath,
    this.localFolderPath = '',
    this.rememberPassphrase = false,
  });

  final SyncBackendType backendType;

  /// WebDAV server URL (e.g. `https://webdav.pcloud.com`).
  final String url;
  final String username;

  /// Vault folder on the server.
  final String basePath;

  /// Vault folder on disk for the local-folder backend.
  final String localFolderPath;

  /// Whether the vault passphrase may be kept in secure storage.
  final bool rememberPassphrase;

  /// Enough information to attempt a sync?
  bool get isConfigured => switch (backendType) {
    SyncBackendType.webdav => url.trim().isNotEmpty,
    SyncBackendType.localFolder => localFolderPath.trim().isNotEmpty,
  };

  SyncConnectionSettings copyWith({
    SyncBackendType? backendType,
    String? url,
    String? username,
    String? basePath,
    String? localFolderPath,
    bool? rememberPassphrase,
  }) {
    return SyncConnectionSettings(
      backendType: backendType ?? this.backendType,
      url: url ?? this.url,
      username: username ?? this.username,
      basePath: basePath ?? this.basePath,
      localFolderPath: localFolderPath ?? this.localFolderPath,
      rememberPassphrase: rememberPassphrase ?? this.rememberPassphrase,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SyncConnectionSettings &&
      other.backendType == backendType &&
      other.url == url &&
      other.username == username &&
      other.basePath == basePath &&
      other.localFolderPath == localFolderPath &&
      other.rememberPassphrase == rememberPassphrase;

  @override
  int get hashCode => Object.hash(
    backendType,
    url,
    username,
    basePath,
    localFolderPath,
    rememberPassphrase,
  );
}

/// Application-facing contract for sync connection settings.
abstract class SyncSettingsRepository {
  Stream<SyncConnectionSettings> watch();
  Future<SyncConnectionSettings> load();
  Future<void> save(SyncConnectionSettings settings);

  /// When the last successful sync finished; null if never.
  Future<DateTime?> lastSyncAt();
  Future<void> recordSyncAt(DateTime at);

  /// Summary of the most recent completed run — including runs that
  /// finished in a background isolate while the app was closed.
  Future<SyncRunSummary?> lastRunSummary();
  Future<void> recordRunSummary(SyncRunSummary summary);
}

/// Compact, persistable summary of one sync run.
///
/// The foreground controller keeps full [SyncReport] objects in memory;
/// this is what survives process death so the UI can say "Last sync
/// finished in background: pushed 3, pulled 1" after the WorkManager
/// worker did the job while the app was closed.
class SyncRunSummary {
  const SyncRunSummary({
    required this.pushed,
    required this.pulled,
    this.deletions = 0,
    required this.conflictsResolved,
    required this.warningCount,
    required this.background,
    required this.finishedAt,
  });

  final int pushed;
  final int pulled;

  /// Tombstones replicated in either direction (see [SyncReport]).
  final int deletions;
  final int conflictsResolved;
  final int warningCount;

  /// True when the run completed in the WorkManager background isolate.
  final bool background;

  final DateTime finishedAt;

  Map<String, Object?> toJson() => {
    'pushed': pushed,
    'pulled': pulled,
    'deletions': deletions,
    'conflicts': conflictsResolved,
    'warnings': warningCount,
    'background': background,
    'at': finishedAt.millisecondsSinceEpoch,
  };

  static SyncRunSummary? fromJson(Map<String, Object?> json) {
    final at = json['at'];
    if (at is! int) return null;
    int intField(String name) => json[name] is int ? json[name]! as int : 0;
    return SyncRunSummary(
      pushed: intField('pushed'),
      pulled: intField('pulled'),
      deletions: intField('deletions'),
      conflictsResolved: intField('conflicts'),
      warningCount: intField('warnings'),
      background: json['background'] == true,
      finishedAt: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }
}

/// [SyncSettingsRepository] backed by the drift `app_settings` table.
class DriftSyncSettingsRepository implements SyncSettingsRepository {
  DriftSyncSettingsRepository(this._db);

  final OneiroDatabase _db;

  static const _kBackendType = 'sync.backendType';
  static const _kUrl = 'sync.url';
  static const _kUsername = 'sync.username';
  static const _kBasePath = 'sync.basePath';
  static const _kLocalFolderPath = 'sync.localFolderPath';
  static const _kRememberPassphrase = 'sync.rememberPassphrase';
  static const _kLastSyncAtMs = 'sync.lastSyncAtMs';
  static const _kLastRunSummary = 'sync.lastRunSummary';

  static SyncConnectionSettings _decode(Map<String, String> m) {
    final basePath = (m[_kBasePath] ?? '').trim();
    return SyncConnectionSettings(
      backendType: SyncBackendType.fromName(m[_kBackendType]),
      url: m[_kUrl] ?? '',
      username: m[_kUsername] ?? '',
      basePath: basePath.isEmpty ? defaultVaultBasePath : basePath,
      localFolderPath: m[_kLocalFolderPath] ?? '',
      rememberPassphrase: m[_kRememberPassphrase] == 'true',
    );
  }

  static Map<String, String> _encode(SyncConnectionSettings s) => {
    _kBackendType: s.backendType.name,
    _kUrl: s.url,
    _kUsername: s.username,
    _kBasePath: s.basePath,
    _kLocalFolderPath: s.localFolderPath,
    _kRememberPassphrase: '${s.rememberPassphrase}',
  };

  Future<Map<String, String>> _readAll() async {
    final rows = await _db.select(_db.appSettings).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<void> _put(String key, String value) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(key: Value(key), value: Value(value)),
        );
  }

  @override
  Stream<SyncConnectionSettings> watch() => _db
      .select(_db.appSettings)
      .watch()
      .map((rows) => _decode({for (final row in rows) row.key: row.value}));

  @override
  Future<SyncConnectionSettings> load() async => _decode(await _readAll());

  @override
  Future<void> save(SyncConnectionSettings settings) {
    final encoded = _encode(settings);
    return _db.transaction(() async {
      for (final entry in encoded.entries) {
        await _put(entry.key, entry.value);
      }
    });
  }

  @override
  Future<DateTime?> lastSyncAt() async {
    final raw = (await _readAll())[_kLastSyncAtMs];
    final ms = int.tryParse(raw ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> recordSyncAt(DateTime at) =>
      _put(_kLastSyncAtMs, '${at.millisecondsSinceEpoch}');

  @override
  Future<SyncRunSummary?> lastRunSummary() async {
    final raw = (await _readAll())[_kLastRunSummary];
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return SyncRunSummary.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> recordRunSummary(SyncRunSummary summary) =>
      _put(_kLastRunSummary, jsonEncode(summary.toJson()));
}
