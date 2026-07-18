// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oneiro_database.dart';

// ignore_for_file: type=lint
class $DreamEntriesTable extends DreamEntries
    with TableInfo<$DreamEntriesTable, DreamEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DreamEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dreamDateMeta = const VerificationMeta(
    'dreamDate',
  );
  @override
  late final GeneratedColumn<int> dreamDate = GeneratedColumn<int>(
    'dream_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isLucidMeta = const VerificationMeta(
    'isLucid',
  );
  @override
  late final GeneratedColumn<bool> isLucid = GeneratedColumn<bool>(
    'is_lucid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_lucid" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dreamDate,
    body,
    isLucid,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dream_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DreamEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dream_date')) {
      context.handle(
        _dreamDateMeta,
        dreamDate.isAcceptableOrUnknown(data['dream_date']!, _dreamDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dreamDateMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('is_lucid')) {
      context.handle(
        _isLucidMeta,
        isLucid.isAcceptableOrUnknown(data['is_lucid']!, _isLucidMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DreamEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DreamEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dreamDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dream_date'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      isLucid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_lucid'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DreamEntriesTable createAlias(String alias) {
    return $DreamEntriesTable(attachedDatabase, alias);
  }
}

class DreamEntry extends DataClass implements Insertable<DreamEntry> {
  /// Stable client-generated UUID.
  final String id;

  /// Day-granularity dream date, millis since epoch of local midnight.
  final int dreamDate;

  /// Free-form dream body, may be multi-line.
  ///
  /// The SQL column is named `text`; the Dart getter is `body` because a
  /// getter named `text` would shadow the inherited `text()` column builder.
  final String body;

  /// Whether the dreamer knew they were dreaming.
  final bool isLucid;

  /// Creation time, millis since epoch.
  final int createdAt;

  /// Last modification time, millis since epoch.
  final int updatedAt;

  /// Soft-delete tombstone; null while the entry is live.
  final int? deletedAt;
  const DreamEntry({
    required this.id,
    required this.dreamDate,
    required this.body,
    required this.isLucid,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['dream_date'] = Variable<int>(dreamDate);
    map['text'] = Variable<String>(body);
    map['is_lucid'] = Variable<bool>(isLucid);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  DreamEntriesCompanion toCompanion(bool nullToAbsent) {
    return DreamEntriesCompanion(
      id: Value(id),
      dreamDate: Value(dreamDate),
      body: Value(body),
      isLucid: Value(isLucid),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DreamEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DreamEntry(
      id: serializer.fromJson<String>(json['id']),
      dreamDate: serializer.fromJson<int>(json['dreamDate']),
      body: serializer.fromJson<String>(json['body']),
      isLucid: serializer.fromJson<bool>(json['isLucid']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dreamDate': serializer.toJson<int>(dreamDate),
      'body': serializer.toJson<String>(body),
      'isLucid': serializer.toJson<bool>(isLucid),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  DreamEntry copyWith({
    String? id,
    int? dreamDate,
    String? body,
    bool? isLucid,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => DreamEntry(
    id: id ?? this.id,
    dreamDate: dreamDate ?? this.dreamDate,
    body: body ?? this.body,
    isLucid: isLucid ?? this.isLucid,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  DreamEntry copyWithCompanion(DreamEntriesCompanion data) {
    return DreamEntry(
      id: data.id.present ? data.id.value : this.id,
      dreamDate: data.dreamDate.present ? data.dreamDate.value : this.dreamDate,
      body: data.body.present ? data.body.value : this.body,
      isLucid: data.isLucid.present ? data.isLucid.value : this.isLucid,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DreamEntry(')
          ..write('id: $id, ')
          ..write('dreamDate: $dreamDate, ')
          ..write('body: $body, ')
          ..write('isLucid: $isLucid, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

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
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DreamEntry &&
          other.id == this.id &&
          other.dreamDate == this.dreamDate &&
          other.body == this.body &&
          other.isLucid == this.isLucid &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class DreamEntriesCompanion extends UpdateCompanion<DreamEntry> {
  final Value<String> id;
  final Value<int> dreamDate;
  final Value<String> body;
  final Value<bool> isLucid;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const DreamEntriesCompanion({
    this.id = const Value.absent(),
    this.dreamDate = const Value.absent(),
    this.body = const Value.absent(),
    this.isLucid = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DreamEntriesCompanion.insert({
    required String id,
    required int dreamDate,
    required String body,
    this.isLucid = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dreamDate = Value(dreamDate),
       body = Value(body),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DreamEntry> custom({
    Expression<String>? id,
    Expression<int>? dreamDate,
    Expression<String>? body,
    Expression<bool>? isLucid,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dreamDate != null) 'dream_date': dreamDate,
      if (body != null) 'text': body,
      if (isLucid != null) 'is_lucid': isLucid,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DreamEntriesCompanion copyWith({
    Value<String>? id,
    Value<int>? dreamDate,
    Value<String>? body,
    Value<bool>? isLucid,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return DreamEntriesCompanion(
      id: id ?? this.id,
      dreamDate: dreamDate ?? this.dreamDate,
      body: body ?? this.body,
      isLucid: isLucid ?? this.isLucid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dreamDate.present) {
      map['dream_date'] = Variable<int>(dreamDate.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (isLucid.present) {
      map['is_lucid'] = Variable<bool>(isLucid.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DreamEntriesCompanion(')
          ..write('id: $id, ')
          ..write('dreamDate: $dreamDate, ')
          ..write('body: $body, ')
          ..write('isLucid: $isLucid, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DismissedThemeWordsTable extends DismissedThemeWords
    with TableInfo<$DismissedThemeWordsTable, DismissedThemeWord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DismissedThemeWordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dismissedAtMeta = const VerificationMeta(
    'dismissedAt',
  );
  @override
  late final GeneratedColumn<int> dismissedAt = GeneratedColumn<int>(
    'dismissed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [word, dismissedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dismissed_theme_words';
  @override
  VerificationContext validateIntegrity(
    Insertable<DismissedThemeWord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('dismissed_at')) {
      context.handle(
        _dismissedAtMeta,
        dismissedAt.isAcceptableOrUnknown(
          data['dismissed_at']!,
          _dismissedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dismissedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {word};
  @override
  DismissedThemeWord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DismissedThemeWord(
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      dismissedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dismissed_at'],
      )!,
    );
  }

  @override
  $DismissedThemeWordsTable createAlias(String alias) {
    return $DismissedThemeWordsTable(attachedDatabase, alias);
  }
}

class DismissedThemeWord extends DataClass
    implements Insertable<DismissedThemeWord> {
  /// The lowercased token, e.g. `flying` or `#ocean`.
  final String word;

  /// When the word was dismissed, millis since epoch.
  final int dismissedAt;
  const DismissedThemeWord({required this.word, required this.dismissedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word'] = Variable<String>(word);
    map['dismissed_at'] = Variable<int>(dismissedAt);
    return map;
  }

  DismissedThemeWordsCompanion toCompanion(bool nullToAbsent) {
    return DismissedThemeWordsCompanion(
      word: Value(word),
      dismissedAt: Value(dismissedAt),
    );
  }

  factory DismissedThemeWord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DismissedThemeWord(
      word: serializer.fromJson<String>(json['word']),
      dismissedAt: serializer.fromJson<int>(json['dismissedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'word': serializer.toJson<String>(word),
      'dismissedAt': serializer.toJson<int>(dismissedAt),
    };
  }

  DismissedThemeWord copyWith({String? word, int? dismissedAt}) =>
      DismissedThemeWord(
        word: word ?? this.word,
        dismissedAt: dismissedAt ?? this.dismissedAt,
      );
  DismissedThemeWord copyWithCompanion(DismissedThemeWordsCompanion data) {
    return DismissedThemeWord(
      word: data.word.present ? data.word.value : this.word,
      dismissedAt: data.dismissedAt.present
          ? data.dismissedAt.value
          : this.dismissedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DismissedThemeWord(')
          ..write('word: $word, ')
          ..write('dismissedAt: $dismissedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(word, dismissedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DismissedThemeWord &&
          other.word == this.word &&
          other.dismissedAt == this.dismissedAt);
}

class DismissedThemeWordsCompanion extends UpdateCompanion<DismissedThemeWord> {
  final Value<String> word;
  final Value<int> dismissedAt;
  final Value<int> rowid;
  const DismissedThemeWordsCompanion({
    this.word = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DismissedThemeWordsCompanion.insert({
    required String word,
    required int dismissedAt,
    this.rowid = const Value.absent(),
  }) : word = Value(word),
       dismissedAt = Value(dismissedAt);
  static Insertable<DismissedThemeWord> custom({
    Expression<String>? word,
    Expression<int>? dismissedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (word != null) 'word': word,
      if (dismissedAt != null) 'dismissed_at': dismissedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DismissedThemeWordsCompanion copyWith({
    Value<String>? word,
    Value<int>? dismissedAt,
    Value<int>? rowid,
  }) {
    return DismissedThemeWordsCompanion(
      word: word ?? this.word,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (dismissedAt.present) {
      map['dismissed_at'] = Variable<int>(dismissedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DismissedThemeWordsCompanion(')
          ..write('word: $word, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedUpdatedAtMeta =
      const VerificationMeta('lastSyncedUpdatedAt');
  @override
  late final GeneratedColumn<int> lastSyncedUpdatedAt = GeneratedColumn<int>(
    'last_synced_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryId, lastSyncedUpdatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('last_synced_updated_at')) {
      context.handle(
        _lastSyncedUpdatedAtMeta,
        lastSyncedUpdatedAt.isAcceptableOrUnknown(
          data['last_synced_updated_at']!,
          _lastSyncedUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedUpdatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId};
  @override
  SyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncState(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      lastSyncedUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_updated_at'],
      )!,
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncState extends DataClass implements Insertable<SyncState> {
  /// The dream entry this row tracks.
  final String entryId;

  /// The entry `updatedAt` (millis since epoch) as of the last successful
  /// push or pull.
  final int lastSyncedUpdatedAt;
  const SyncState({required this.entryId, required this.lastSyncedUpdatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['last_synced_updated_at'] = Variable<int>(lastSyncedUpdatedAt);
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      entryId: Value(entryId),
      lastSyncedUpdatedAt: Value(lastSyncedUpdatedAt),
    );
  }

  factory SyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncState(
      entryId: serializer.fromJson<String>(json['entryId']),
      lastSyncedUpdatedAt: serializer.fromJson<int>(
        json['lastSyncedUpdatedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'lastSyncedUpdatedAt': serializer.toJson<int>(lastSyncedUpdatedAt),
    };
  }

  SyncState copyWith({String? entryId, int? lastSyncedUpdatedAt}) => SyncState(
    entryId: entryId ?? this.entryId,
    lastSyncedUpdatedAt: lastSyncedUpdatedAt ?? this.lastSyncedUpdatedAt,
  );
  SyncState copyWithCompanion(SyncStatesCompanion data) {
    return SyncState(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      lastSyncedUpdatedAt: data.lastSyncedUpdatedAt.present
          ? data.lastSyncedUpdatedAt.value
          : this.lastSyncedUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncState(')
          ..write('entryId: $entryId, ')
          ..write('lastSyncedUpdatedAt: $lastSyncedUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryId, lastSyncedUpdatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncState &&
          other.entryId == this.entryId &&
          other.lastSyncedUpdatedAt == this.lastSyncedUpdatedAt);
}

class SyncStatesCompanion extends UpdateCompanion<SyncState> {
  final Value<String> entryId;
  final Value<int> lastSyncedUpdatedAt;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.entryId = const Value.absent(),
    this.lastSyncedUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String entryId,
    required int lastSyncedUpdatedAt,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       lastSyncedUpdatedAt = Value(lastSyncedUpdatedAt);
  static Insertable<SyncState> custom({
    Expression<String>? entryId,
    Expression<int>? lastSyncedUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (lastSyncedUpdatedAt != null)
        'last_synced_updated_at': lastSyncedUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? entryId,
    Value<int>? lastSyncedUpdatedAt,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      entryId: entryId ?? this.entryId,
      lastSyncedUpdatedAt: lastSyncedUpdatedAt ?? this.lastSyncedUpdatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (lastSyncedUpdatedAt.present) {
      map['last_synced_updated_at'] = Variable<int>(lastSyncedUpdatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('entryId: $entryId, ')
          ..write('lastSyncedUpdatedAt: $lastSyncedUpdatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$OneiroDatabase extends GeneratedDatabase {
  _$OneiroDatabase(QueryExecutor e) : super(e);
  $OneiroDatabaseManager get managers => $OneiroDatabaseManager(this);
  late final $DreamEntriesTable dreamEntries = $DreamEntriesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $DismissedThemeWordsTable dismissedThemeWords =
      $DismissedThemeWordsTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final DreamEntryDao dreamEntryDao = DreamEntryDao(
    this as OneiroDatabase,
  );
  late final DismissedThemeWordDao dismissedThemeWordDao =
      DismissedThemeWordDao(this as OneiroDatabase);
  late final SyncStateDao syncStateDao = SyncStateDao(this as OneiroDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dreamEntries,
    appSettings,
    dismissedThemeWords,
    syncStates,
  ];
}

typedef $$DreamEntriesTableCreateCompanionBuilder =
    DreamEntriesCompanion Function({
      required String id,
      required int dreamDate,
      required String body,
      Value<bool> isLucid,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$DreamEntriesTableUpdateCompanionBuilder =
    DreamEntriesCompanion Function({
      Value<String> id,
      Value<int> dreamDate,
      Value<String> body,
      Value<bool> isLucid,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$DreamEntriesTableFilterComposer
    extends Composer<_$OneiroDatabase, $DreamEntriesTable> {
  $$DreamEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dreamDate => $composableBuilder(
    column: $table.dreamDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLucid => $composableBuilder(
    column: $table.isLucid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DreamEntriesTableOrderingComposer
    extends Composer<_$OneiroDatabase, $DreamEntriesTable> {
  $$DreamEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dreamDate => $composableBuilder(
    column: $table.dreamDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLucid => $composableBuilder(
    column: $table.isLucid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DreamEntriesTableAnnotationComposer
    extends Composer<_$OneiroDatabase, $DreamEntriesTable> {
  $$DreamEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dreamDate =>
      $composableBuilder(column: $table.dreamDate, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<bool> get isLucid =>
      $composableBuilder(column: $table.isLucid, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DreamEntriesTableTableManager
    extends
        RootTableManager<
          _$OneiroDatabase,
          $DreamEntriesTable,
          DreamEntry,
          $$DreamEntriesTableFilterComposer,
          $$DreamEntriesTableOrderingComposer,
          $$DreamEntriesTableAnnotationComposer,
          $$DreamEntriesTableCreateCompanionBuilder,
          $$DreamEntriesTableUpdateCompanionBuilder,
          (
            DreamEntry,
            BaseReferences<_$OneiroDatabase, $DreamEntriesTable, DreamEntry>,
          ),
          DreamEntry,
          PrefetchHooks Function()
        > {
  $$DreamEntriesTableTableManager(_$OneiroDatabase db, $DreamEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DreamEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DreamEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DreamEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> dreamDate = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<bool> isLucid = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DreamEntriesCompanion(
                id: id,
                dreamDate: dreamDate,
                body: body,
                isLucid: isLucid,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int dreamDate,
                required String body,
                Value<bool> isLucid = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DreamEntriesCompanion.insert(
                id: id,
                dreamDate: dreamDate,
                body: body,
                isLucid: isLucid,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DreamEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$OneiroDatabase,
      $DreamEntriesTable,
      DreamEntry,
      $$DreamEntriesTableFilterComposer,
      $$DreamEntriesTableOrderingComposer,
      $$DreamEntriesTableAnnotationComposer,
      $$DreamEntriesTableCreateCompanionBuilder,
      $$DreamEntriesTableUpdateCompanionBuilder,
      (
        DreamEntry,
        BaseReferences<_$OneiroDatabase, $DreamEntriesTable, DreamEntry>,
      ),
      DreamEntry,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$OneiroDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$OneiroDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$OneiroDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$OneiroDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$OneiroDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$OneiroDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$OneiroDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$OneiroDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$DismissedThemeWordsTableCreateCompanionBuilder =
    DismissedThemeWordsCompanion Function({
      required String word,
      required int dismissedAt,
      Value<int> rowid,
    });
typedef $$DismissedThemeWordsTableUpdateCompanionBuilder =
    DismissedThemeWordsCompanion Function({
      Value<String> word,
      Value<int> dismissedAt,
      Value<int> rowid,
    });

class $$DismissedThemeWordsTableFilterComposer
    extends Composer<_$OneiroDatabase, $DismissedThemeWordsTable> {
  $$DismissedThemeWordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DismissedThemeWordsTableOrderingComposer
    extends Composer<_$OneiroDatabase, $DismissedThemeWordsTable> {
  $$DismissedThemeWordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DismissedThemeWordsTableAnnotationComposer
    extends Composer<_$OneiroDatabase, $DismissedThemeWordsTable> {
  $$DismissedThemeWordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<int> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => column,
  );
}

class $$DismissedThemeWordsTableTableManager
    extends
        RootTableManager<
          _$OneiroDatabase,
          $DismissedThemeWordsTable,
          DismissedThemeWord,
          $$DismissedThemeWordsTableFilterComposer,
          $$DismissedThemeWordsTableOrderingComposer,
          $$DismissedThemeWordsTableAnnotationComposer,
          $$DismissedThemeWordsTableCreateCompanionBuilder,
          $$DismissedThemeWordsTableUpdateCompanionBuilder,
          (
            DismissedThemeWord,
            BaseReferences<
              _$OneiroDatabase,
              $DismissedThemeWordsTable,
              DismissedThemeWord
            >,
          ),
          DismissedThemeWord,
          PrefetchHooks Function()
        > {
  $$DismissedThemeWordsTableTableManager(
    _$OneiroDatabase db,
    $DismissedThemeWordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DismissedThemeWordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DismissedThemeWordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DismissedThemeWordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> word = const Value.absent(),
                Value<int> dismissedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DismissedThemeWordsCompanion(
                word: word,
                dismissedAt: dismissedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String word,
                required int dismissedAt,
                Value<int> rowid = const Value.absent(),
              }) => DismissedThemeWordsCompanion.insert(
                word: word,
                dismissedAt: dismissedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DismissedThemeWordsTableProcessedTableManager =
    ProcessedTableManager<
      _$OneiroDatabase,
      $DismissedThemeWordsTable,
      DismissedThemeWord,
      $$DismissedThemeWordsTableFilterComposer,
      $$DismissedThemeWordsTableOrderingComposer,
      $$DismissedThemeWordsTableAnnotationComposer,
      $$DismissedThemeWordsTableCreateCompanionBuilder,
      $$DismissedThemeWordsTableUpdateCompanionBuilder,
      (
        DismissedThemeWord,
        BaseReferences<
          _$OneiroDatabase,
          $DismissedThemeWordsTable,
          DismissedThemeWord
        >,
      ),
      DismissedThemeWord,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder =
    SyncStatesCompanion Function({
      required String entryId,
      required int lastSyncedUpdatedAt,
      Value<int> rowid,
    });
typedef $$SyncStatesTableUpdateCompanionBuilder =
    SyncStatesCompanion Function({
      Value<String> entryId,
      Value<int> lastSyncedUpdatedAt,
      Value<int> rowid,
    });

class $$SyncStatesTableFilterComposer
    extends Composer<_$OneiroDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedUpdatedAt => $composableBuilder(
    column: $table.lastSyncedUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$OneiroDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedUpdatedAt => $composableBuilder(
    column: $table.lastSyncedUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$OneiroDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<int> get lastSyncedUpdatedAt => $composableBuilder(
    column: $table.lastSyncedUpdatedAt,
    builder: (column) => column,
  );
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$OneiroDatabase,
          $SyncStatesTable,
          SyncState,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncState,
            BaseReferences<_$OneiroDatabase, $SyncStatesTable, SyncState>,
          ),
          SyncState,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$OneiroDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<int> lastSyncedUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(
                entryId: entryId,
                lastSyncedUpdatedAt: lastSyncedUpdatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required int lastSyncedUpdatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                entryId: entryId,
                lastSyncedUpdatedAt: lastSyncedUpdatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$OneiroDatabase,
      $SyncStatesTable,
      SyncState,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (
        SyncState,
        BaseReferences<_$OneiroDatabase, $SyncStatesTable, SyncState>,
      ),
      SyncState,
      PrefetchHooks Function()
    >;

class $OneiroDatabaseManager {
  final _$OneiroDatabase _db;
  $OneiroDatabaseManager(this._db);
  $$DreamEntriesTableTableManager get dreamEntries =>
      $$DreamEntriesTableTableManager(_db, _db.dreamEntries);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$DismissedThemeWordsTableTableManager get dismissedThemeWords =>
      $$DismissedThemeWordsTableTableManager(_db, _db.dismissedThemeWords);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
}
