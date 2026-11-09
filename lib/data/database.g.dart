// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CharactersTable extends Characters
    with TableInfo<$CharactersTable, CharacterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharactersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [id, name, summary, json, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'characters';
  @override
  VerificationContext validateIntegrity(
    Insertable<CharacterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CharacterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CharacterRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CharactersTable createAlias(String alias) {
    return $CharactersTable(attachedDatabase, alias);
  }
}

class CharacterRow extends DataClass implements Insertable<CharacterRow> {
  final String id;
  final String name;
  final String summary;
  final String json;
  final int updatedAt;
  const CharacterRow({
    required this.id,
    required this.name,
    required this.summary,
    required this.json,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['summary'] = Variable<String>(summary);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CharactersCompanion toCompanion(bool nullToAbsent) {
    return CharactersCompanion(
      id: Value(id),
      name: Value(name),
      summary: Value(summary),
      json: Value(json),
      updatedAt: Value(updatedAt),
    );
  }

  factory CharacterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CharacterRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      summary: serializer.fromJson<String>(json['summary']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'summary': serializer.toJson<String>(summary),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CharacterRow copyWith({
    String? id,
    String? name,
    String? summary,
    String? json,
    int? updatedAt,
  }) => CharacterRow(
    id: id ?? this.id,
    name: name ?? this.name,
    summary: summary ?? this.summary,
    json: json ?? this.json,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CharacterRow copyWithCompanion(CharactersCompanion data) {
    return CharacterRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      summary: data.summary.present ? data.summary.value : this.summary,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CharacterRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('summary: $summary, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, summary, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CharacterRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.summary == this.summary &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class CharactersCompanion extends UpdateCompanion<CharacterRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> summary;
  final Value<String> json;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CharactersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.summary = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CharactersCompanion.insert({
    required String id,
    required String name,
    this.summary = const Value.absent(),
    required String json,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       json = Value(json),
       updatedAt = Value(updatedAt);
  static Insertable<CharacterRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? summary,
    Expression<String>? json,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (summary != null) 'summary': summary,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CharactersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? summary,
    Value<String>? json,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CharactersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharactersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('summary: $summary, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LogEntriesTable extends LogEntries
    with TableInfo<$LogEntriesTable, LogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES characters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforeMeta = const VerificationMeta('before');
  @override
  late final GeneratedColumn<String> before = GeneratedColumn<String>(
    'before',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _afterMeta = const VerificationMeta('after');
  @override
  late final GeneratedColumn<String> after = GeneratedColumn<String>(
    'after',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _undoableMeta = const VerificationMeta(
    'undoable',
  );
  @override
  late final GeneratedColumn<bool> undoable = GeneratedColumn<bool>(
    'undoable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("undoable" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    characterId,
    type,
    description,
    before,
    after,
    undoable,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'log_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('before')) {
      context.handle(
        _beforeMeta,
        before.isAcceptableOrUnknown(data['before']!, _beforeMeta),
      );
    }
    if (data.containsKey('after')) {
      context.handle(
        _afterMeta,
        after.isAcceptableOrUnknown(data['after']!, _afterMeta),
      );
    }
    if (data.containsKey('undoable')) {
      context.handle(
        _undoableMeta,
        undoable.isAcceptableOrUnknown(data['undoable']!, _undoableMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      before: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before'],
      ),
      after: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after'],
      ),
      undoable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}undoable'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LogEntriesTable createAlias(String alias) {
    return $LogEntriesTable(attachedDatabase, alias);
  }
}

class LogRow extends DataClass implements Insertable<LogRow> {
  final int id;
  final String characterId;
  final String type;
  final String description;

  /// Character JSON before and after the change; undo restores `before`.
  final String? before;
  final String? after;
  final bool undoable;
  final int createdAt;
  const LogRow({
    required this.id,
    required this.characterId,
    required this.type,
    required this.description,
    this.before,
    this.after,
    required this.undoable,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['character_id'] = Variable<String>(characterId);
    map['type'] = Variable<String>(type);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || before != null) {
      map['before'] = Variable<String>(before);
    }
    if (!nullToAbsent || after != null) {
      map['after'] = Variable<String>(after);
    }
    map['undoable'] = Variable<bool>(undoable);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  LogEntriesCompanion toCompanion(bool nullToAbsent) {
    return LogEntriesCompanion(
      id: Value(id),
      characterId: Value(characterId),
      type: Value(type),
      description: Value(description),
      before: before == null && nullToAbsent
          ? const Value.absent()
          : Value(before),
      after: after == null && nullToAbsent
          ? const Value.absent()
          : Value(after),
      undoable: Value(undoable),
      createdAt: Value(createdAt),
    );
  }

  factory LogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LogRow(
      id: serializer.fromJson<int>(json['id']),
      characterId: serializer.fromJson<String>(json['characterId']),
      type: serializer.fromJson<String>(json['type']),
      description: serializer.fromJson<String>(json['description']),
      before: serializer.fromJson<String?>(json['before']),
      after: serializer.fromJson<String?>(json['after']),
      undoable: serializer.fromJson<bool>(json['undoable']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'characterId': serializer.toJson<String>(characterId),
      'type': serializer.toJson<String>(type),
      'description': serializer.toJson<String>(description),
      'before': serializer.toJson<String?>(before),
      'after': serializer.toJson<String?>(after),
      'undoable': serializer.toJson<bool>(undoable),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  LogRow copyWith({
    int? id,
    String? characterId,
    String? type,
    String? description,
    Value<String?> before = const Value.absent(),
    Value<String?> after = const Value.absent(),
    bool? undoable,
    int? createdAt,
  }) => LogRow(
    id: id ?? this.id,
    characterId: characterId ?? this.characterId,
    type: type ?? this.type,
    description: description ?? this.description,
    before: before.present ? before.value : this.before,
    after: after.present ? after.value : this.after,
    undoable: undoable ?? this.undoable,
    createdAt: createdAt ?? this.createdAt,
  );
  LogRow copyWithCompanion(LogEntriesCompanion data) {
    return LogRow(
      id: data.id.present ? data.id.value : this.id,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      type: data.type.present ? data.type.value : this.type,
      description: data.description.present
          ? data.description.value
          : this.description,
      before: data.before.present ? data.before.value : this.before,
      after: data.after.present ? data.after.value : this.after,
      undoable: data.undoable.present ? data.undoable.value : this.undoable,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LogRow(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('before: $before, ')
          ..write('after: $after, ')
          ..write('undoable: $undoable, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    characterId,
    type,
    description,
    before,
    after,
    undoable,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LogRow &&
          other.id == this.id &&
          other.characterId == this.characterId &&
          other.type == this.type &&
          other.description == this.description &&
          other.before == this.before &&
          other.after == this.after &&
          other.undoable == this.undoable &&
          other.createdAt == this.createdAt);
}

class LogEntriesCompanion extends UpdateCompanion<LogRow> {
  final Value<int> id;
  final Value<String> characterId;
  final Value<String> type;
  final Value<String> description;
  final Value<String?> before;
  final Value<String?> after;
  final Value<bool> undoable;
  final Value<int> createdAt;
  const LogEntriesCompanion({
    this.id = const Value.absent(),
    this.characterId = const Value.absent(),
    this.type = const Value.absent(),
    this.description = const Value.absent(),
    this.before = const Value.absent(),
    this.after = const Value.absent(),
    this.undoable = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LogEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String characterId,
    required String type,
    required String description,
    this.before = const Value.absent(),
    this.after = const Value.absent(),
    this.undoable = const Value.absent(),
    required int createdAt,
  }) : characterId = Value(characterId),
       type = Value(type),
       description = Value(description),
       createdAt = Value(createdAt);
  static Insertable<LogRow> custom({
    Expression<int>? id,
    Expression<String>? characterId,
    Expression<String>? type,
    Expression<String>? description,
    Expression<String>? before,
    Expression<String>? after,
    Expression<bool>? undoable,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (characterId != null) 'character_id': characterId,
      if (type != null) 'type': type,
      if (description != null) 'description': description,
      if (before != null) 'before': before,
      if (after != null) 'after': after,
      if (undoable != null) 'undoable': undoable,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LogEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? characterId,
    Value<String>? type,
    Value<String>? description,
    Value<String?>? before,
    Value<String?>? after,
    Value<bool>? undoable,
    Value<int>? createdAt,
  }) {
    return LogEntriesCompanion(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      type: type ?? this.type,
      description: description ?? this.description,
      before: before ?? this.before,
      after: after ?? this.after,
      undoable: undoable ?? this.undoable,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (before.present) {
      map['before'] = Variable<String>(before.value);
    }
    if (after.present) {
      map['after'] = Variable<String>(after.value);
    }
    if (undoable.present) {
      map['undoable'] = Variable<bool>(undoable.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('before: $before, ')
          ..write('after: $after, ')
          ..write('undoable: $undoable, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TombstonesTable extends Tombstones
    with TableInfo<$TombstonesTable, TombstoneRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, updatedAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<TombstoneRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TombstoneRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TombstoneRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      )!,
    );
  }

  @override
  $TombstonesTable createAlias(String alias) {
    return $TombstonesTable(attachedDatabase, alias);
  }
}

class TombstoneRow extends DataClass implements Insertable<TombstoneRow> {
  final String id;
  final String name;
  final int updatedAt;
  final int deletedAt;
  const TombstoneRow({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted_at'] = Variable<int>(deletedAt);
    return map;
  }

  TombstonesCompanion toCompanion(bool nullToAbsent) {
    return TombstonesCompanion(
      id: Value(id),
      name: Value(name),
      updatedAt: Value(updatedAt),
      deletedAt: Value(deletedAt),
    );
  }

  factory TombstoneRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TombstoneRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int>(deletedAt),
    };
  }

  TombstoneRow copyWith({
    String? id,
    String? name,
    int? updatedAt,
    int? deletedAt,
  }) => TombstoneRow(
    id: id ?? this.id,
    name: name ?? this.name,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );
  TombstoneRow copyWithCompanion(TombstonesCompanion data) {
    return TombstoneRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TombstoneRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TombstoneRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TombstonesCompanion extends UpdateCompanion<TombstoneRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> updatedAt;
  final Value<int> deletedAt;
  final Value<int> rowid;
  const TombstonesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TombstonesCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required int deletedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deletedAt = Value(deletedAt);
  static Insertable<TombstoneRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TombstonesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? updatedAt,
    Value<int>? deletedAt,
    Value<int>? rowid,
  }) {
    return TombstonesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
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
    return (StringBuffer('TombstonesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncPeersTable extends SyncPeers
    with TableInfo<$SyncPeersTable, PeerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncPeersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pairedAtMeta = const VerificationMeta(
    'pairedAt',
  );
  @override
  late final GeneratedColumn<int> pairedAt = GeneratedColumn<int>(
    'paired_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncAt = GeneratedColumn<int>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, key, pairedAt, lastSyncAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_peers';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('paired_at')) {
      context.handle(
        _pairedAtMeta,
        pairedAt.isAcceptableOrUnknown(data['paired_at']!, _pairedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_pairedAtMeta);
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PeerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      pairedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paired_at'],
      )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sync_at'],
      ),
    );
  }

  @override
  $SyncPeersTable createAlias(String alias) {
    return $SyncPeersTable(attachedDatabase, alias);
  }
}

class PeerRow extends DataClass implements Insertable<PeerRow> {
  final String id;
  final String name;

  /// Shared secret, base64.
  final String key;
  final int pairedAt;
  final int? lastSyncAt;
  const PeerRow({
    required this.id,
    required this.name,
    required this.key,
    required this.pairedAt,
    this.lastSyncAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['key'] = Variable<String>(key);
    map['paired_at'] = Variable<int>(pairedAt);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<int>(lastSyncAt);
    }
    return map;
  }

  SyncPeersCompanion toCompanion(bool nullToAbsent) {
    return SyncPeersCompanion(
      id: Value(id),
      name: Value(name),
      key: Value(key),
      pairedAt: Value(pairedAt),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
    );
  }

  factory PeerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeerRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      key: serializer.fromJson<String>(json['key']),
      pairedAt: serializer.fromJson<int>(json['pairedAt']),
      lastSyncAt: serializer.fromJson<int?>(json['lastSyncAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'key': serializer.toJson<String>(key),
      'pairedAt': serializer.toJson<int>(pairedAt),
      'lastSyncAt': serializer.toJson<int?>(lastSyncAt),
    };
  }

  PeerRow copyWith({
    String? id,
    String? name,
    String? key,
    int? pairedAt,
    Value<int?> lastSyncAt = const Value.absent(),
  }) => PeerRow(
    id: id ?? this.id,
    name: name ?? this.name,
    key: key ?? this.key,
    pairedAt: pairedAt ?? this.pairedAt,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
  );
  PeerRow copyWithCompanion(SyncPeersCompanion data) {
    return PeerRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      key: data.key.present ? data.key.value : this.key,
      pairedAt: data.pairedAt.present ? data.pairedAt.value : this.pairedAt,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeerRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('key: $key, ')
          ..write('pairedAt: $pairedAt, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, key, pairedAt, lastSyncAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeerRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.key == this.key &&
          other.pairedAt == this.pairedAt &&
          other.lastSyncAt == this.lastSyncAt);
}

class SyncPeersCompanion extends UpdateCompanion<PeerRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> key;
  final Value<int> pairedAt;
  final Value<int?> lastSyncAt;
  final Value<int> rowid;
  const SyncPeersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.key = const Value.absent(),
    this.pairedAt = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncPeersCompanion.insert({
    required String id,
    required String name,
    required String key,
    required int pairedAt,
    this.lastSyncAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       key = Value(key),
       pairedAt = Value(pairedAt);
  static Insertable<PeerRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? key,
    Expression<int>? pairedAt,
    Expression<int>? lastSyncAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (key != null) 'key': key,
      if (pairedAt != null) 'paired_at': pairedAt,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncPeersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? key,
    Value<int>? pairedAt,
    Value<int?>? lastSyncAt,
    Value<int>? rowid,
  }) {
    return SyncPeersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      pairedAt: pairedAt ?? this.pairedAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (pairedAt.present) {
      map['paired_at'] = Variable<int>(pairedAt.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<int>(lastSyncAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncPeersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('key: $key, ')
          ..write('pairedAt: $pairedAt, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncBasesTable extends SyncBases
    with TableInfo<$SyncBasesTable, BaseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncBasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localTimeMeta = const VerificationMeta(
    'localTime',
  );
  @override
  late final GeneratedColumn<int> localTime = GeneratedColumn<int>(
    'local_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteTimeMeta = const VerificationMeta(
    'remoteTime',
  );
  @override
  late final GeneratedColumn<int> remoteTime = GeneratedColumn<int>(
    'remote_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    peerId,
    characterId,
    localTime,
    remoteTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_bases';
  @override
  VerificationContext validateIntegrity(
    Insertable<BaseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('local_time')) {
      context.handle(
        _localTimeMeta,
        localTime.isAcceptableOrUnknown(data['local_time']!, _localTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_localTimeMeta);
    }
    if (data.containsKey('remote_time')) {
      context.handle(
        _remoteTimeMeta,
        remoteTime.isAcceptableOrUnknown(data['remote_time']!, _remoteTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteTimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {peerId, characterId};
  @override
  BaseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BaseRow(
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      )!,
      localTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_time'],
      )!,
      remoteTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_time'],
      )!,
    );
  }

  @override
  $SyncBasesTable createAlias(String alias) {
    return $SyncBasesTable(attachedDatabase, alias);
  }
}

class BaseRow extends DataClass implements Insertable<BaseRow> {
  final String peerId;
  final String characterId;
  final int localTime;
  final int remoteTime;
  const BaseRow({
    required this.peerId,
    required this.characterId,
    required this.localTime,
    required this.remoteTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_id'] = Variable<String>(peerId);
    map['character_id'] = Variable<String>(characterId);
    map['local_time'] = Variable<int>(localTime);
    map['remote_time'] = Variable<int>(remoteTime);
    return map;
  }

  SyncBasesCompanion toCompanion(bool nullToAbsent) {
    return SyncBasesCompanion(
      peerId: Value(peerId),
      characterId: Value(characterId),
      localTime: Value(localTime),
      remoteTime: Value(remoteTime),
    );
  }

  factory BaseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BaseRow(
      peerId: serializer.fromJson<String>(json['peerId']),
      characterId: serializer.fromJson<String>(json['characterId']),
      localTime: serializer.fromJson<int>(json['localTime']),
      remoteTime: serializer.fromJson<int>(json['remoteTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerId': serializer.toJson<String>(peerId),
      'characterId': serializer.toJson<String>(characterId),
      'localTime': serializer.toJson<int>(localTime),
      'remoteTime': serializer.toJson<int>(remoteTime),
    };
  }

  BaseRow copyWith({
    String? peerId,
    String? characterId,
    int? localTime,
    int? remoteTime,
  }) => BaseRow(
    peerId: peerId ?? this.peerId,
    characterId: characterId ?? this.characterId,
    localTime: localTime ?? this.localTime,
    remoteTime: remoteTime ?? this.remoteTime,
  );
  BaseRow copyWithCompanion(SyncBasesCompanion data) {
    return BaseRow(
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      localTime: data.localTime.present ? data.localTime.value : this.localTime,
      remoteTime: data.remoteTime.present
          ? data.remoteTime.value
          : this.remoteTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BaseRow(')
          ..write('peerId: $peerId, ')
          ..write('characterId: $characterId, ')
          ..write('localTime: $localTime, ')
          ..write('remoteTime: $remoteTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(peerId, characterId, localTime, remoteTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BaseRow &&
          other.peerId == this.peerId &&
          other.characterId == this.characterId &&
          other.localTime == this.localTime &&
          other.remoteTime == this.remoteTime);
}

class SyncBasesCompanion extends UpdateCompanion<BaseRow> {
  final Value<String> peerId;
  final Value<String> characterId;
  final Value<int> localTime;
  final Value<int> remoteTime;
  final Value<int> rowid;
  const SyncBasesCompanion({
    this.peerId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.localTime = const Value.absent(),
    this.remoteTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncBasesCompanion.insert({
    required String peerId,
    required String characterId,
    required int localTime,
    required int remoteTime,
    this.rowid = const Value.absent(),
  }) : peerId = Value(peerId),
       characterId = Value(characterId),
       localTime = Value(localTime),
       remoteTime = Value(remoteTime);
  static Insertable<BaseRow> custom({
    Expression<String>? peerId,
    Expression<String>? characterId,
    Expression<int>? localTime,
    Expression<int>? remoteTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerId != null) 'peer_id': peerId,
      if (characterId != null) 'character_id': characterId,
      if (localTime != null) 'local_time': localTime,
      if (remoteTime != null) 'remote_time': remoteTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncBasesCompanion copyWith({
    Value<String>? peerId,
    Value<String>? characterId,
    Value<int>? localTime,
    Value<int>? remoteTime,
    Value<int>? rowid,
  }) {
    return SyncBasesCompanion(
      peerId: peerId ?? this.peerId,
      characterId: characterId ?? this.characterId,
      localTime: localTime ?? this.localTime,
      remoteTime: remoteTime ?? this.remoteTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (localTime.present) {
      map['local_time'] = Variable<int>(localTime.value);
    }
    if (remoteTime.present) {
      map['remote_time'] = Variable<int>(remoteTime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncBasesCompanion(')
          ..write('peerId: $peerId, ')
          ..write('characterId: $characterId, ')
          ..write('localTime: $localTime, ')
          ..write('remoteTime: $remoteTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncSettingsTable extends SyncSettings
    with TableInfo<$SyncSettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncSettingsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'sync_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
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
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
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
  $SyncSettingsTable createAlias(String alias) {
    return $SyncSettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncSettingsCompanion toCompanion(bool nullToAbsent) {
    return SyncSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
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

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SyncSettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
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
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncSettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
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

  SyncSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncSettingsCompanion(
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
    return (StringBuffer('SyncSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CharactersTable characters = $CharactersTable(this);
  late final $LogEntriesTable logEntries = $LogEntriesTable(this);
  late final $TombstonesTable tombstones = $TombstonesTable(this);
  late final $SyncPeersTable syncPeers = $SyncPeersTable(this);
  late final $SyncBasesTable syncBases = $SyncBasesTable(this);
  late final $SyncSettingsTable syncSettings = $SyncSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    characters,
    logEntries,
    tombstones,
    syncPeers,
    syncBases,
    syncSettings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'characters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('log_entries', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CharactersTableCreateCompanionBuilder = CharactersCompanion Function({
  required String id,
  required String name,
  Value<String> summary,
  required String json,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$CharactersTableUpdateCompanionBuilder = CharactersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> summary,
  Value<String> json,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$CharactersTableReferences
    extends BaseReferences<_$AppDatabase, $CharactersTable, CharacterRow> {
  $$CharactersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LogEntriesTable, List<LogRow>>
  _logEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.logEntries,
    aliasName: 'characters__id__log_entries__character_id',
  );

  $$LogEntriesTableProcessedTableManager get logEntriesRefs {
    final manager = $$LogEntriesTableTableManager(
      $_db,
      $_db.logEntries,
    ).filter((f) => f.characterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_logEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CharactersTableFilterComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> logEntriesRefs(
    Expression<bool> Function($$LogEntriesTableFilterComposer f) f,
  ) {
    final $$LogEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.logEntries,
      getReferencedColumn: (t) => t.characterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LogEntriesTableFilterComposer(
            $db: $db,
            $table: $db.logEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CharactersTableOrderingComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CharactersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> logEntriesRefs<T extends Object>(
    Expression<T> Function($$LogEntriesTableAnnotationComposer a) f,
  ) {
    final $$LogEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.logEntries,
      getReferencedColumn: (t) => t.characterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LogEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.logEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CharactersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CharactersTable,
          CharacterRow,
          $$CharactersTableFilterComposer,
          $$CharactersTableOrderingComposer,
          $$CharactersTableAnnotationComposer,
          $$CharactersTableCreateCompanionBuilder,
          $$CharactersTableUpdateCompanionBuilder,
          (CharacterRow, $$CharactersTableReferences),
          CharacterRow,
          PrefetchHooks Function({bool logEntriesRefs})
        > {
  $$CharactersTableTableManager(_$AppDatabase db, $CharactersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CharactersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CharactersCompanion(
                id: id,
                name: name,
                summary: summary,
                json: json,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> summary = const Value.absent(),
                required String json,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CharactersCompanion.insert(
                id: id,
                name: name,
                summary: summary,
                json: json,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CharactersTable, CharacterRow>(table),
                  $$CharactersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({logEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (logEntriesRefs) db.logEntries],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (logEntriesRefs)
                    await $_getPrefetchedDataByColumns<
                      CharacterRow,
                      $CharactersTable,
                      LogRow,
                      $LogEntriesTable
                    >(
                      currentTable: table,
                      referencedTable: $$CharactersTableReferences
                          ._logEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CharactersTableReferences(
                            db,
                            table,
                            p0,
                          ).logEntriesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'character_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CharactersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CharactersTable,
      CharacterRow,
      $$CharactersTableFilterComposer,
      $$CharactersTableOrderingComposer,
      $$CharactersTableAnnotationComposer,
      $$CharactersTableCreateCompanionBuilder,
      $$CharactersTableUpdateCompanionBuilder,
      (CharacterRow, $$CharactersTableReferences),
      CharacterRow,
      PrefetchHooks Function({bool logEntriesRefs})
    >;
typedef $$LogEntriesTableCreateCompanionBuilder = LogEntriesCompanion Function({
  Value<int> id,
  required String characterId,
  required String type,
  required String description,
  Value<String?> before,
  Value<String?> after,
  Value<bool> undoable,
  required int createdAt,
});
typedef $$LogEntriesTableUpdateCompanionBuilder = LogEntriesCompanion Function({
  Value<int> id,
  Value<String> characterId,
  Value<String> type,
  Value<String> description,
  Value<String?> before,
  Value<String?> after,
  Value<bool> undoable,
  Value<int> createdAt,
});

final class $$LogEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $LogEntriesTable, LogRow> {
  $$LogEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias('log_entries__character_id__characters__id');

  $$CharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<String>('character_id')!;

    final manager = $$CharactersTableTableManager(
      $_db,
      $_db.characters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $LogEntriesTable> {
  $$LogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get before => $composableBuilder(
    column: $table.before,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get after => $composableBuilder(
    column: $table.after,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get undoable => $composableBuilder(
    column: $table.undoable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableFilterComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LogEntriesTable> {
  $$LogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get before => $composableBuilder(
    column: $table.before,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get after => $composableBuilder(
    column: $table.after,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get undoable => $composableBuilder(
    column: $table.undoable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableOrderingComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LogEntriesTable> {
  $$LogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get before =>
      $composableBuilder(column: $table.before, builder: (column) => column);

  GeneratedColumn<String> get after =>
      $composableBuilder(column: $table.after, builder: (column) => column);

  GeneratedColumn<bool> get undoable =>
      $composableBuilder(column: $table.undoable, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableAnnotationComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LogEntriesTable,
          LogRow,
          $$LogEntriesTableFilterComposer,
          $$LogEntriesTableOrderingComposer,
          $$LogEntriesTableAnnotationComposer,
          $$LogEntriesTableCreateCompanionBuilder,
          $$LogEntriesTableUpdateCompanionBuilder,
          (LogRow, $$LogEntriesTableReferences),
          LogRow,
          PrefetchHooks Function({bool characterId})
        > {
  $$LogEntriesTableTableManager(_$AppDatabase db, $LogEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LogEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LogEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LogEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> characterId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> before = const Value.absent(),
                Value<String?> after = const Value.absent(),
                Value<bool> undoable = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => LogEntriesCompanion(
                id: id,
                characterId: characterId,
                type: type,
                description: description,
                before: before,
                after: after,
                undoable: undoable,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String characterId,
                required String type,
                required String description,
                Value<String?> before = const Value.absent(),
                Value<String?> after = const Value.absent(),
                Value<bool> undoable = const Value.absent(),
                required int createdAt,
              }) => LogEntriesCompanion.insert(
                id: id,
                characterId: characterId,
                type: type,
                description: description,
                before: before,
                after: after,
                undoable: undoable,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LogEntriesTable, LogRow>(table),
                  $$LogEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({characterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (characterId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.characterId,
                        referencedTable: $$LogEntriesTableReferences
                            ._characterIdTable(db),
                        referencedColumn: $$LogEntriesTableReferences
                            ._characterIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LogEntriesTable,
      LogRow,
      $$LogEntriesTableFilterComposer,
      $$LogEntriesTableOrderingComposer,
      $$LogEntriesTableAnnotationComposer,
      $$LogEntriesTableCreateCompanionBuilder,
      $$LogEntriesTableUpdateCompanionBuilder,
      (LogRow, $$LogEntriesTableReferences),
      LogRow,
      PrefetchHooks Function({bool characterId})
    >;
typedef $$TombstonesTableCreateCompanionBuilder = TombstonesCompanion Function({
  required String id,
  Value<String> name,
  Value<int> updatedAt,
  required int deletedAt,
  Value<int> rowid,
});
typedef $$TombstonesTableUpdateCompanionBuilder = TombstonesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> updatedAt,
  Value<int> deletedAt,
  Value<int> rowid,
});

class $$TombstonesTableFilterComposer
    extends Composer<_$AppDatabase, $TombstonesTable> {
  $$TombstonesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
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

class $$TombstonesTableOrderingComposer
    extends Composer<_$AppDatabase, $TombstonesTable> {
  $$TombstonesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
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

class $$TombstonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TombstonesTable> {
  $$TombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TombstonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TombstonesTable,
          TombstoneRow,
          $$TombstonesTableFilterComposer,
          $$TombstonesTableOrderingComposer,
          $$TombstonesTableAnnotationComposer,
          $$TombstonesTableCreateCompanionBuilder,
          $$TombstonesTableUpdateCompanionBuilder,
          (
            TombstoneRow,
            BaseReferences<_$AppDatabase, $TombstonesTable, TombstoneRow>,
          ),
          TombstoneRow,
          PrefetchHooks Function()
        > {
  $$TombstonesTableTableManager(_$AppDatabase db, $TombstonesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TombstonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TombstonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TombstonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TombstonesCompanion(
                id: id,
                name: name,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> name = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                required int deletedAt,
                Value<int> rowid = const Value.absent(),
              }) => TombstonesCompanion.insert(
                id: id,
                name: name,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TombstonesTable, TombstoneRow>(table),
                  BaseReferences<_$AppDatabase, $TombstonesTable, TombstoneRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TombstonesTable,
      TombstoneRow,
      $$TombstonesTableFilterComposer,
      $$TombstonesTableOrderingComposer,
      $$TombstonesTableAnnotationComposer,
      $$TombstonesTableCreateCompanionBuilder,
      $$TombstonesTableUpdateCompanionBuilder,
      (
        TombstoneRow,
        BaseReferences<_$AppDatabase, $TombstonesTable, TombstoneRow>,
      ),
      TombstoneRow,
      PrefetchHooks Function()
    >;
typedef $$SyncPeersTableCreateCompanionBuilder = SyncPeersCompanion Function({
  required String id,
  required String name,
  required String key,
  required int pairedAt,
  Value<int?> lastSyncAt,
  Value<int> rowid,
});
typedef $$SyncPeersTableUpdateCompanionBuilder = SyncPeersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> key,
  Value<int> pairedAt,
  Value<int?> lastSyncAt,
  Value<int> rowid,
});

class $$SyncPeersTableFilterComposer
    extends Composer<_$AppDatabase, $SyncPeersTable> {
  $$SyncPeersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pairedAt => $composableBuilder(
    column: $table.pairedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncPeersTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncPeersTable> {
  $$SyncPeersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pairedAt => $composableBuilder(
    column: $table.pairedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncPeersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncPeersTable> {
  $$SyncPeersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get pairedAt =>
      $composableBuilder(column: $table.pairedAt, builder: (column) => column);

  GeneratedColumn<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );
}

class $$SyncPeersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncPeersTable,
          PeerRow,
          $$SyncPeersTableFilterComposer,
          $$SyncPeersTableOrderingComposer,
          $$SyncPeersTableAnnotationComposer,
          $$SyncPeersTableCreateCompanionBuilder,
          $$SyncPeersTableUpdateCompanionBuilder,
          (PeerRow, BaseReferences<_$AppDatabase, $SyncPeersTable, PeerRow>),
          PeerRow,
          PrefetchHooks Function()
        > {
  $$SyncPeersTableTableManager(_$AppDatabase db, $SyncPeersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncPeersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncPeersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncPeersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<int> pairedAt = const Value.absent(),
                Value<int?> lastSyncAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncPeersCompanion(
                id: id,
                name: name,
                key: key,
                pairedAt: pairedAt,
                lastSyncAt: lastSyncAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String key,
                required int pairedAt,
                Value<int?> lastSyncAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncPeersCompanion.insert(
                id: id,
                name: name,
                key: key,
                pairedAt: pairedAt,
                lastSyncAt: lastSyncAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncPeersTable, PeerRow>(table),
                  BaseReferences<_$AppDatabase, $SyncPeersTable, PeerRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncPeersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncPeersTable,
      PeerRow,
      $$SyncPeersTableFilterComposer,
      $$SyncPeersTableOrderingComposer,
      $$SyncPeersTableAnnotationComposer,
      $$SyncPeersTableCreateCompanionBuilder,
      $$SyncPeersTableUpdateCompanionBuilder,
      (PeerRow, BaseReferences<_$AppDatabase, $SyncPeersTable, PeerRow>),
      PeerRow,
      PrefetchHooks Function()
    >;
typedef $$SyncBasesTableCreateCompanionBuilder = SyncBasesCompanion Function({
  required String peerId,
  required String characterId,
  required int localTime,
  required int remoteTime,
  Value<int> rowid,
});
typedef $$SyncBasesTableUpdateCompanionBuilder = SyncBasesCompanion Function({
  Value<String> peerId,
  Value<String> characterId,
  Value<int> localTime,
  Value<int> remoteTime,
  Value<int> rowid,
});

class $$SyncBasesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncBasesTable> {
  $$SyncBasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localTime => $composableBuilder(
    column: $table.localTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteTime => $composableBuilder(
    column: $table.remoteTime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncBasesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncBasesTable> {
  $$SyncBasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localTime => $composableBuilder(
    column: $table.localTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteTime => $composableBuilder(
    column: $table.remoteTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncBasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncBasesTable> {
  $$SyncBasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get localTime =>
      $composableBuilder(column: $table.localTime, builder: (column) => column);

  GeneratedColumn<int> get remoteTime => $composableBuilder(
    column: $table.remoteTime,
    builder: (column) => column,
  );
}

class $$SyncBasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncBasesTable,
          BaseRow,
          $$SyncBasesTableFilterComposer,
          $$SyncBasesTableOrderingComposer,
          $$SyncBasesTableAnnotationComposer,
          $$SyncBasesTableCreateCompanionBuilder,
          $$SyncBasesTableUpdateCompanionBuilder,
          (BaseRow, BaseReferences<_$AppDatabase, $SyncBasesTable, BaseRow>),
          BaseRow,
          PrefetchHooks Function()
        > {
  $$SyncBasesTableTableManager(_$AppDatabase db, $SyncBasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncBasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncBasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncBasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> peerId = const Value.absent(),
                Value<String> characterId = const Value.absent(),
                Value<int> localTime = const Value.absent(),
                Value<int> remoteTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncBasesCompanion(
                peerId: peerId,
                characterId: characterId,
                localTime: localTime,
                remoteTime: remoteTime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerId,
                required String characterId,
                required int localTime,
                required int remoteTime,
                Value<int> rowid = const Value.absent(),
              }) => SyncBasesCompanion.insert(
                peerId: peerId,
                characterId: characterId,
                localTime: localTime,
                remoteTime: remoteTime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncBasesTable, BaseRow>(table),
                  BaseReferences<_$AppDatabase, $SyncBasesTable, BaseRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncBasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncBasesTable,
      BaseRow,
      $$SyncBasesTableFilterComposer,
      $$SyncBasesTableOrderingComposer,
      $$SyncBasesTableAnnotationComposer,
      $$SyncBasesTableCreateCompanionBuilder,
      $$SyncBasesTableUpdateCompanionBuilder,
      (BaseRow, BaseReferences<_$AppDatabase, $SyncBasesTable, BaseRow>),
      BaseRow,
      PrefetchHooks Function()
    >;
typedef $$SyncSettingsTableCreateCompanionBuilder =
    SyncSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncSettingsTableUpdateCompanionBuilder =
    SyncSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncSettingsTable> {
  $$SyncSettingsTableFilterComposer({
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

class $$SyncSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncSettingsTable> {
  $$SyncSettingsTableOrderingComposer({
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

class $$SyncSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncSettingsTable> {
  $$SyncSettingsTableAnnotationComposer({
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

class $$SyncSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncSettingsTable,
          SettingRow,
          $$SyncSettingsTableFilterComposer,
          $$SyncSettingsTableOrderingComposer,
          $$SyncSettingsTableAnnotationComposer,
          $$SyncSettingsTableCreateCompanionBuilder,
          $$SyncSettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SyncSettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SyncSettingsTableTableManager(_$AppDatabase db, $SyncSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncSettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SyncSettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncSettingsTable,
      SettingRow,
      $$SyncSettingsTableFilterComposer,
      $$SyncSettingsTableOrderingComposer,
      $$SyncSettingsTableAnnotationComposer,
      $$SyncSettingsTableCreateCompanionBuilder,
      $$SyncSettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$AppDatabase, $SyncSettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CharactersTableTableManager get characters =>
      $$CharactersTableTableManager(_db, _db.characters);
  $$LogEntriesTableTableManager get logEntries =>
      $$LogEntriesTableTableManager(_db, _db.logEntries);
  $$TombstonesTableTableManager get tombstones =>
      $$TombstonesTableTableManager(_db, _db.tombstones);
  $$SyncPeersTableTableManager get syncPeers =>
      $$SyncPeersTableTableManager(_db, _db.syncPeers);
  $$SyncBasesTableTableManager get syncBases =>
      $$SyncBasesTableTableManager(_db, _db.syncBases);
  $$SyncSettingsTableTableManager get syncSettings =>
      $$SyncSettingsTableTableManager(_db, _db.syncSettings);
}
