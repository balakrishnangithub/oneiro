import '../../../data/db/oneiro_database.dart';

/// The canonical plaintext form of a journal entry inside an OVault
/// envelope.
///
/// Field order and names are fixed by the OVault v1 format
/// (`docs/sync-format.md`): `id`, `dreamDate`, `body`, `isLucid`,
/// `createdAt`, `updatedAt`, `deletedAt` — all timestamps are epoch
/// milliseconds, `deletedAt` is null for live entries and carries the
/// tombstone instant otherwise.
class SyncedEntry {
  const SyncedEntry({
    required this.id,
    required this.dreamDate,
    required this.body,
    required this.isLucid,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final int dreamDate;
  final String body;
  final bool isLucid;
  final int createdAt;
  final int updatedAt;

  /// Soft-delete tombstone, null while the entry is live.
  final int? deletedAt;

  factory SyncedEntry.fromEntry(DreamEntry entry) => SyncedEntry(
    id: entry.id,
    dreamDate: entry.dreamDate,
    body: entry.body,
    isLucid: entry.isLucid,
    createdAt: entry.createdAt,
    updatedAt: entry.updatedAt,
    deletedAt: entry.deletedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'dreamDate': dreamDate,
    'body': body,
    'isLucid': isLucid,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'deletedAt': deletedAt,
  };

  /// Strict parse of the canonical payload; throws [FormatException] on any
  /// schema violation so a corrupted remote file never half-applies.
  factory SyncedEntry.fromJson(Map<String, Object?> json) {
    int intField(String name) {
      final value = json[name];
      if (value is! int) {
        throw FormatException('entry field "$name" must be an integer');
      }
      return value;
    }

    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('entry field "id" must be a string');
    }
    final body = json['body'];
    if (body is! String) {
      throw const FormatException('entry field "body" must be a string');
    }
    final isLucid = json['isLucid'];
    if (isLucid is! bool) {
      throw const FormatException('entry field "isLucid" must be a boolean');
    }
    final deletedAt = json['deletedAt'];
    if (deletedAt != null && deletedAt is! int) {
      throw const FormatException('entry field "deletedAt" must be null or an integer');
    }
    return SyncedEntry(
      id: id,
      dreamDate: intField('dreamDate'),
      body: body,
      isLucid: isLucid,
      createdAt: intField('createdAt'),
      updatedAt: intField('updatedAt'),
      deletedAt: deletedAt as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SyncedEntry &&
      other.id == id &&
      other.dreamDate == dreamDate &&
      other.body == body &&
      other.isLucid == isLucid &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    dreamDate,
    body,
    isLucid,
    createdAt,
    updatedAt,
    deletedAt,
  );
}
