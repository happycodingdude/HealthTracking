// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('id = 1'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<int> cursor = GeneratedColumn<int>(
    'cursor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiBudgetMeta = const VerificationMeta(
    'aiBudget',
  );
  @override
  late final GeneratedColumn<String> aiBudget = GeneratedColumn<String>(
    'ai_budget',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _knownEntitiesMeta = const VerificationMeta(
    'knownEntities',
  );
  @override
  late final GeneratedColumn<String> knownEntities = GeneratedColumn<String>(
    'known_entities',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cursor,
    lastSyncedAt,
    aiBudget,
    knownEntities,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('ai_budget')) {
      context.handle(
        _aiBudgetMeta,
        aiBudget.isAcceptableOrUnknown(data['ai_budget']!, _aiBudgetMeta),
      );
    }
    if (data.containsKey('known_entities')) {
      context.handle(
        _knownEntitiesMeta,
        knownEntities.isAcceptableOrUnknown(
          data['known_entities']!,
          _knownEntitiesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cursor'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      aiBudget: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_budget'],
      ),
      knownEntities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}known_entities'],
      ),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final int id;
  final int cursor;
  final DateTime? lastSyncedAt;

  /// `meta.aiBudget` của lần pull gần nhất, JSON (VS-12, ED-04).
  final String? aiBudget;

  /// Bộ entity app đã biết lúc pull, cách nhau bởi dấu phẩy (06 Bản 2 ED2-14).
  /// App mới biết thêm entity → đặt lại cursor về 0 và pull lại toàn bộ.
  final String? knownEntities;
  const SyncStateRow({
    required this.id,
    required this.cursor,
    this.lastSyncedAt,
    this.aiBudget,
    this.knownEntities,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cursor'] = Variable<int>(cursor);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || aiBudget != null) {
      map['ai_budget'] = Variable<String>(aiBudget);
    }
    if (!nullToAbsent || knownEntities != null) {
      map['known_entities'] = Variable<String>(knownEntities);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      id: Value(id),
      cursor: Value(cursor),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      aiBudget: aiBudget == null && nullToAbsent
          ? const Value.absent()
          : Value(aiBudget),
      knownEntities: knownEntities == null && nullToAbsent
          ? const Value.absent()
          : Value(knownEntities),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      id: serializer.fromJson<int>(json['id']),
      cursor: serializer.fromJson<int>(json['cursor']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      aiBudget: serializer.fromJson<String?>(json['aiBudget']),
      knownEntities: serializer.fromJson<String?>(json['knownEntities']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cursor': serializer.toJson<int>(cursor),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'aiBudget': serializer.toJson<String?>(aiBudget),
      'knownEntities': serializer.toJson<String?>(knownEntities),
    };
  }

  SyncStateRow copyWith({
    int? id,
    int? cursor,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<String?> aiBudget = const Value.absent(),
    Value<String?> knownEntities = const Value.absent(),
  }) => SyncStateRow(
    id: id ?? this.id,
    cursor: cursor ?? this.cursor,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    aiBudget: aiBudget.present ? aiBudget.value : this.aiBudget,
    knownEntities: knownEntities.present
        ? knownEntities.value
        : this.knownEntities,
  );
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      id: data.id.present ? data.id.value : this.id,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      aiBudget: data.aiBudget.present ? data.aiBudget.value : this.aiBudget,
      knownEntities: data.knownEntities.present
          ? data.knownEntities.value
          : this.knownEntities,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('id: $id, ')
          ..write('cursor: $cursor, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('aiBudget: $aiBudget, ')
          ..write('knownEntities: $knownEntities')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, cursor, lastSyncedAt, aiBudget, knownEntities);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.id == this.id &&
          other.cursor == this.cursor &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.aiBudget == this.aiBudget &&
          other.knownEntities == this.knownEntities);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<int> id;
  final Value<int> cursor;
  final Value<DateTime?> lastSyncedAt;
  final Value<String?> aiBudget;
  final Value<String?> knownEntities;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.aiBudget = const Value.absent(),
    this.knownEntities = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.aiBudget = const Value.absent(),
    this.knownEntities = const Value.absent(),
  });
  static Insertable<SyncStateRow> custom({
    Expression<int>? id,
    Expression<int>? cursor,
    Expression<DateTime>? lastSyncedAt,
    Expression<String>? aiBudget,
    Expression<String>? knownEntities,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cursor != null) 'cursor': cursor,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (aiBudget != null) 'ai_budget': aiBudget,
      if (knownEntities != null) 'known_entities': knownEntities,
    });
  }

  SyncStateCompanion copyWith({
    Value<int>? id,
    Value<int>? cursor,
    Value<DateTime?>? lastSyncedAt,
    Value<String?>? aiBudget,
    Value<String?>? knownEntities,
  }) {
    return SyncStateCompanion(
      id: id ?? this.id,
      cursor: cursor ?? this.cursor,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      aiBudget: aiBudget ?? this.aiBudget,
      knownEntities: knownEntities ?? this.knownEntities,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<int>(cursor.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (aiBudget.present) {
      map['ai_budget'] = Variable<String>(aiBudget.value);
    }
    if (knownEntities.present) {
      map['known_entities'] = Variable<String>(knownEntities.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('cursor: $cursor, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('aiBudget: $aiBudget, ')
          ..write('knownEntities: $knownEntities')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityKeyMeta = const VerificationMeta(
    'entityKey',
  );
  @override
  late final GeneratedColumn<String> entityKey = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta(
    'clientUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> clientUpdatedAt =
      GeneratedColumn<DateTime>(
        'client_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mutationId,
    entity,
    entityKey,
    op,
    payload,
    clientUpdatedAt,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _entityKeyMeta,
        entityKey.isAcceptableOrUnknown(data['key']!, _entityKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_entityKeyMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(
          data['client_updated_at']!,
          _clientUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientUpdatedAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}client_updated_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  /// Thứ tự gửi.
  final int id;
  final String mutationId;
  final String entity;
  final String entityKey;

  /// `upsert` / `ensure` / `delete`.
  final String op;

  /// `data` dạng JSON; null với `delete`.
  final String? payload;
  final DateTime clientUpdatedAt;
  final int attempts;
  final String? lastError;
  const OutboxRow({
    required this.id,
    required this.mutationId,
    required this.entity,
    required this.entityKey,
    required this.op,
    this.payload,
    required this.clientUpdatedAt,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mutation_id'] = Variable<String>(mutationId);
    map['entity'] = Variable<String>(entity);
    map['key'] = Variable<String>(entityKey);
    map['op'] = Variable<String>(op);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['client_updated_at'] = Variable<DateTime>(clientUpdatedAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      mutationId: Value(mutationId),
      entity: Value(entity),
      entityKey: Value(entityKey),
      op: Value(op),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      clientUpdatedAt: Value(clientUpdatedAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      id: serializer.fromJson<int>(json['id']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      entity: serializer.fromJson<String>(json['entity']),
      entityKey: serializer.fromJson<String>(json['entityKey']),
      op: serializer.fromJson<String>(json['op']),
      payload: serializer.fromJson<String?>(json['payload']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mutationId': serializer.toJson<String>(mutationId),
      'entity': serializer.toJson<String>(entity),
      'entityKey': serializer.toJson<String>(entityKey),
      'op': serializer.toJson<String>(op),
      'payload': serializer.toJson<String?>(payload),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxRow copyWith({
    int? id,
    String? mutationId,
    String? entity,
    String? entityKey,
    String? op,
    Value<String?> payload = const Value.absent(),
    DateTime? clientUpdatedAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => OutboxRow(
    id: id ?? this.id,
    mutationId: mutationId ?? this.mutationId,
    entity: entity ?? this.entity,
    entityKey: entityKey ?? this.entityKey,
    op: op ?? this.op,
    payload: payload.present ? payload.value : this.payload,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      id: data.id.present ? data.id.value : this.id,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityKey: data.entityKey.present ? data.entityKey.value : this.entityKey,
      op: data.op.present ? data.op.value : this.op,
      payload: data.payload.present ? data.payload.value : this.payload,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('id: $id, ')
          ..write('mutationId: $mutationId, ')
          ..write('entity: $entity, ')
          ..write('entityKey: $entityKey, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mutationId,
    entity,
    entityKey,
    op,
    payload,
    clientUpdatedAt,
    attempts,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.id == this.id &&
          other.mutationId == this.mutationId &&
          other.entity == this.entity &&
          other.entityKey == this.entityKey &&
          other.op == this.op &&
          other.payload == this.payload &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> id;
  final Value<String> mutationId;
  final Value<String> entity;
  final Value<String> entityKey;
  final Value<String> op;
  final Value<String?> payload;
  final Value<DateTime> clientUpdatedAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityKey = const Value.absent(),
    this.op = const Value.absent(),
    this.payload = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String mutationId,
    required String entity,
    required String entityKey,
    required String op,
    this.payload = const Value.absent(),
    required DateTime clientUpdatedAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : mutationId = Value(mutationId),
       entity = Value(entity),
       entityKey = Value(entityKey),
       op = Value(op),
       clientUpdatedAt = Value(clientUpdatedAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? id,
    Expression<String>? mutationId,
    Expression<String>? entity,
    Expression<String>? entityKey,
    Expression<String>? op,
    Expression<String>? payload,
    Expression<DateTime>? clientUpdatedAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mutationId != null) 'mutation_id': mutationId,
      if (entity != null) 'entity': entity,
      if (entityKey != null) 'key': entityKey,
      if (op != null) 'op': op,
      if (payload != null) 'payload': payload,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? mutationId,
    Value<String>? entity,
    Value<String>? entityKey,
    Value<String>? op,
    Value<String?>? payload,
    Value<DateTime>? clientUpdatedAt,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      mutationId: mutationId ?? this.mutationId,
      entity: entity ?? this.entity,
      entityKey: entityKey ?? this.entityKey,
      op: op ?? this.op,
      payload: payload ?? this.payload,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityKey.present) {
      map['key'] = Variable<String>(entityKey.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<DateTime>(clientUpdatedAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('mutationId: $mutationId, ')
          ..write('entity: $entity, ')
          ..write('entityKey: $entityKey, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $AccountTable extends Account with TableInfo<$AccountTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, displayName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'account';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountRow> instance, {
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
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
    );
  }

  @override
  $AccountTable createAlias(String alias) {
    return $AccountTable(attachedDatabase, alias);
  }
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  final String key;
  final String displayName;
  const AccountRow({required this.key, required this.displayName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['display_name'] = Variable<String>(displayName);
    return map;
  }

  AccountCompanion toCompanion(bool nullToAbsent) {
    return AccountCompanion(key: Value(key), displayName: Value(displayName));
  }

  factory AccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      key: serializer.fromJson<String>(json['key']),
      displayName: serializer.fromJson<String>(json['displayName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'displayName': serializer.toJson<String>(displayName),
    };
  }

  AccountRow copyWith({String? key, String? displayName}) => AccountRow(
    key: key ?? this.key,
    displayName: displayName ?? this.displayName,
  );
  AccountRow copyWithCompanion(AccountCompanion data) {
    return AccountRow(
      key: data.key.present ? data.key.value : this.key,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('key: $key, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, displayName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.key == this.key &&
          other.displayName == this.displayName);
}

class AccountCompanion extends UpdateCompanion<AccountRow> {
  final Value<String> key;
  final Value<String> displayName;
  final Value<int> rowid;
  const AccountCompanion({
    this.key = const Value.absent(),
    this.displayName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountCompanion.insert({
    required String key,
    required String displayName,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       displayName = Value(displayName);
  static Insertable<AccountRow> custom({
    Expression<String>? key,
    Expression<String>? displayName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (displayName != null) 'display_name': displayName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountCompanion copyWith({
    Value<String>? key,
    Value<String>? displayName,
    Value<int>? rowid,
  }) {
    return AccountCompanion(
      key: key ?? this.key,
      displayName: displayName ?? this.displayName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountCompanion(')
          ..write('key: $key, ')
          ..write('displayName: $displayName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _onboardingStepMeta = const VerificationMeta(
    'onboardingStep',
  );
  @override
  late final GeneratedColumn<int> onboardingStep = GeneratedColumn<int>(
    'onboarding_step',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<int> heightCm = GeneratedColumn<int>(
    'height_cm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthYearMeta = const VerificationMeta(
    'birthYear',
  );
  @override
  late final GeneratedColumn<int> birthYear = GeneratedColumn<int>(
    'birth_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
    'sex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityLevelMeta = const VerificationMeta(
    'activityLevel',
  );
  @override
  late final GeneratedColumn<String> activityLevel = GeneratedColumn<String>(
    'activity_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _setupDateMeta = const VerificationMeta(
    'setupDate',
  );
  @override
  late final GeneratedColumn<String> setupDate = GeneratedColumn<String>(
    'setup_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduleStartedOnMeta = const VerificationMeta(
    'scheduleStartedOn',
  );
  @override
  late final GeneratedColumn<String> scheduleStartedOn =
      GeneratedColumn<String>(
        'schedule_started_on',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _disclaimerAcceptedAtMeta =
      const VerificationMeta('disclaimerAcceptedAt');
  @override
  late final GeneratedColumn<DateTime> disclaimerAcceptedAt =
      GeneratedColumn<DateTime>(
        'disclaimer_accepted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _onboardingCompletedAtMeta =
      const VerificationMeta('onboardingCompletedAt');
  @override
  late final GeneratedColumn<DateTime> onboardingCompletedAt =
      GeneratedColumn<DateTime>(
        'onboarding_completed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _calorieModeMeta = const VerificationMeta(
    'calorieMode',
  );
  @override
  late final GeneratedColumn<String> calorieMode = GeneratedColumn<String>(
    'calorie_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calorieKcalMeta = const VerificationMeta(
    'calorieKcal',
  );
  @override
  late final GeneratedColumn<int> calorieKcal = GeneratedColumn<int>(
    'calorie_kcal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caloriePendingKcalMeta =
      const VerificationMeta('caloriePendingKcal');
  @override
  late final GeneratedColumn<int> caloriePendingKcal = GeneratedColumn<int>(
    'calorie_pending_kcal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caloriePendingReasonMeta =
      const VerificationMeta('caloriePendingReason');
  @override
  late final GeneratedColumn<String> caloriePendingReason =
      GeneratedColumn<String>(
        'calorie_pending_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _remindersEnabledMeta = const VerificationMeta(
    'remindersEnabled',
  );
  @override
  late final GeneratedColumn<bool> remindersEnabled = GeneratedColumn<bool>(
    'reminders_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminders_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _timezoneMeta = const VerificationMeta(
    'timezone',
  );
  @override
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    onboardingStep,
    heightCm,
    birthYear,
    sex,
    activityLevel,
    setupDate,
    scheduleStartedOn,
    disclaimerAcceptedAt,
    onboardingCompletedAt,
    calorieMode,
    calorieKcal,
    caloriePendingKcal,
    caloriePendingReason,
    remindersEnabled,
    timezone,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
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
    if (data.containsKey('onboarding_step')) {
      context.handle(
        _onboardingStepMeta,
        onboardingStep.isAcceptableOrUnknown(
          data['onboarding_step']!,
          _onboardingStepMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_onboardingStepMeta);
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    }
    if (data.containsKey('birth_year')) {
      context.handle(
        _birthYearMeta,
        birthYear.isAcceptableOrUnknown(data['birth_year']!, _birthYearMeta),
      );
    }
    if (data.containsKey('sex')) {
      context.handle(
        _sexMeta,
        sex.isAcceptableOrUnknown(data['sex']!, _sexMeta),
      );
    }
    if (data.containsKey('activity_level')) {
      context.handle(
        _activityLevelMeta,
        activityLevel.isAcceptableOrUnknown(
          data['activity_level']!,
          _activityLevelMeta,
        ),
      );
    }
    if (data.containsKey('setup_date')) {
      context.handle(
        _setupDateMeta,
        setupDate.isAcceptableOrUnknown(data['setup_date']!, _setupDateMeta),
      );
    }
    if (data.containsKey('schedule_started_on')) {
      context.handle(
        _scheduleStartedOnMeta,
        scheduleStartedOn.isAcceptableOrUnknown(
          data['schedule_started_on']!,
          _scheduleStartedOnMeta,
        ),
      );
    }
    if (data.containsKey('disclaimer_accepted_at')) {
      context.handle(
        _disclaimerAcceptedAtMeta,
        disclaimerAcceptedAt.isAcceptableOrUnknown(
          data['disclaimer_accepted_at']!,
          _disclaimerAcceptedAtMeta,
        ),
      );
    }
    if (data.containsKey('onboarding_completed_at')) {
      context.handle(
        _onboardingCompletedAtMeta,
        onboardingCompletedAt.isAcceptableOrUnknown(
          data['onboarding_completed_at']!,
          _onboardingCompletedAtMeta,
        ),
      );
    }
    if (data.containsKey('calorie_mode')) {
      context.handle(
        _calorieModeMeta,
        calorieMode.isAcceptableOrUnknown(
          data['calorie_mode']!,
          _calorieModeMeta,
        ),
      );
    }
    if (data.containsKey('calorie_kcal')) {
      context.handle(
        _calorieKcalMeta,
        calorieKcal.isAcceptableOrUnknown(
          data['calorie_kcal']!,
          _calorieKcalMeta,
        ),
      );
    }
    if (data.containsKey('calorie_pending_kcal')) {
      context.handle(
        _caloriePendingKcalMeta,
        caloriePendingKcal.isAcceptableOrUnknown(
          data['calorie_pending_kcal']!,
          _caloriePendingKcalMeta,
        ),
      );
    }
    if (data.containsKey('calorie_pending_reason')) {
      context.handle(
        _caloriePendingReasonMeta,
        caloriePendingReason.isAcceptableOrUnknown(
          data['calorie_pending_reason']!,
          _caloriePendingReasonMeta,
        ),
      );
    }
    if (data.containsKey('reminders_enabled')) {
      context.handle(
        _remindersEnabledMeta,
        remindersEnabled.isAcceptableOrUnknown(
          data['reminders_enabled']!,
          _remindersEnabledMeta,
        ),
      );
    }
    if (data.containsKey('timezone')) {
      context.handle(
        _timezoneMeta,
        timezone.isAcceptableOrUnknown(data['timezone']!, _timezoneMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      onboardingStep: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}onboarding_step'],
      )!,
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height_cm'],
      ),
      birthYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birth_year'],
      ),
      sex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sex'],
      ),
      activityLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_level'],
      ),
      setupDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setup_date'],
      ),
      scheduleStartedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_started_on'],
      ),
      disclaimerAcceptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}disclaimer_accepted_at'],
      ),
      onboardingCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}onboarding_completed_at'],
      ),
      calorieMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calorie_mode'],
      ),
      calorieKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calorie_kcal'],
      ),
      caloriePendingKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calorie_pending_kcal'],
      ),
      caloriePendingReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calorie_pending_reason'],
      ),
      remindersEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminders_enabled'],
      )!,
      timezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone'],
      ),
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final String key;
  final int onboardingStep;
  final int? heightCm;
  final int? birthYear;
  final String? sex;
  final String? activityLevel;

  /// `YYYY-MM-DD`.
  final String? setupDate;

  /// `YYYY-MM-DD`, Bản 2 (05 Bản 2 §6.6.5).
  final String? scheduleStartedOn;
  final DateTime? disclaimerAcceptedAt;
  final DateTime? onboardingCompletedAt;
  final String? calorieMode;
  final int? calorieKcal;
  final int? caloriePendingKcal;
  final String? caloriePendingReason;
  final bool remindersEnabled;
  final String? timezone;
  const ProfileRow({
    required this.key,
    required this.onboardingStep,
    this.heightCm,
    this.birthYear,
    this.sex,
    this.activityLevel,
    this.setupDate,
    this.scheduleStartedOn,
    this.disclaimerAcceptedAt,
    this.onboardingCompletedAt,
    this.calorieMode,
    this.calorieKcal,
    this.caloriePendingKcal,
    this.caloriePendingReason,
    required this.remindersEnabled,
    this.timezone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['onboarding_step'] = Variable<int>(onboardingStep);
    if (!nullToAbsent || heightCm != null) {
      map['height_cm'] = Variable<int>(heightCm);
    }
    if (!nullToAbsent || birthYear != null) {
      map['birth_year'] = Variable<int>(birthYear);
    }
    if (!nullToAbsent || sex != null) {
      map['sex'] = Variable<String>(sex);
    }
    if (!nullToAbsent || activityLevel != null) {
      map['activity_level'] = Variable<String>(activityLevel);
    }
    if (!nullToAbsent || setupDate != null) {
      map['setup_date'] = Variable<String>(setupDate);
    }
    if (!nullToAbsent || scheduleStartedOn != null) {
      map['schedule_started_on'] = Variable<String>(scheduleStartedOn);
    }
    if (!nullToAbsent || disclaimerAcceptedAt != null) {
      map['disclaimer_accepted_at'] = Variable<DateTime>(disclaimerAcceptedAt);
    }
    if (!nullToAbsent || onboardingCompletedAt != null) {
      map['onboarding_completed_at'] = Variable<DateTime>(
        onboardingCompletedAt,
      );
    }
    if (!nullToAbsent || calorieMode != null) {
      map['calorie_mode'] = Variable<String>(calorieMode);
    }
    if (!nullToAbsent || calorieKcal != null) {
      map['calorie_kcal'] = Variable<int>(calorieKcal);
    }
    if (!nullToAbsent || caloriePendingKcal != null) {
      map['calorie_pending_kcal'] = Variable<int>(caloriePendingKcal);
    }
    if (!nullToAbsent || caloriePendingReason != null) {
      map['calorie_pending_reason'] = Variable<String>(caloriePendingReason);
    }
    map['reminders_enabled'] = Variable<bool>(remindersEnabled);
    if (!nullToAbsent || timezone != null) {
      map['timezone'] = Variable<String>(timezone);
    }
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      key: Value(key),
      onboardingStep: Value(onboardingStep),
      heightCm: heightCm == null && nullToAbsent
          ? const Value.absent()
          : Value(heightCm),
      birthYear: birthYear == null && nullToAbsent
          ? const Value.absent()
          : Value(birthYear),
      sex: sex == null && nullToAbsent ? const Value.absent() : Value(sex),
      activityLevel: activityLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(activityLevel),
      setupDate: setupDate == null && nullToAbsent
          ? const Value.absent()
          : Value(setupDate),
      scheduleStartedOn: scheduleStartedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduleStartedOn),
      disclaimerAcceptedAt: disclaimerAcceptedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(disclaimerAcceptedAt),
      onboardingCompletedAt: onboardingCompletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(onboardingCompletedAt),
      calorieMode: calorieMode == null && nullToAbsent
          ? const Value.absent()
          : Value(calorieMode),
      calorieKcal: calorieKcal == null && nullToAbsent
          ? const Value.absent()
          : Value(calorieKcal),
      caloriePendingKcal: caloriePendingKcal == null && nullToAbsent
          ? const Value.absent()
          : Value(caloriePendingKcal),
      caloriePendingReason: caloriePendingReason == null && nullToAbsent
          ? const Value.absent()
          : Value(caloriePendingReason),
      remindersEnabled: Value(remindersEnabled),
      timezone: timezone == null && nullToAbsent
          ? const Value.absent()
          : Value(timezone),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      key: serializer.fromJson<String>(json['key']),
      onboardingStep: serializer.fromJson<int>(json['onboardingStep']),
      heightCm: serializer.fromJson<int?>(json['heightCm']),
      birthYear: serializer.fromJson<int?>(json['birthYear']),
      sex: serializer.fromJson<String?>(json['sex']),
      activityLevel: serializer.fromJson<String?>(json['activityLevel']),
      setupDate: serializer.fromJson<String?>(json['setupDate']),
      scheduleStartedOn: serializer.fromJson<String?>(
        json['scheduleStartedOn'],
      ),
      disclaimerAcceptedAt: serializer.fromJson<DateTime?>(
        json['disclaimerAcceptedAt'],
      ),
      onboardingCompletedAt: serializer.fromJson<DateTime?>(
        json['onboardingCompletedAt'],
      ),
      calorieMode: serializer.fromJson<String?>(json['calorieMode']),
      calorieKcal: serializer.fromJson<int?>(json['calorieKcal']),
      caloriePendingKcal: serializer.fromJson<int?>(json['caloriePendingKcal']),
      caloriePendingReason: serializer.fromJson<String?>(
        json['caloriePendingReason'],
      ),
      remindersEnabled: serializer.fromJson<bool>(json['remindersEnabled']),
      timezone: serializer.fromJson<String?>(json['timezone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'onboardingStep': serializer.toJson<int>(onboardingStep),
      'heightCm': serializer.toJson<int?>(heightCm),
      'birthYear': serializer.toJson<int?>(birthYear),
      'sex': serializer.toJson<String?>(sex),
      'activityLevel': serializer.toJson<String?>(activityLevel),
      'setupDate': serializer.toJson<String?>(setupDate),
      'scheduleStartedOn': serializer.toJson<String?>(scheduleStartedOn),
      'disclaimerAcceptedAt': serializer.toJson<DateTime?>(
        disclaimerAcceptedAt,
      ),
      'onboardingCompletedAt': serializer.toJson<DateTime?>(
        onboardingCompletedAt,
      ),
      'calorieMode': serializer.toJson<String?>(calorieMode),
      'calorieKcal': serializer.toJson<int?>(calorieKcal),
      'caloriePendingKcal': serializer.toJson<int?>(caloriePendingKcal),
      'caloriePendingReason': serializer.toJson<String?>(caloriePendingReason),
      'remindersEnabled': serializer.toJson<bool>(remindersEnabled),
      'timezone': serializer.toJson<String?>(timezone),
    };
  }

  ProfileRow copyWith({
    String? key,
    int? onboardingStep,
    Value<int?> heightCm = const Value.absent(),
    Value<int?> birthYear = const Value.absent(),
    Value<String?> sex = const Value.absent(),
    Value<String?> activityLevel = const Value.absent(),
    Value<String?> setupDate = const Value.absent(),
    Value<String?> scheduleStartedOn = const Value.absent(),
    Value<DateTime?> disclaimerAcceptedAt = const Value.absent(),
    Value<DateTime?> onboardingCompletedAt = const Value.absent(),
    Value<String?> calorieMode = const Value.absent(),
    Value<int?> calorieKcal = const Value.absent(),
    Value<int?> caloriePendingKcal = const Value.absent(),
    Value<String?> caloriePendingReason = const Value.absent(),
    bool? remindersEnabled,
    Value<String?> timezone = const Value.absent(),
  }) => ProfileRow(
    key: key ?? this.key,
    onboardingStep: onboardingStep ?? this.onboardingStep,
    heightCm: heightCm.present ? heightCm.value : this.heightCm,
    birthYear: birthYear.present ? birthYear.value : this.birthYear,
    sex: sex.present ? sex.value : this.sex,
    activityLevel: activityLevel.present
        ? activityLevel.value
        : this.activityLevel,
    setupDate: setupDate.present ? setupDate.value : this.setupDate,
    scheduleStartedOn: scheduleStartedOn.present
        ? scheduleStartedOn.value
        : this.scheduleStartedOn,
    disclaimerAcceptedAt: disclaimerAcceptedAt.present
        ? disclaimerAcceptedAt.value
        : this.disclaimerAcceptedAt,
    onboardingCompletedAt: onboardingCompletedAt.present
        ? onboardingCompletedAt.value
        : this.onboardingCompletedAt,
    calorieMode: calorieMode.present ? calorieMode.value : this.calorieMode,
    calorieKcal: calorieKcal.present ? calorieKcal.value : this.calorieKcal,
    caloriePendingKcal: caloriePendingKcal.present
        ? caloriePendingKcal.value
        : this.caloriePendingKcal,
    caloriePendingReason: caloriePendingReason.present
        ? caloriePendingReason.value
        : this.caloriePendingReason,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    timezone: timezone.present ? timezone.value : this.timezone,
  );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      key: data.key.present ? data.key.value : this.key,
      onboardingStep: data.onboardingStep.present
          ? data.onboardingStep.value
          : this.onboardingStep,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      birthYear: data.birthYear.present ? data.birthYear.value : this.birthYear,
      sex: data.sex.present ? data.sex.value : this.sex,
      activityLevel: data.activityLevel.present
          ? data.activityLevel.value
          : this.activityLevel,
      setupDate: data.setupDate.present ? data.setupDate.value : this.setupDate,
      scheduleStartedOn: data.scheduleStartedOn.present
          ? data.scheduleStartedOn.value
          : this.scheduleStartedOn,
      disclaimerAcceptedAt: data.disclaimerAcceptedAt.present
          ? data.disclaimerAcceptedAt.value
          : this.disclaimerAcceptedAt,
      onboardingCompletedAt: data.onboardingCompletedAt.present
          ? data.onboardingCompletedAt.value
          : this.onboardingCompletedAt,
      calorieMode: data.calorieMode.present
          ? data.calorieMode.value
          : this.calorieMode,
      calorieKcal: data.calorieKcal.present
          ? data.calorieKcal.value
          : this.calorieKcal,
      caloriePendingKcal: data.caloriePendingKcal.present
          ? data.caloriePendingKcal.value
          : this.caloriePendingKcal,
      caloriePendingReason: data.caloriePendingReason.present
          ? data.caloriePendingReason.value
          : this.caloriePendingReason,
      remindersEnabled: data.remindersEnabled.present
          ? data.remindersEnabled.value
          : this.remindersEnabled,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('key: $key, ')
          ..write('onboardingStep: $onboardingStep, ')
          ..write('heightCm: $heightCm, ')
          ..write('birthYear: $birthYear, ')
          ..write('sex: $sex, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('setupDate: $setupDate, ')
          ..write('scheduleStartedOn: $scheduleStartedOn, ')
          ..write('disclaimerAcceptedAt: $disclaimerAcceptedAt, ')
          ..write('onboardingCompletedAt: $onboardingCompletedAt, ')
          ..write('calorieMode: $calorieMode, ')
          ..write('calorieKcal: $calorieKcal, ')
          ..write('caloriePendingKcal: $caloriePendingKcal, ')
          ..write('caloriePendingReason: $caloriePendingReason, ')
          ..write('remindersEnabled: $remindersEnabled, ')
          ..write('timezone: $timezone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    key,
    onboardingStep,
    heightCm,
    birthYear,
    sex,
    activityLevel,
    setupDate,
    scheduleStartedOn,
    disclaimerAcceptedAt,
    onboardingCompletedAt,
    calorieMode,
    calorieKcal,
    caloriePendingKcal,
    caloriePendingReason,
    remindersEnabled,
    timezone,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.key == this.key &&
          other.onboardingStep == this.onboardingStep &&
          other.heightCm == this.heightCm &&
          other.birthYear == this.birthYear &&
          other.sex == this.sex &&
          other.activityLevel == this.activityLevel &&
          other.setupDate == this.setupDate &&
          other.scheduleStartedOn == this.scheduleStartedOn &&
          other.disclaimerAcceptedAt == this.disclaimerAcceptedAt &&
          other.onboardingCompletedAt == this.onboardingCompletedAt &&
          other.calorieMode == this.calorieMode &&
          other.calorieKcal == this.calorieKcal &&
          other.caloriePendingKcal == this.caloriePendingKcal &&
          other.caloriePendingReason == this.caloriePendingReason &&
          other.remindersEnabled == this.remindersEnabled &&
          other.timezone == this.timezone);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<String> key;
  final Value<int> onboardingStep;
  final Value<int?> heightCm;
  final Value<int?> birthYear;
  final Value<String?> sex;
  final Value<String?> activityLevel;
  final Value<String?> setupDate;
  final Value<String?> scheduleStartedOn;
  final Value<DateTime?> disclaimerAcceptedAt;
  final Value<DateTime?> onboardingCompletedAt;
  final Value<String?> calorieMode;
  final Value<int?> calorieKcal;
  final Value<int?> caloriePendingKcal;
  final Value<String?> caloriePendingReason;
  final Value<bool> remindersEnabled;
  final Value<String?> timezone;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.key = const Value.absent(),
    this.onboardingStep = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.birthYear = const Value.absent(),
    this.sex = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.setupDate = const Value.absent(),
    this.scheduleStartedOn = const Value.absent(),
    this.disclaimerAcceptedAt = const Value.absent(),
    this.onboardingCompletedAt = const Value.absent(),
    this.calorieMode = const Value.absent(),
    this.calorieKcal = const Value.absent(),
    this.caloriePendingKcal = const Value.absent(),
    this.caloriePendingReason = const Value.absent(),
    this.remindersEnabled = const Value.absent(),
    this.timezone = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String key,
    required int onboardingStep,
    this.heightCm = const Value.absent(),
    this.birthYear = const Value.absent(),
    this.sex = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.setupDate = const Value.absent(),
    this.scheduleStartedOn = const Value.absent(),
    this.disclaimerAcceptedAt = const Value.absent(),
    this.onboardingCompletedAt = const Value.absent(),
    this.calorieMode = const Value.absent(),
    this.calorieKcal = const Value.absent(),
    this.caloriePendingKcal = const Value.absent(),
    this.caloriePendingReason = const Value.absent(),
    this.remindersEnabled = const Value.absent(),
    this.timezone = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       onboardingStep = Value(onboardingStep);
  static Insertable<ProfileRow> custom({
    Expression<String>? key,
    Expression<int>? onboardingStep,
    Expression<int>? heightCm,
    Expression<int>? birthYear,
    Expression<String>? sex,
    Expression<String>? activityLevel,
    Expression<String>? setupDate,
    Expression<String>? scheduleStartedOn,
    Expression<DateTime>? disclaimerAcceptedAt,
    Expression<DateTime>? onboardingCompletedAt,
    Expression<String>? calorieMode,
    Expression<int>? calorieKcal,
    Expression<int>? caloriePendingKcal,
    Expression<String>? caloriePendingReason,
    Expression<bool>? remindersEnabled,
    Expression<String>? timezone,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (onboardingStep != null) 'onboarding_step': onboardingStep,
      if (heightCm != null) 'height_cm': heightCm,
      if (birthYear != null) 'birth_year': birthYear,
      if (sex != null) 'sex': sex,
      if (activityLevel != null) 'activity_level': activityLevel,
      if (setupDate != null) 'setup_date': setupDate,
      if (scheduleStartedOn != null) 'schedule_started_on': scheduleStartedOn,
      if (disclaimerAcceptedAt != null)
        'disclaimer_accepted_at': disclaimerAcceptedAt,
      if (onboardingCompletedAt != null)
        'onboarding_completed_at': onboardingCompletedAt,
      if (calorieMode != null) 'calorie_mode': calorieMode,
      if (calorieKcal != null) 'calorie_kcal': calorieKcal,
      if (caloriePendingKcal != null)
        'calorie_pending_kcal': caloriePendingKcal,
      if (caloriePendingReason != null)
        'calorie_pending_reason': caloriePendingReason,
      if (remindersEnabled != null) 'reminders_enabled': remindersEnabled,
      if (timezone != null) 'timezone': timezone,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? key,
    Value<int>? onboardingStep,
    Value<int?>? heightCm,
    Value<int?>? birthYear,
    Value<String?>? sex,
    Value<String?>? activityLevel,
    Value<String?>? setupDate,
    Value<String?>? scheduleStartedOn,
    Value<DateTime?>? disclaimerAcceptedAt,
    Value<DateTime?>? onboardingCompletedAt,
    Value<String?>? calorieMode,
    Value<int?>? calorieKcal,
    Value<int?>? caloriePendingKcal,
    Value<String?>? caloriePendingReason,
    Value<bool>? remindersEnabled,
    Value<String?>? timezone,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      key: key ?? this.key,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      heightCm: heightCm ?? this.heightCm,
      birthYear: birthYear ?? this.birthYear,
      sex: sex ?? this.sex,
      activityLevel: activityLevel ?? this.activityLevel,
      setupDate: setupDate ?? this.setupDate,
      scheduleStartedOn: scheduleStartedOn ?? this.scheduleStartedOn,
      disclaimerAcceptedAt: disclaimerAcceptedAt ?? this.disclaimerAcceptedAt,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      calorieMode: calorieMode ?? this.calorieMode,
      calorieKcal: calorieKcal ?? this.calorieKcal,
      caloriePendingKcal: caloriePendingKcal ?? this.caloriePendingKcal,
      caloriePendingReason: caloriePendingReason ?? this.caloriePendingReason,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      timezone: timezone ?? this.timezone,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (onboardingStep.present) {
      map['onboarding_step'] = Variable<int>(onboardingStep.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<int>(heightCm.value);
    }
    if (birthYear.present) {
      map['birth_year'] = Variable<int>(birthYear.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(sex.value);
    }
    if (activityLevel.present) {
      map['activity_level'] = Variable<String>(activityLevel.value);
    }
    if (setupDate.present) {
      map['setup_date'] = Variable<String>(setupDate.value);
    }
    if (scheduleStartedOn.present) {
      map['schedule_started_on'] = Variable<String>(scheduleStartedOn.value);
    }
    if (disclaimerAcceptedAt.present) {
      map['disclaimer_accepted_at'] = Variable<DateTime>(
        disclaimerAcceptedAt.value,
      );
    }
    if (onboardingCompletedAt.present) {
      map['onboarding_completed_at'] = Variable<DateTime>(
        onboardingCompletedAt.value,
      );
    }
    if (calorieMode.present) {
      map['calorie_mode'] = Variable<String>(calorieMode.value);
    }
    if (calorieKcal.present) {
      map['calorie_kcal'] = Variable<int>(calorieKcal.value);
    }
    if (caloriePendingKcal.present) {
      map['calorie_pending_kcal'] = Variable<int>(caloriePendingKcal.value);
    }
    if (caloriePendingReason.present) {
      map['calorie_pending_reason'] = Variable<String>(
        caloriePendingReason.value,
      );
    }
    if (remindersEnabled.present) {
      map['reminders_enabled'] = Variable<bool>(remindersEnabled.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('key: $key, ')
          ..write('onboardingStep: $onboardingStep, ')
          ..write('heightCm: $heightCm, ')
          ..write('birthYear: $birthYear, ')
          ..write('sex: $sex, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('setupDate: $setupDate, ')
          ..write('scheduleStartedOn: $scheduleStartedOn, ')
          ..write('disclaimerAcceptedAt: $disclaimerAcceptedAt, ')
          ..write('onboardingCompletedAt: $onboardingCompletedAt, ')
          ..write('calorieMode: $calorieMode, ')
          ..write('calorieKcal: $calorieKcal, ')
          ..write('caloriePendingKcal: $caloriePendingKcal, ')
          ..write('caloriePendingReason: $caloriePendingReason, ')
          ..write('remindersEnabled: $remindersEnabled, ')
          ..write('timezone: $timezone, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeightsTable extends Weights with TableInfo<$WeightsTable, WeightRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _weekStartMeta = const VerificationMeta(
    'weekStart',
  );
  @override
  late final GeneratedColumn<String> weekStart = GeneratedColumn<String>(
    'week_start',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightKgX10Meta = const VerificationMeta(
    'weightKgX10',
  );
  @override
  late final GeneratedColumn<int> weightKgX10 = GeneratedColumn<int>(
    'weight_kg_x10',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [weekStart, weightKgX10];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weights';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeightRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('week_start')) {
      context.handle(
        _weekStartMeta,
        weekStart.isAcceptableOrUnknown(data['week_start']!, _weekStartMeta),
      );
    } else if (isInserting) {
      context.missing(_weekStartMeta);
    }
    if (data.containsKey('weight_kg_x10')) {
      context.handle(
        _weightKgX10Meta,
        weightKgX10.isAcceptableOrUnknown(
          data['weight_kg_x10']!,
          _weightKgX10Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_weightKgX10Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {weekStart};
  @override
  WeightRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeightRow(
      weekStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}week_start'],
      )!,
      weightKgX10: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weight_kg_x10'],
      )!,
    );
  }

  @override
  $WeightsTable createAlias(String alias) {
    return $WeightsTable(attachedDatabase, alias);
  }
}

class WeightRow extends DataClass implements Insertable<WeightRow> {
  /// `YYYY-MM-DD` của thứ 2.
  final String weekStart;
  final int weightKgX10;
  const WeightRow({required this.weekStart, required this.weightKgX10});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['week_start'] = Variable<String>(weekStart);
    map['weight_kg_x10'] = Variable<int>(weightKgX10);
    return map;
  }

  WeightsCompanion toCompanion(bool nullToAbsent) {
    return WeightsCompanion(
      weekStart: Value(weekStart),
      weightKgX10: Value(weightKgX10),
    );
  }

  factory WeightRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeightRow(
      weekStart: serializer.fromJson<String>(json['weekStart']),
      weightKgX10: serializer.fromJson<int>(json['weightKgX10']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'weekStart': serializer.toJson<String>(weekStart),
      'weightKgX10': serializer.toJson<int>(weightKgX10),
    };
  }

  WeightRow copyWith({String? weekStart, int? weightKgX10}) => WeightRow(
    weekStart: weekStart ?? this.weekStart,
    weightKgX10: weightKgX10 ?? this.weightKgX10,
  );
  WeightRow copyWithCompanion(WeightsCompanion data) {
    return WeightRow(
      weekStart: data.weekStart.present ? data.weekStart.value : this.weekStart,
      weightKgX10: data.weightKgX10.present
          ? data.weightKgX10.value
          : this.weightKgX10,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeightRow(')
          ..write('weekStart: $weekStart, ')
          ..write('weightKgX10: $weightKgX10')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(weekStart, weightKgX10);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeightRow &&
          other.weekStart == this.weekStart &&
          other.weightKgX10 == this.weightKgX10);
}

class WeightsCompanion extends UpdateCompanion<WeightRow> {
  final Value<String> weekStart;
  final Value<int> weightKgX10;
  final Value<int> rowid;
  const WeightsCompanion({
    this.weekStart = const Value.absent(),
    this.weightKgX10 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeightsCompanion.insert({
    required String weekStart,
    required int weightKgX10,
    this.rowid = const Value.absent(),
  }) : weekStart = Value(weekStart),
       weightKgX10 = Value(weightKgX10);
  static Insertable<WeightRow> custom({
    Expression<String>? weekStart,
    Expression<int>? weightKgX10,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (weekStart != null) 'week_start': weekStart,
      if (weightKgX10 != null) 'weight_kg_x10': weightKgX10,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeightsCompanion copyWith({
    Value<String>? weekStart,
    Value<int>? weightKgX10,
    Value<int>? rowid,
  }) {
    return WeightsCompanion(
      weekStart: weekStart ?? this.weekStart,
      weightKgX10: weightKgX10 ?? this.weightKgX10,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (weekStart.present) {
      map['week_start'] = Variable<String>(weekStart.value);
    }
    if (weightKgX10.present) {
      map['weight_kg_x10'] = Variable<int>(weightKgX10.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeightsCompanion(')
          ..write('weekStart: $weekStart, ')
          ..write('weightKgX10: $weightKgX10, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OnboardingDraftTable extends OnboardingDraft
    with TableInfo<$OnboardingDraftTable, OnboardingDraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnboardingDraftTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('id = 1'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<String> height = GeneratedColumn<String>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _birthYearMeta = const VerificationMeta(
    'birthYear',
  );
  @override
  late final GeneratedColumn<int> birthYear = GeneratedColumn<int>(
    'birth_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
    'sex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityLevelMeta = const VerificationMeta(
    'activityLevel',
  );
  @override
  late final GeneratedColumn<String> activityLevel = GeneratedColumn<String>(
    'activity_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<String> weight = GeneratedColumn<String>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _templateMeta = const VerificationMeta(
    'template',
  );
  @override
  late final GeneratedColumn<String> template = GeneratedColumn<String>(
    'template',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    height,
    birthYear,
    sex,
    activityLevel,
    weight,
    template,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'onboarding_draft';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnboardingDraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('birth_year')) {
      context.handle(
        _birthYearMeta,
        birthYear.isAcceptableOrUnknown(data['birth_year']!, _birthYearMeta),
      );
    }
    if (data.containsKey('sex')) {
      context.handle(
        _sexMeta,
        sex.isAcceptableOrUnknown(data['sex']!, _sexMeta),
      );
    }
    if (data.containsKey('activity_level')) {
      context.handle(
        _activityLevelMeta,
        activityLevel.isAcceptableOrUnknown(
          data['activity_level']!,
          _activityLevelMeta,
        ),
      );
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('template')) {
      context.handle(
        _templateMeta,
        template.isAcceptableOrUnknown(data['template']!, _templateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OnboardingDraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnboardingDraftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}height'],
      )!,
      birthYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birth_year'],
      ),
      sex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sex'],
      ),
      activityLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_level'],
      ),
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weight'],
      )!,
      template: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template'],
      ),
    );
  }

  @override
  $OnboardingDraftTable createAlias(String alias) {
    return $OnboardingDraftTable(attachedDatabase, alias);
  }
}

class OnboardingDraftRow extends DataClass
    implements Insertable<OnboardingDraftRow> {
  final int id;

  /// Chuỗi Bạn gõ, giữ nguyên kể cả khi sai (04 §6.13.5).
  final String height;
  final int? birthYear;
  final String? sex;
  final String? activityLevel;
  final String weight;

  /// Lịch tuần đang xếp dở ở S-05 (JSON như `WeeklyTemplate.toJson`, VS-04).
  final String? template;
  const OnboardingDraftRow({
    required this.id,
    required this.height,
    this.birthYear,
    this.sex,
    this.activityLevel,
    required this.weight,
    this.template,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['height'] = Variable<String>(height);
    if (!nullToAbsent || birthYear != null) {
      map['birth_year'] = Variable<int>(birthYear);
    }
    if (!nullToAbsent || sex != null) {
      map['sex'] = Variable<String>(sex);
    }
    if (!nullToAbsent || activityLevel != null) {
      map['activity_level'] = Variable<String>(activityLevel);
    }
    map['weight'] = Variable<String>(weight);
    if (!nullToAbsent || template != null) {
      map['template'] = Variable<String>(template);
    }
    return map;
  }

  OnboardingDraftCompanion toCompanion(bool nullToAbsent) {
    return OnboardingDraftCompanion(
      id: Value(id),
      height: Value(height),
      birthYear: birthYear == null && nullToAbsent
          ? const Value.absent()
          : Value(birthYear),
      sex: sex == null && nullToAbsent ? const Value.absent() : Value(sex),
      activityLevel: activityLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(activityLevel),
      weight: Value(weight),
      template: template == null && nullToAbsent
          ? const Value.absent()
          : Value(template),
    );
  }

  factory OnboardingDraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnboardingDraftRow(
      id: serializer.fromJson<int>(json['id']),
      height: serializer.fromJson<String>(json['height']),
      birthYear: serializer.fromJson<int?>(json['birthYear']),
      sex: serializer.fromJson<String?>(json['sex']),
      activityLevel: serializer.fromJson<String?>(json['activityLevel']),
      weight: serializer.fromJson<String>(json['weight']),
      template: serializer.fromJson<String?>(json['template']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'height': serializer.toJson<String>(height),
      'birthYear': serializer.toJson<int?>(birthYear),
      'sex': serializer.toJson<String?>(sex),
      'activityLevel': serializer.toJson<String?>(activityLevel),
      'weight': serializer.toJson<String>(weight),
      'template': serializer.toJson<String?>(template),
    };
  }

  OnboardingDraftRow copyWith({
    int? id,
    String? height,
    Value<int?> birthYear = const Value.absent(),
    Value<String?> sex = const Value.absent(),
    Value<String?> activityLevel = const Value.absent(),
    String? weight,
    Value<String?> template = const Value.absent(),
  }) => OnboardingDraftRow(
    id: id ?? this.id,
    height: height ?? this.height,
    birthYear: birthYear.present ? birthYear.value : this.birthYear,
    sex: sex.present ? sex.value : this.sex,
    activityLevel: activityLevel.present
        ? activityLevel.value
        : this.activityLevel,
    weight: weight ?? this.weight,
    template: template.present ? template.value : this.template,
  );
  OnboardingDraftRow copyWithCompanion(OnboardingDraftCompanion data) {
    return OnboardingDraftRow(
      id: data.id.present ? data.id.value : this.id,
      height: data.height.present ? data.height.value : this.height,
      birthYear: data.birthYear.present ? data.birthYear.value : this.birthYear,
      sex: data.sex.present ? data.sex.value : this.sex,
      activityLevel: data.activityLevel.present
          ? data.activityLevel.value
          : this.activityLevel,
      weight: data.weight.present ? data.weight.value : this.weight,
      template: data.template.present ? data.template.value : this.template,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingDraftRow(')
          ..write('id: $id, ')
          ..write('height: $height, ')
          ..write('birthYear: $birthYear, ')
          ..write('sex: $sex, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('weight: $weight, ')
          ..write('template: $template')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, height, birthYear, sex, activityLevel, weight, template);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnboardingDraftRow &&
          other.id == this.id &&
          other.height == this.height &&
          other.birthYear == this.birthYear &&
          other.sex == this.sex &&
          other.activityLevel == this.activityLevel &&
          other.weight == this.weight &&
          other.template == this.template);
}

class OnboardingDraftCompanion extends UpdateCompanion<OnboardingDraftRow> {
  final Value<int> id;
  final Value<String> height;
  final Value<int?> birthYear;
  final Value<String?> sex;
  final Value<String?> activityLevel;
  final Value<String> weight;
  final Value<String?> template;
  const OnboardingDraftCompanion({
    this.id = const Value.absent(),
    this.height = const Value.absent(),
    this.birthYear = const Value.absent(),
    this.sex = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.weight = const Value.absent(),
    this.template = const Value.absent(),
  });
  OnboardingDraftCompanion.insert({
    this.id = const Value.absent(),
    this.height = const Value.absent(),
    this.birthYear = const Value.absent(),
    this.sex = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.weight = const Value.absent(),
    this.template = const Value.absent(),
  });
  static Insertable<OnboardingDraftRow> custom({
    Expression<int>? id,
    Expression<String>? height,
    Expression<int>? birthYear,
    Expression<String>? sex,
    Expression<String>? activityLevel,
    Expression<String>? weight,
    Expression<String>? template,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (height != null) 'height': height,
      if (birthYear != null) 'birth_year': birthYear,
      if (sex != null) 'sex': sex,
      if (activityLevel != null) 'activity_level': activityLevel,
      if (weight != null) 'weight': weight,
      if (template != null) 'template': template,
    });
  }

  OnboardingDraftCompanion copyWith({
    Value<int>? id,
    Value<String>? height,
    Value<int?>? birthYear,
    Value<String?>? sex,
    Value<String?>? activityLevel,
    Value<String>? weight,
    Value<String?>? template,
  }) {
    return OnboardingDraftCompanion(
      id: id ?? this.id,
      height: height ?? this.height,
      birthYear: birthYear ?? this.birthYear,
      sex: sex ?? this.sex,
      activityLevel: activityLevel ?? this.activityLevel,
      weight: weight ?? this.weight,
      template: template ?? this.template,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (height.present) {
      map['height'] = Variable<String>(height.value);
    }
    if (birthYear.present) {
      map['birth_year'] = Variable<int>(birthYear.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(sex.value);
    }
    if (activityLevel.present) {
      map['activity_level'] = Variable<String>(activityLevel.value);
    }
    if (weight.present) {
      map['weight'] = Variable<String>(weight.value);
    }
    if (template.present) {
      map['template'] = Variable<String>(template.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingDraftCompanion(')
          ..write('id: $id, ')
          ..write('height: $height, ')
          ..write('birthYear: $birthYear, ')
          ..write('sex: $sex, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('weight: $weight, ')
          ..write('template: $template')
          ..write(')'))
        .toString();
  }
}

class $WeeklyTemplatesTable extends WeeklyTemplates
    with TableInfo<$WeeklyTemplatesTable, WeeklyTemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklyTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _daysMeta = const VerificationMeta('days');
  @override
  late final GeneratedColumn<String> days = GeneratedColumn<String>(
    'days',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, days, contentHash];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeeklyTemplateRow> instance, {
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
    if (data.containsKey('days')) {
      context.handle(
        _daysMeta,
        days.isAcceptableOrUnknown(data['days']!, _daysMeta),
      );
    } else if (isInserting) {
      context.missing(_daysMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  WeeklyTemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklyTemplateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      days: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}days'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
    );
  }

  @override
  $WeeklyTemplatesTable createAlias(String alias) {
    return $WeeklyTemplatesTable(attachedDatabase, alias);
  }
}

class WeeklyTemplateRow extends DataClass
    implements Insertable<WeeklyTemplateRow> {
  final String key;
  final String days;
  final String contentHash;
  const WeeklyTemplateRow({
    required this.key,
    required this.days,
    required this.contentHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['days'] = Variable<String>(days);
    map['content_hash'] = Variable<String>(contentHash);
    return map;
  }

  WeeklyTemplatesCompanion toCompanion(bool nullToAbsent) {
    return WeeklyTemplatesCompanion(
      key: Value(key),
      days: Value(days),
      contentHash: Value(contentHash),
    );
  }

  factory WeeklyTemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklyTemplateRow(
      key: serializer.fromJson<String>(json['key']),
      days: serializer.fromJson<String>(json['days']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'days': serializer.toJson<String>(days),
      'contentHash': serializer.toJson<String>(contentHash),
    };
  }

  WeeklyTemplateRow copyWith({
    String? key,
    String? days,
    String? contentHash,
  }) => WeeklyTemplateRow(
    key: key ?? this.key,
    days: days ?? this.days,
    contentHash: contentHash ?? this.contentHash,
  );
  WeeklyTemplateRow copyWithCompanion(WeeklyTemplatesCompanion data) {
    return WeeklyTemplateRow(
      key: data.key.present ? data.key.value : this.key,
      days: data.days.present ? data.days.value : this.days,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyTemplateRow(')
          ..write('key: $key, ')
          ..write('days: $days, ')
          ..write('contentHash: $contentHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, days, contentHash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklyTemplateRow &&
          other.key == this.key &&
          other.days == this.days &&
          other.contentHash == this.contentHash);
}

class WeeklyTemplatesCompanion extends UpdateCompanion<WeeklyTemplateRow> {
  final Value<String> key;
  final Value<String> days;
  final Value<String> contentHash;
  final Value<int> rowid;
  const WeeklyTemplatesCompanion({
    this.key = const Value.absent(),
    this.days = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeeklyTemplatesCompanion.insert({
    required String key,
    required String days,
    required String contentHash,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       days = Value(days),
       contentHash = Value(contentHash);
  static Insertable<WeeklyTemplateRow> custom({
    Expression<String>? key,
    Expression<String>? days,
    Expression<String>? contentHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (days != null) 'days': days,
      if (contentHash != null) 'content_hash': contentHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeeklyTemplatesCompanion copyWith({
    Value<String>? key,
    Value<String>? days,
    Value<String>? contentHash,
    Value<int>? rowid,
  }) {
    return WeeklyTemplatesCompanion(
      key: key ?? this.key,
      days: days ?? this.days,
      contentHash: contentHash ?? this.contentHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (days.present) {
      map['days'] = Variable<String>(days.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyTemplatesCompanion(')
          ..write('key: $key, ')
          ..write('days: $days, ')
          ..write('contentHash: $contentHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MonthPlansTable extends MonthPlans
    with TableInfo<$MonthPlansTable, MonthPlanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonthPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateHashMeta = const VerificationMeta(
    'templateHash',
  );
  @override
  late final GeneratedColumn<String> templateHash = GeneratedColumn<String>(
    'template_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _redistributedAtMeta = const VerificationMeta(
    'redistributedAt',
  );
  @override
  late final GeneratedColumn<DateTime> redistributedAt =
      GeneratedColumn<DateTime>(
        'redistributed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    month,
    startDate,
    templateHash,
    generatedAt,
    redistributedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'month_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<MonthPlanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('template_hash')) {
      context.handle(
        _templateHashMeta,
        templateHash.isAcceptableOrUnknown(
          data['template_hash']!,
          _templateHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_templateHashMeta);
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    if (data.containsKey('redistributed_at')) {
      context.handle(
        _redistributedAtMeta,
        redistributedAt.isAcceptableOrUnknown(
          data['redistributed_at']!,
          _redistributedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {month};
  @override
  MonthPlanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonthPlanRow(
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      templateHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_hash'],
      )!,
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      )!,
      redistributedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}redistributed_at'],
      ),
    );
  }

  @override
  $MonthPlansTable createAlias(String alias) {
    return $MonthPlansTable(attachedDatabase, alias);
  }
}

class MonthPlanRow extends DataClass implements Insertable<MonthPlanRow> {
  final String month;

  /// `YYYY-MM-DD`.
  final String startDate;
  final String templateHash;
  final DateTime generatedAt;
  final DateTime? redistributedAt;
  const MonthPlanRow({
    required this.month,
    required this.startDate,
    required this.templateHash,
    required this.generatedAt,
    this.redistributedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['month'] = Variable<String>(month);
    map['start_date'] = Variable<String>(startDate);
    map['template_hash'] = Variable<String>(templateHash);
    map['generated_at'] = Variable<DateTime>(generatedAt);
    if (!nullToAbsent || redistributedAt != null) {
      map['redistributed_at'] = Variable<DateTime>(redistributedAt);
    }
    return map;
  }

  MonthPlansCompanion toCompanion(bool nullToAbsent) {
    return MonthPlansCompanion(
      month: Value(month),
      startDate: Value(startDate),
      templateHash: Value(templateHash),
      generatedAt: Value(generatedAt),
      redistributedAt: redistributedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(redistributedAt),
    );
  }

  factory MonthPlanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonthPlanRow(
      month: serializer.fromJson<String>(json['month']),
      startDate: serializer.fromJson<String>(json['startDate']),
      templateHash: serializer.fromJson<String>(json['templateHash']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
      redistributedAt: serializer.fromJson<DateTime?>(json['redistributedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'month': serializer.toJson<String>(month),
      'startDate': serializer.toJson<String>(startDate),
      'templateHash': serializer.toJson<String>(templateHash),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
      'redistributedAt': serializer.toJson<DateTime?>(redistributedAt),
    };
  }

  MonthPlanRow copyWith({
    String? month,
    String? startDate,
    String? templateHash,
    DateTime? generatedAt,
    Value<DateTime?> redistributedAt = const Value.absent(),
  }) => MonthPlanRow(
    month: month ?? this.month,
    startDate: startDate ?? this.startDate,
    templateHash: templateHash ?? this.templateHash,
    generatedAt: generatedAt ?? this.generatedAt,
    redistributedAt: redistributedAt.present
        ? redistributedAt.value
        : this.redistributedAt,
  );
  MonthPlanRow copyWithCompanion(MonthPlansCompanion data) {
    return MonthPlanRow(
      month: data.month.present ? data.month.value : this.month,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      templateHash: data.templateHash.present
          ? data.templateHash.value
          : this.templateHash,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
      redistributedAt: data.redistributedAt.present
          ? data.redistributedAt.value
          : this.redistributedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonthPlanRow(')
          ..write('month: $month, ')
          ..write('startDate: $startDate, ')
          ..write('templateHash: $templateHash, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('redistributedAt: $redistributedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(month, startDate, templateHash, generatedAt, redistributedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthPlanRow &&
          other.month == this.month &&
          other.startDate == this.startDate &&
          other.templateHash == this.templateHash &&
          other.generatedAt == this.generatedAt &&
          other.redistributedAt == this.redistributedAt);
}

class MonthPlansCompanion extends UpdateCompanion<MonthPlanRow> {
  final Value<String> month;
  final Value<String> startDate;
  final Value<String> templateHash;
  final Value<DateTime> generatedAt;
  final Value<DateTime?> redistributedAt;
  final Value<int> rowid;
  const MonthPlansCompanion({
    this.month = const Value.absent(),
    this.startDate = const Value.absent(),
    this.templateHash = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.redistributedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MonthPlansCompanion.insert({
    required String month,
    required String startDate,
    required String templateHash,
    required DateTime generatedAt,
    this.redistributedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : month = Value(month),
       startDate = Value(startDate),
       templateHash = Value(templateHash),
       generatedAt = Value(generatedAt);
  static Insertable<MonthPlanRow> custom({
    Expression<String>? month,
    Expression<String>? startDate,
    Expression<String>? templateHash,
    Expression<DateTime>? generatedAt,
    Expression<DateTime>? redistributedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (month != null) 'month': month,
      if (startDate != null) 'start_date': startDate,
      if (templateHash != null) 'template_hash': templateHash,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (redistributedAt != null) 'redistributed_at': redistributedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MonthPlansCompanion copyWith({
    Value<String>? month,
    Value<String>? startDate,
    Value<String>? templateHash,
    Value<DateTime>? generatedAt,
    Value<DateTime?>? redistributedAt,
    Value<int>? rowid,
  }) {
    return MonthPlansCompanion(
      month: month ?? this.month,
      startDate: startDate ?? this.startDate,
      templateHash: templateHash ?? this.templateHash,
      generatedAt: generatedAt ?? this.generatedAt,
      redistributedAt: redistributedAt ?? this.redistributedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (templateHash.present) {
      map['template_hash'] = Variable<String>(templateHash.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (redistributedAt.present) {
      map['redistributed_at'] = Variable<DateTime>(redistributedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MonthPlansCompanion(')
          ..write('month: $month, ')
          ..write('startDate: $startDate, ')
          ..write('templateHash: $templateHash, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('redistributedAt: $redistributedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DaysTable extends Days with TableInfo<$DaysTable, DayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
    'time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _musclesMeta = const VerificationMeta(
    'muscles',
  );
  @override
  late final GeneratedColumn<String> muscles = GeneratedColumn<String>(
    'muscles',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markMeta = const VerificationMeta('mark');
  @override
  late final GeneratedColumn<String> mark = GeneratedColumn<String>(
    'mark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualMusclesMeta = const VerificationMeta(
    'actualMuscles',
  );
  @override
  late final GeneratedColumn<String> actualMuscles = GeneratedColumn<String>(
    'actual_muscles',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _markedAtMeta = const VerificationMeta(
    'markedAt',
  );
  @override
  late final GeneratedColumn<DateTime> markedAt = GeneratedColumn<DateTime>(
    'marked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extraMusclesMeta = const VerificationMeta(
    'extraMuscles',
  );
  @override
  late final GeneratedColumn<String> extraMuscles = GeneratedColumn<String>(
    'extra_muscles',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extraLoggedAtMeta = const VerificationMeta(
    'extraLoggedAt',
  );
  @override
  late final GeneratedColumn<DateTime> extraLoggedAt =
      GeneratedColumn<DateTime>(
        'extra_logged_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    kind,
    time,
    muscles,
    source,
    mark,
    actualMuscles,
    markedAt,
    extraMuscles,
    extraLoggedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'days';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    }
    if (data.containsKey('muscles')) {
      context.handle(
        _musclesMeta,
        muscles.isAcceptableOrUnknown(data['muscles']!, _musclesMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('mark')) {
      context.handle(
        _markMeta,
        mark.isAcceptableOrUnknown(data['mark']!, _markMeta),
      );
    }
    if (data.containsKey('actual_muscles')) {
      context.handle(
        _actualMusclesMeta,
        actualMuscles.isAcceptableOrUnknown(
          data['actual_muscles']!,
          _actualMusclesMeta,
        ),
      );
    }
    if (data.containsKey('marked_at')) {
      context.handle(
        _markedAtMeta,
        markedAt.isAcceptableOrUnknown(data['marked_at']!, _markedAtMeta),
      );
    }
    if (data.containsKey('extra_muscles')) {
      context.handle(
        _extraMusclesMeta,
        extraMuscles.isAcceptableOrUnknown(
          data['extra_muscles']!,
          _extraMusclesMeta,
        ),
      );
    }
    if (data.containsKey('extra_logged_at')) {
      context.handle(
        _extraLoggedAtMeta,
        extraLoggedAt.isAcceptableOrUnknown(
          data['extra_logged_at']!,
          _extraLoggedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  DayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time'],
      ),
      muscles: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}muscles'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      mark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mark'],
      ),
      actualMuscles: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actual_muscles'],
      ),
      markedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}marked_at'],
      ),
      extraMuscles: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_muscles'],
      ),
      extraLoggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}extra_logged_at'],
      ),
    );
  }

  @override
  $DaysTable createAlias(String alias) {
    return $DaysTable(attachedDatabase, alias);
  }
}

class DayRow extends DataClass implements Insertable<DayRow> {
  final String date;
  final String kind;

  /// `HH:mm`.
  final String? time;
  final String? muscles;
  final String source;
  final String? mark;
  final String? actualMuscles;
  final DateTime? markedAt;
  final String? extraMuscles;
  final DateTime? extraLoggedAt;
  const DayRow({
    required this.date,
    required this.kind,
    this.time,
    this.muscles,
    required this.source,
    this.mark,
    this.actualMuscles,
    this.markedAt,
    this.extraMuscles,
    this.extraLoggedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || time != null) {
      map['time'] = Variable<String>(time);
    }
    if (!nullToAbsent || muscles != null) {
      map['muscles'] = Variable<String>(muscles);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || mark != null) {
      map['mark'] = Variable<String>(mark);
    }
    if (!nullToAbsent || actualMuscles != null) {
      map['actual_muscles'] = Variable<String>(actualMuscles);
    }
    if (!nullToAbsent || markedAt != null) {
      map['marked_at'] = Variable<DateTime>(markedAt);
    }
    if (!nullToAbsent || extraMuscles != null) {
      map['extra_muscles'] = Variable<String>(extraMuscles);
    }
    if (!nullToAbsent || extraLoggedAt != null) {
      map['extra_logged_at'] = Variable<DateTime>(extraLoggedAt);
    }
    return map;
  }

  DaysCompanion toCompanion(bool nullToAbsent) {
    return DaysCompanion(
      date: Value(date),
      kind: Value(kind),
      time: time == null && nullToAbsent ? const Value.absent() : Value(time),
      muscles: muscles == null && nullToAbsent
          ? const Value.absent()
          : Value(muscles),
      source: Value(source),
      mark: mark == null && nullToAbsent ? const Value.absent() : Value(mark),
      actualMuscles: actualMuscles == null && nullToAbsent
          ? const Value.absent()
          : Value(actualMuscles),
      markedAt: markedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(markedAt),
      extraMuscles: extraMuscles == null && nullToAbsent
          ? const Value.absent()
          : Value(extraMuscles),
      extraLoggedAt: extraLoggedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(extraLoggedAt),
    );
  }

  factory DayRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayRow(
      date: serializer.fromJson<String>(json['date']),
      kind: serializer.fromJson<String>(json['kind']),
      time: serializer.fromJson<String?>(json['time']),
      muscles: serializer.fromJson<String?>(json['muscles']),
      source: serializer.fromJson<String>(json['source']),
      mark: serializer.fromJson<String?>(json['mark']),
      actualMuscles: serializer.fromJson<String?>(json['actualMuscles']),
      markedAt: serializer.fromJson<DateTime?>(json['markedAt']),
      extraMuscles: serializer.fromJson<String?>(json['extraMuscles']),
      extraLoggedAt: serializer.fromJson<DateTime?>(json['extraLoggedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'kind': serializer.toJson<String>(kind),
      'time': serializer.toJson<String?>(time),
      'muscles': serializer.toJson<String?>(muscles),
      'source': serializer.toJson<String>(source),
      'mark': serializer.toJson<String?>(mark),
      'actualMuscles': serializer.toJson<String?>(actualMuscles),
      'markedAt': serializer.toJson<DateTime?>(markedAt),
      'extraMuscles': serializer.toJson<String?>(extraMuscles),
      'extraLoggedAt': serializer.toJson<DateTime?>(extraLoggedAt),
    };
  }

  DayRow copyWith({
    String? date,
    String? kind,
    Value<String?> time = const Value.absent(),
    Value<String?> muscles = const Value.absent(),
    String? source,
    Value<String?> mark = const Value.absent(),
    Value<String?> actualMuscles = const Value.absent(),
    Value<DateTime?> markedAt = const Value.absent(),
    Value<String?> extraMuscles = const Value.absent(),
    Value<DateTime?> extraLoggedAt = const Value.absent(),
  }) => DayRow(
    date: date ?? this.date,
    kind: kind ?? this.kind,
    time: time.present ? time.value : this.time,
    muscles: muscles.present ? muscles.value : this.muscles,
    source: source ?? this.source,
    mark: mark.present ? mark.value : this.mark,
    actualMuscles: actualMuscles.present
        ? actualMuscles.value
        : this.actualMuscles,
    markedAt: markedAt.present ? markedAt.value : this.markedAt,
    extraMuscles: extraMuscles.present ? extraMuscles.value : this.extraMuscles,
    extraLoggedAt: extraLoggedAt.present
        ? extraLoggedAt.value
        : this.extraLoggedAt,
  );
  DayRow copyWithCompanion(DaysCompanion data) {
    return DayRow(
      date: data.date.present ? data.date.value : this.date,
      kind: data.kind.present ? data.kind.value : this.kind,
      time: data.time.present ? data.time.value : this.time,
      muscles: data.muscles.present ? data.muscles.value : this.muscles,
      source: data.source.present ? data.source.value : this.source,
      mark: data.mark.present ? data.mark.value : this.mark,
      actualMuscles: data.actualMuscles.present
          ? data.actualMuscles.value
          : this.actualMuscles,
      markedAt: data.markedAt.present ? data.markedAt.value : this.markedAt,
      extraMuscles: data.extraMuscles.present
          ? data.extraMuscles.value
          : this.extraMuscles,
      extraLoggedAt: data.extraLoggedAt.present
          ? data.extraLoggedAt.value
          : this.extraLoggedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayRow(')
          ..write('date: $date, ')
          ..write('kind: $kind, ')
          ..write('time: $time, ')
          ..write('muscles: $muscles, ')
          ..write('source: $source, ')
          ..write('mark: $mark, ')
          ..write('actualMuscles: $actualMuscles, ')
          ..write('markedAt: $markedAt, ')
          ..write('extraMuscles: $extraMuscles, ')
          ..write('extraLoggedAt: $extraLoggedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    date,
    kind,
    time,
    muscles,
    source,
    mark,
    actualMuscles,
    markedAt,
    extraMuscles,
    extraLoggedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayRow &&
          other.date == this.date &&
          other.kind == this.kind &&
          other.time == this.time &&
          other.muscles == this.muscles &&
          other.source == this.source &&
          other.mark == this.mark &&
          other.actualMuscles == this.actualMuscles &&
          other.markedAt == this.markedAt &&
          other.extraMuscles == this.extraMuscles &&
          other.extraLoggedAt == this.extraLoggedAt);
}

class DaysCompanion extends UpdateCompanion<DayRow> {
  final Value<String> date;
  final Value<String> kind;
  final Value<String?> time;
  final Value<String?> muscles;
  final Value<String> source;
  final Value<String?> mark;
  final Value<String?> actualMuscles;
  final Value<DateTime?> markedAt;
  final Value<String?> extraMuscles;
  final Value<DateTime?> extraLoggedAt;
  final Value<int> rowid;
  const DaysCompanion({
    this.date = const Value.absent(),
    this.kind = const Value.absent(),
    this.time = const Value.absent(),
    this.muscles = const Value.absent(),
    this.source = const Value.absent(),
    this.mark = const Value.absent(),
    this.actualMuscles = const Value.absent(),
    this.markedAt = const Value.absent(),
    this.extraMuscles = const Value.absent(),
    this.extraLoggedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DaysCompanion.insert({
    required String date,
    required String kind,
    this.time = const Value.absent(),
    this.muscles = const Value.absent(),
    required String source,
    this.mark = const Value.absent(),
    this.actualMuscles = const Value.absent(),
    this.markedAt = const Value.absent(),
    this.extraMuscles = const Value.absent(),
    this.extraLoggedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       kind = Value(kind),
       source = Value(source);
  static Insertable<DayRow> custom({
    Expression<String>? date,
    Expression<String>? kind,
    Expression<String>? time,
    Expression<String>? muscles,
    Expression<String>? source,
    Expression<String>? mark,
    Expression<String>? actualMuscles,
    Expression<DateTime>? markedAt,
    Expression<String>? extraMuscles,
    Expression<DateTime>? extraLoggedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (kind != null) 'kind': kind,
      if (time != null) 'time': time,
      if (muscles != null) 'muscles': muscles,
      if (source != null) 'source': source,
      if (mark != null) 'mark': mark,
      if (actualMuscles != null) 'actual_muscles': actualMuscles,
      if (markedAt != null) 'marked_at': markedAt,
      if (extraMuscles != null) 'extra_muscles': extraMuscles,
      if (extraLoggedAt != null) 'extra_logged_at': extraLoggedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DaysCompanion copyWith({
    Value<String>? date,
    Value<String>? kind,
    Value<String?>? time,
    Value<String?>? muscles,
    Value<String>? source,
    Value<String?>? mark,
    Value<String?>? actualMuscles,
    Value<DateTime?>? markedAt,
    Value<String?>? extraMuscles,
    Value<DateTime?>? extraLoggedAt,
    Value<int>? rowid,
  }) {
    return DaysCompanion(
      date: date ?? this.date,
      kind: kind ?? this.kind,
      time: time ?? this.time,
      muscles: muscles ?? this.muscles,
      source: source ?? this.source,
      mark: mark ?? this.mark,
      actualMuscles: actualMuscles ?? this.actualMuscles,
      markedAt: markedAt ?? this.markedAt,
      extraMuscles: extraMuscles ?? this.extraMuscles,
      extraLoggedAt: extraLoggedAt ?? this.extraLoggedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (muscles.present) {
      map['muscles'] = Variable<String>(muscles.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (mark.present) {
      map['mark'] = Variable<String>(mark.value);
    }
    if (actualMuscles.present) {
      map['actual_muscles'] = Variable<String>(actualMuscles.value);
    }
    if (markedAt.present) {
      map['marked_at'] = Variable<DateTime>(markedAt.value);
    }
    if (extraMuscles.present) {
      map['extra_muscles'] = Variable<String>(extraMuscles.value);
    }
    if (extraLoggedAt.present) {
      map['extra_logged_at'] = Variable<DateTime>(extraLoggedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DaysCompanion(')
          ..write('date: $date, ')
          ..write('kind: $kind, ')
          ..write('time: $time, ')
          ..write('muscles: $muscles, ')
          ..write('source: $source, ')
          ..write('mark: $mark, ')
          ..write('actualMuscles: $actualMuscles, ')
          ..write('markedAt: $markedAt, ')
          ..write('extraMuscles: $extraMuscles, ')
          ..write('extraLoggedAt: $extraLoggedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MenusTable extends Menus with TableInfo<$MenusTable, MenuRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MenusTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetKcalMeta = const VerificationMeta(
    'targetKcal',
  );
  @override
  late final GeneratedColumn<int> targetKcal = GeneratedColumn<int>(
    'target_kcal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usedSafetyFloorMeta = const VerificationMeta(
    'usedSafetyFloor',
  );
  @override
  late final GeneratedColumn<bool> usedSafetyFloor = GeneratedColumn<bool>(
    'used_safety_floor',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("used_safety_floor" IN (0, 1))',
    ),
  );
  static const VerificationMeta _totalKcalMeta = const VerificationMeta(
    'totalKcal',
  );
  @override
  late final GeneratedColumn<int> totalKcal = GeneratedColumn<int>(
    'total_kcal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAttemptStatusMeta = const VerificationMeta(
    'lastAttemptStatus',
  );
  @override
  late final GeneratedColumn<String> lastAttemptStatus =
      GeneratedColumn<String>(
        'last_attempt_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    payload,
    targetKcal,
    usedSafetyFloor,
    totalKcal,
    lastAttemptStatus,
    lastErrorCode,
    generatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'menus';
  @override
  VerificationContext validateIntegrity(
    Insertable<MenuRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('target_kcal')) {
      context.handle(
        _targetKcalMeta,
        targetKcal.isAcceptableOrUnknown(data['target_kcal']!, _targetKcalMeta),
      );
    } else if (isInserting) {
      context.missing(_targetKcalMeta);
    }
    if (data.containsKey('used_safety_floor')) {
      context.handle(
        _usedSafetyFloorMeta,
        usedSafetyFloor.isAcceptableOrUnknown(
          data['used_safety_floor']!,
          _usedSafetyFloorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_usedSafetyFloorMeta);
    }
    if (data.containsKey('total_kcal')) {
      context.handle(
        _totalKcalMeta,
        totalKcal.isAcceptableOrUnknown(data['total_kcal']!, _totalKcalMeta),
      );
    }
    if (data.containsKey('last_attempt_status')) {
      context.handle(
        _lastAttemptStatusMeta,
        lastAttemptStatus.isAcceptableOrUnknown(
          data['last_attempt_status']!,
          _lastAttemptStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAttemptStatusMeta);
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  MenuRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MenuRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      targetKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_kcal'],
      )!,
      usedSafetyFloor: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}used_safety_floor'],
      )!,
      totalKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_kcal'],
      ),
      lastAttemptStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_attempt_status'],
      )!,
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      ),
    );
  }

  @override
  $MenusTable createAlias(String alias) {
    return $MenusTable(attachedDatabase, alias);
  }
}

class MenuRow extends DataClass implements Insertable<MenuRow> {
  final String date;

  /// Thực đơn (JSON theo 05 §6.9.4); null khi chưa có lần nào thành công.
  final String? payload;
  final int targetKcal;
  final bool usedSafetyFloor;
  final int? totalKcal;

  /// `generating` / `ready` / `failed`.
  final String lastAttemptStatus;
  final String? lastErrorCode;
  final DateTime? generatedAt;
  const MenuRow({
    required this.date,
    this.payload,
    required this.targetKcal,
    required this.usedSafetyFloor,
    this.totalKcal,
    required this.lastAttemptStatus,
    this.lastErrorCode,
    this.generatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['target_kcal'] = Variable<int>(targetKcal);
    map['used_safety_floor'] = Variable<bool>(usedSafetyFloor);
    if (!nullToAbsent || totalKcal != null) {
      map['total_kcal'] = Variable<int>(totalKcal);
    }
    map['last_attempt_status'] = Variable<String>(lastAttemptStatus);
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    if (!nullToAbsent || generatedAt != null) {
      map['generated_at'] = Variable<DateTime>(generatedAt);
    }
    return map;
  }

  MenusCompanion toCompanion(bool nullToAbsent) {
    return MenusCompanion(
      date: Value(date),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      targetKcal: Value(targetKcal),
      usedSafetyFloor: Value(usedSafetyFloor),
      totalKcal: totalKcal == null && nullToAbsent
          ? const Value.absent()
          : Value(totalKcal),
      lastAttemptStatus: Value(lastAttemptStatus),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      generatedAt: generatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(generatedAt),
    );
  }

  factory MenuRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MenuRow(
      date: serializer.fromJson<String>(json['date']),
      payload: serializer.fromJson<String?>(json['payload']),
      targetKcal: serializer.fromJson<int>(json['targetKcal']),
      usedSafetyFloor: serializer.fromJson<bool>(json['usedSafetyFloor']),
      totalKcal: serializer.fromJson<int?>(json['totalKcal']),
      lastAttemptStatus: serializer.fromJson<String>(json['lastAttemptStatus']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      generatedAt: serializer.fromJson<DateTime?>(json['generatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'payload': serializer.toJson<String?>(payload),
      'targetKcal': serializer.toJson<int>(targetKcal),
      'usedSafetyFloor': serializer.toJson<bool>(usedSafetyFloor),
      'totalKcal': serializer.toJson<int?>(totalKcal),
      'lastAttemptStatus': serializer.toJson<String>(lastAttemptStatus),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'generatedAt': serializer.toJson<DateTime?>(generatedAt),
    };
  }

  MenuRow copyWith({
    String? date,
    Value<String?> payload = const Value.absent(),
    int? targetKcal,
    bool? usedSafetyFloor,
    Value<int?> totalKcal = const Value.absent(),
    String? lastAttemptStatus,
    Value<String?> lastErrorCode = const Value.absent(),
    Value<DateTime?> generatedAt = const Value.absent(),
  }) => MenuRow(
    date: date ?? this.date,
    payload: payload.present ? payload.value : this.payload,
    targetKcal: targetKcal ?? this.targetKcal,
    usedSafetyFloor: usedSafetyFloor ?? this.usedSafetyFloor,
    totalKcal: totalKcal.present ? totalKcal.value : this.totalKcal,
    lastAttemptStatus: lastAttemptStatus ?? this.lastAttemptStatus,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    generatedAt: generatedAt.present ? generatedAt.value : this.generatedAt,
  );
  MenuRow copyWithCompanion(MenusCompanion data) {
    return MenuRow(
      date: data.date.present ? data.date.value : this.date,
      payload: data.payload.present ? data.payload.value : this.payload,
      targetKcal: data.targetKcal.present
          ? data.targetKcal.value
          : this.targetKcal,
      usedSafetyFloor: data.usedSafetyFloor.present
          ? data.usedSafetyFloor.value
          : this.usedSafetyFloor,
      totalKcal: data.totalKcal.present ? data.totalKcal.value : this.totalKcal,
      lastAttemptStatus: data.lastAttemptStatus.present
          ? data.lastAttemptStatus.value
          : this.lastAttemptStatus,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MenuRow(')
          ..write('date: $date, ')
          ..write('payload: $payload, ')
          ..write('targetKcal: $targetKcal, ')
          ..write('usedSafetyFloor: $usedSafetyFloor, ')
          ..write('totalKcal: $totalKcal, ')
          ..write('lastAttemptStatus: $lastAttemptStatus, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('generatedAt: $generatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    date,
    payload,
    targetKcal,
    usedSafetyFloor,
    totalKcal,
    lastAttemptStatus,
    lastErrorCode,
    generatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MenuRow &&
          other.date == this.date &&
          other.payload == this.payload &&
          other.targetKcal == this.targetKcal &&
          other.usedSafetyFloor == this.usedSafetyFloor &&
          other.totalKcal == this.totalKcal &&
          other.lastAttemptStatus == this.lastAttemptStatus &&
          other.lastErrorCode == this.lastErrorCode &&
          other.generatedAt == this.generatedAt);
}

class MenusCompanion extends UpdateCompanion<MenuRow> {
  final Value<String> date;
  final Value<String?> payload;
  final Value<int> targetKcal;
  final Value<bool> usedSafetyFloor;
  final Value<int?> totalKcal;
  final Value<String> lastAttemptStatus;
  final Value<String?> lastErrorCode;
  final Value<DateTime?> generatedAt;
  final Value<int> rowid;
  const MenusCompanion({
    this.date = const Value.absent(),
    this.payload = const Value.absent(),
    this.targetKcal = const Value.absent(),
    this.usedSafetyFloor = const Value.absent(),
    this.totalKcal = const Value.absent(),
    this.lastAttemptStatus = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MenusCompanion.insert({
    required String date,
    this.payload = const Value.absent(),
    required int targetKcal,
    required bool usedSafetyFloor,
    this.totalKcal = const Value.absent(),
    required String lastAttemptStatus,
    this.lastErrorCode = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       targetKcal = Value(targetKcal),
       usedSafetyFloor = Value(usedSafetyFloor),
       lastAttemptStatus = Value(lastAttemptStatus);
  static Insertable<MenuRow> custom({
    Expression<String>? date,
    Expression<String>? payload,
    Expression<int>? targetKcal,
    Expression<bool>? usedSafetyFloor,
    Expression<int>? totalKcal,
    Expression<String>? lastAttemptStatus,
    Expression<String>? lastErrorCode,
    Expression<DateTime>? generatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (payload != null) 'payload': payload,
      if (targetKcal != null) 'target_kcal': targetKcal,
      if (usedSafetyFloor != null) 'used_safety_floor': usedSafetyFloor,
      if (totalKcal != null) 'total_kcal': totalKcal,
      if (lastAttemptStatus != null) 'last_attempt_status': lastAttemptStatus,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MenusCompanion copyWith({
    Value<String>? date,
    Value<String?>? payload,
    Value<int>? targetKcal,
    Value<bool>? usedSafetyFloor,
    Value<int?>? totalKcal,
    Value<String>? lastAttemptStatus,
    Value<String?>? lastErrorCode,
    Value<DateTime?>? generatedAt,
    Value<int>? rowid,
  }) {
    return MenusCompanion(
      date: date ?? this.date,
      payload: payload ?? this.payload,
      targetKcal: targetKcal ?? this.targetKcal,
      usedSafetyFloor: usedSafetyFloor ?? this.usedSafetyFloor,
      totalKcal: totalKcal ?? this.totalKcal,
      lastAttemptStatus: lastAttemptStatus ?? this.lastAttemptStatus,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      generatedAt: generatedAt ?? this.generatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (targetKcal.present) {
      map['target_kcal'] = Variable<int>(targetKcal.value);
    }
    if (usedSafetyFloor.present) {
      map['used_safety_floor'] = Variable<bool>(usedSafetyFloor.value);
    }
    if (totalKcal.present) {
      map['total_kcal'] = Variable<int>(totalKcal.value);
    }
    if (lastAttemptStatus.present) {
      map['last_attempt_status'] = Variable<String>(lastAttemptStatus.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MenusCompanion(')
          ..write('date: $date, ')
          ..write('payload: $payload, ')
          ..write('targetKcal: $targetKcal, ')
          ..write('usedSafetyFloor: $usedSafetyFloor, ')
          ..write('totalKcal: $totalKcal, ')
          ..write('lastAttemptStatus: $lastAttemptStatus, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiDailyUsageTable extends AiDailyUsage
    with TableInfo<$AiDailyUsageTable, AiDailyUsageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiDailyUsageTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _successCountMeta = const VerificationMeta(
    'successCount',
  );
  @override
  late final GeneratedColumn<int> successCount = GeneratedColumn<int>(
    'success_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, successCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_daily_usage';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiDailyUsageRow> instance, {
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
    if (data.containsKey('success_count')) {
      context.handle(
        _successCountMeta,
        successCount.isAcceptableOrUnknown(
          data['success_count']!,
          _successCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_successCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AiDailyUsageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiDailyUsageRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      successCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}success_count'],
      )!,
    );
  }

  @override
  $AiDailyUsageTable createAlias(String alias) {
    return $AiDailyUsageTable(attachedDatabase, alias);
  }
}

class AiDailyUsageRow extends DataClass implements Insertable<AiDailyUsageRow> {
  final String key;
  final int successCount;
  const AiDailyUsageRow({required this.key, required this.successCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['success_count'] = Variable<int>(successCount);
    return map;
  }

  AiDailyUsageCompanion toCompanion(bool nullToAbsent) {
    return AiDailyUsageCompanion(
      key: Value(key),
      successCount: Value(successCount),
    );
  }

  factory AiDailyUsageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiDailyUsageRow(
      key: serializer.fromJson<String>(json['key']),
      successCount: serializer.fromJson<int>(json['successCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'successCount': serializer.toJson<int>(successCount),
    };
  }

  AiDailyUsageRow copyWith({String? key, int? successCount}) => AiDailyUsageRow(
    key: key ?? this.key,
    successCount: successCount ?? this.successCount,
  );
  AiDailyUsageRow copyWithCompanion(AiDailyUsageCompanion data) {
    return AiDailyUsageRow(
      key: data.key.present ? data.key.value : this.key,
      successCount: data.successCount.present
          ? data.successCount.value
          : this.successCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiDailyUsageRow(')
          ..write('key: $key, ')
          ..write('successCount: $successCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, successCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiDailyUsageRow &&
          other.key == this.key &&
          other.successCount == this.successCount);
}

class AiDailyUsageCompanion extends UpdateCompanion<AiDailyUsageRow> {
  final Value<String> key;
  final Value<int> successCount;
  final Value<int> rowid;
  const AiDailyUsageCompanion({
    this.key = const Value.absent(),
    this.successCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiDailyUsageCompanion.insert({
    required String key,
    required int successCount,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       successCount = Value(successCount);
  static Insertable<AiDailyUsageRow> custom({
    Expression<String>? key,
    Expression<int>? successCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (successCount != null) 'success_count': successCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiDailyUsageCompanion copyWith({
    Value<String>? key,
    Value<int>? successCount,
    Value<int>? rowid,
  }) {
    return AiDailyUsageCompanion(
      key: key ?? this.key,
      successCount: successCount ?? this.successCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (successCount.present) {
      map['success_count'] = Variable<int>(successCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiDailyUsageCompanion(')
          ..write('key: $key, ')
          ..write('successCount: $successCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DishImagesTable extends DishImages
    with TableInfo<$DishImagesTable, DishImageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DishImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameKeyMeta = const VerificationMeta(
    'nameKey',
  );
  @override
  late final GeneratedColumn<String> nameKey = GeneratedColumn<String>(
    'name_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedPathMeta = const VerificationMeta(
    'cachedPath',
  );
  @override
  late final GeneratedColumn<String> cachedPath = GeneratedColumn<String>(
    'cached_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    nameKey,
    id,
    displayName,
    width,
    height,
    bytes,
    createdAt,
    cachedPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dish_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<DishImageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name_key')) {
      context.handle(
        _nameKeyMeta,
        nameKey.isAcceptableOrUnknown(data['name_key']!, _nameKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_nameKeyMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('cached_path')) {
      context.handle(
        _cachedPathMeta,
        cachedPath.isAcceptableOrUnknown(data['cached_path']!, _cachedPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {nameKey};
  @override
  DishImageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DishImageRow(
      nameKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_key'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      cachedPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cached_path'],
      ),
    );
  }

  @override
  $DishImagesTable createAlias(String alias) {
    return $DishImagesTable(attachedDatabase, alias);
  }
}

class DishImageRow extends DataClass implements Insertable<DishImageRow> {
  final String nameKey;
  final String id;
  final String displayName;
  final int width;
  final int height;
  final int bytes;
  final DateTime createdAt;
  final String? cachedPath;
  const DishImageRow({
    required this.nameKey,
    required this.id,
    required this.displayName,
    required this.width,
    required this.height,
    required this.bytes,
    required this.createdAt,
    this.cachedPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name_key'] = Variable<String>(nameKey);
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['bytes'] = Variable<int>(bytes);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || cachedPath != null) {
      map['cached_path'] = Variable<String>(cachedPath);
    }
    return map;
  }

  DishImagesCompanion toCompanion(bool nullToAbsent) {
    return DishImagesCompanion(
      nameKey: Value(nameKey),
      id: Value(id),
      displayName: Value(displayName),
      width: Value(width),
      height: Value(height),
      bytes: Value(bytes),
      createdAt: Value(createdAt),
      cachedPath: cachedPath == null && nullToAbsent
          ? const Value.absent()
          : Value(cachedPath),
    );
  }

  factory DishImageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DishImageRow(
      nameKey: serializer.fromJson<String>(json['nameKey']),
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      bytes: serializer.fromJson<int>(json['bytes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      cachedPath: serializer.fromJson<String?>(json['cachedPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'nameKey': serializer.toJson<String>(nameKey),
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'bytes': serializer.toJson<int>(bytes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'cachedPath': serializer.toJson<String?>(cachedPath),
    };
  }

  DishImageRow copyWith({
    String? nameKey,
    String? id,
    String? displayName,
    int? width,
    int? height,
    int? bytes,
    DateTime? createdAt,
    Value<String?> cachedPath = const Value.absent(),
  }) => DishImageRow(
    nameKey: nameKey ?? this.nameKey,
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    width: width ?? this.width,
    height: height ?? this.height,
    bytes: bytes ?? this.bytes,
    createdAt: createdAt ?? this.createdAt,
    cachedPath: cachedPath.present ? cachedPath.value : this.cachedPath,
  );
  DishImageRow copyWithCompanion(DishImagesCompanion data) {
    return DishImageRow(
      nameKey: data.nameKey.present ? data.nameKey.value : this.nameKey,
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      cachedPath: data.cachedPath.present
          ? data.cachedPath.value
          : this.cachedPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DishImageRow(')
          ..write('nameKey: $nameKey, ')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('bytes: $bytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('cachedPath: $cachedPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    nameKey,
    id,
    displayName,
    width,
    height,
    bytes,
    createdAt,
    cachedPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DishImageRow &&
          other.nameKey == this.nameKey &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.width == this.width &&
          other.height == this.height &&
          other.bytes == this.bytes &&
          other.createdAt == this.createdAt &&
          other.cachedPath == this.cachedPath);
}

class DishImagesCompanion extends UpdateCompanion<DishImageRow> {
  final Value<String> nameKey;
  final Value<String> id;
  final Value<String> displayName;
  final Value<int> width;
  final Value<int> height;
  final Value<int> bytes;
  final Value<DateTime> createdAt;
  final Value<String?> cachedPath;
  final Value<int> rowid;
  const DishImagesCompanion({
    this.nameKey = const Value.absent(),
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.bytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.cachedPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DishImagesCompanion.insert({
    required String nameKey,
    required String id,
    required String displayName,
    required int width,
    required int height,
    required int bytes,
    required DateTime createdAt,
    this.cachedPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : nameKey = Value(nameKey),
       id = Value(id),
       displayName = Value(displayName),
       width = Value(width),
       height = Value(height),
       bytes = Value(bytes),
       createdAt = Value(createdAt);
  static Insertable<DishImageRow> custom({
    Expression<String>? nameKey,
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? bytes,
    Expression<DateTime>? createdAt,
    Expression<String>? cachedPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (nameKey != null) 'name_key': nameKey,
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (bytes != null) 'bytes': bytes,
      if (createdAt != null) 'created_at': createdAt,
      if (cachedPath != null) 'cached_path': cachedPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DishImagesCompanion copyWith({
    Value<String>? nameKey,
    Value<String>? id,
    Value<String>? displayName,
    Value<int>? width,
    Value<int>? height,
    Value<int>? bytes,
    Value<DateTime>? createdAt,
    Value<String?>? cachedPath,
    Value<int>? rowid,
  }) {
    return DishImagesCompanion(
      nameKey: nameKey ?? this.nameKey,
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      width: width ?? this.width,
      height: height ?? this.height,
      bytes: bytes ?? this.bytes,
      createdAt: createdAt ?? this.createdAt,
      cachedPath: cachedPath ?? this.cachedPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (nameKey.present) {
      map['name_key'] = Variable<String>(nameKey.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (cachedPath.present) {
      map['cached_path'] = Variable<String>(cachedPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DishImagesCompanion(')
          ..write('nameKey: $nameKey, ')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('bytes: $bytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('cachedPath: $cachedPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MuscleRegionsTable extends MuscleRegions
    with TableInfo<$MuscleRegionsTable, MuscleRegionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MuscleRegionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _muscleGroupMeta = const VerificationMeta(
    'muscleGroup',
  );
  @override
  late final GeneratedColumn<String> muscleGroup = GeneratedColumn<String>(
    'muscle_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viewMeta = const VerificationMeta('view');
  @override
  late final GeneratedColumn<String> view = GeneratedColumn<String>(
    'view',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, muscleGroup, view, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'muscle_regions';
  @override
  VerificationContext validateIntegrity(
    Insertable<MuscleRegionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('muscle_group')) {
      context.handle(
        _muscleGroupMeta,
        muscleGroup.isAcceptableOrUnknown(
          data['muscle_group']!,
          _muscleGroupMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_muscleGroupMeta);
    }
    if (data.containsKey('view')) {
      context.handle(
        _viewMeta,
        view.isAcceptableOrUnknown(data['view']!, _viewMeta),
      );
    } else if (isInserting) {
      context.missing(_viewMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MuscleRegionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MuscleRegionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      muscleGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}muscle_group'],
      )!,
      view: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}view'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $MuscleRegionsTable createAlias(String alias) {
    return $MuscleRegionsTable(attachedDatabase, alias);
  }
}

class MuscleRegionRow extends DataClass implements Insertable<MuscleRegionRow> {
  final String id;
  final String muscleGroup;

  /// `front` / `back`.
  final String view;
  final int sortOrder;
  const MuscleRegionRow({
    required this.id,
    required this.muscleGroup,
    required this.view,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['muscle_group'] = Variable<String>(muscleGroup);
    map['view'] = Variable<String>(view);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  MuscleRegionsCompanion toCompanion(bool nullToAbsent) {
    return MuscleRegionsCompanion(
      id: Value(id),
      muscleGroup: Value(muscleGroup),
      view: Value(view),
      sortOrder: Value(sortOrder),
    );
  }

  factory MuscleRegionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MuscleRegionRow(
      id: serializer.fromJson<String>(json['id']),
      muscleGroup: serializer.fromJson<String>(json['muscleGroup']),
      view: serializer.fromJson<String>(json['view']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'muscleGroup': serializer.toJson<String>(muscleGroup),
      'view': serializer.toJson<String>(view),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  MuscleRegionRow copyWith({
    String? id,
    String? muscleGroup,
    String? view,
    int? sortOrder,
  }) => MuscleRegionRow(
    id: id ?? this.id,
    muscleGroup: muscleGroup ?? this.muscleGroup,
    view: view ?? this.view,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  MuscleRegionRow copyWithCompanion(MuscleRegionsCompanion data) {
    return MuscleRegionRow(
      id: data.id.present ? data.id.value : this.id,
      muscleGroup: data.muscleGroup.present
          ? data.muscleGroup.value
          : this.muscleGroup,
      view: data.view.present ? data.view.value : this.view,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MuscleRegionRow(')
          ..write('id: $id, ')
          ..write('muscleGroup: $muscleGroup, ')
          ..write('view: $view, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, muscleGroup, view, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MuscleRegionRow &&
          other.id == this.id &&
          other.muscleGroup == this.muscleGroup &&
          other.view == this.view &&
          other.sortOrder == this.sortOrder);
}

class MuscleRegionsCompanion extends UpdateCompanion<MuscleRegionRow> {
  final Value<String> id;
  final Value<String> muscleGroup;
  final Value<String> view;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const MuscleRegionsCompanion({
    this.id = const Value.absent(),
    this.muscleGroup = const Value.absent(),
    this.view = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MuscleRegionsCompanion.insert({
    required String id,
    required String muscleGroup,
    required String view,
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       muscleGroup = Value(muscleGroup),
       view = Value(view),
       sortOrder = Value(sortOrder);
  static Insertable<MuscleRegionRow> custom({
    Expression<String>? id,
    Expression<String>? muscleGroup,
    Expression<String>? view,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (muscleGroup != null) 'muscle_group': muscleGroup,
      if (view != null) 'view': view,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MuscleRegionsCompanion copyWith({
    Value<String>? id,
    Value<String>? muscleGroup,
    Value<String>? view,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return MuscleRegionsCompanion(
      id: id ?? this.id,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      view: view ?? this.view,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (muscleGroup.present) {
      map['muscle_group'] = Variable<String>(muscleGroup.value);
    }
    if (view.present) {
      map['view'] = Variable<String>(view.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MuscleRegionsCompanion(')
          ..write('id: $id, ')
          ..write('muscleGroup: $muscleGroup, ')
          ..write('view: $view, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, ExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _muscleGroupMeta = const VerificationMeta(
    'muscleGroup',
  );
  @override
  late final GeneratedColumn<String> muscleGroup = GeneratedColumn<String>(
    'muscle_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _muscleRegionMeta = const VerificationMeta(
    'muscleRegion',
  );
  @override
  late final GeneratedColumn<String> muscleRegion = GeneratedColumn<String>(
    'muscle_region',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _equipmentMeta = const VerificationMeta(
    'equipment',
  );
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
    'equipment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _logsWeightMeta = const VerificationMeta(
    'logsWeight',
  );
  @override
  late final GeneratedColumn<bool> logsWeight = GeneratedColumn<bool>(
    'logs_weight',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("logs_weight" IN (0, 1))',
    ),
  );
  static const VerificationMeta _nameViMeta = const VerificationMeta('nameVi');
  @override
  late final GeneratedColumn<String> nameVi = GeneratedColumn<String>(
    'name_vi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameEnMeta = const VerificationMeta('nameEn');
  @override
  late final GeneratedColumn<String> nameEn = GeneratedColumn<String>(
    'name_en',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _youtubeVideoIdMeta = const VerificationMeta(
    'youtubeVideoId',
  );
  @override
  late final GeneratedColumn<String> youtubeVideoId = GeneratedColumn<String>(
    'youtube_video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoChannelMeta = const VerificationMeta(
    'videoChannel',
  );
  @override
  late final GeneratedColumn<String> videoChannel = GeneratedColumn<String>(
    'video_channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoDurationSMeta = const VerificationMeta(
    'videoDurationS',
  );
  @override
  late final GeneratedColumn<int> videoDurationS = GeneratedColumn<int>(
    'video_duration_s',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoAvailableMeta = const VerificationMeta(
    'videoAvailable',
  );
  @override
  late final GeneratedColumn<bool> videoAvailable = GeneratedColumn<bool>(
    'video_available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("video_available" IN (0, 1))',
    ),
  );
  static const VerificationMeta _videoCheckedAtMeta = const VerificationMeta(
    'videoCheckedAt',
  );
  @override
  late final GeneratedColumn<DateTime> videoCheckedAt =
      GeneratedColumn<DateTime>(
        'video_checked_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _videoUnavailableReasonMeta =
      const VerificationMeta('videoUnavailableReason');
  @override
  late final GeneratedColumn<String> videoUnavailableReason =
      GeneratedColumn<String>(
        'video_unavailable_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _guideStepsMeta = const VerificationMeta(
    'guideSteps',
  );
  @override
  late final GeneratedColumn<String> guideSteps = GeneratedColumn<String>(
    'guide_steps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _guideSafetyMeta = const VerificationMeta(
    'guideSafety',
  );
  @override
  late final GeneratedColumn<String> guideSafety = GeneratedColumn<String>(
    'guide_safety',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _approvedAtMeta = const VerificationMeta(
    'approvedAt',
  );
  @override
  late final GeneratedColumn<String> approvedAt = GeneratedColumn<String>(
    'approved_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    muscleGroup,
    muscleRegion,
    equipment,
    logsWeight,
    nameVi,
    nameEn,
    youtubeVideoId,
    videoChannel,
    videoDurationS,
    videoAvailable,
    videoCheckedAt,
    videoUnavailableReason,
    guideSteps,
    guideSafety,
    approvedAt,
    sortOrder,
    active,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('muscle_group')) {
      context.handle(
        _muscleGroupMeta,
        muscleGroup.isAcceptableOrUnknown(
          data['muscle_group']!,
          _muscleGroupMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_muscleGroupMeta);
    }
    if (data.containsKey('muscle_region')) {
      context.handle(
        _muscleRegionMeta,
        muscleRegion.isAcceptableOrUnknown(
          data['muscle_region']!,
          _muscleRegionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_muscleRegionMeta);
    }
    if (data.containsKey('equipment')) {
      context.handle(
        _equipmentMeta,
        equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta),
      );
    } else if (isInserting) {
      context.missing(_equipmentMeta);
    }
    if (data.containsKey('logs_weight')) {
      context.handle(
        _logsWeightMeta,
        logsWeight.isAcceptableOrUnknown(data['logs_weight']!, _logsWeightMeta),
      );
    } else if (isInserting) {
      context.missing(_logsWeightMeta);
    }
    if (data.containsKey('name_vi')) {
      context.handle(
        _nameViMeta,
        nameVi.isAcceptableOrUnknown(data['name_vi']!, _nameViMeta),
      );
    } else if (isInserting) {
      context.missing(_nameViMeta);
    }
    if (data.containsKey('name_en')) {
      context.handle(
        _nameEnMeta,
        nameEn.isAcceptableOrUnknown(data['name_en']!, _nameEnMeta),
      );
    }
    if (data.containsKey('youtube_video_id')) {
      context.handle(
        _youtubeVideoIdMeta,
        youtubeVideoId.isAcceptableOrUnknown(
          data['youtube_video_id']!,
          _youtubeVideoIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_youtubeVideoIdMeta);
    }
    if (data.containsKey('video_channel')) {
      context.handle(
        _videoChannelMeta,
        videoChannel.isAcceptableOrUnknown(
          data['video_channel']!,
          _videoChannelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_videoChannelMeta);
    }
    if (data.containsKey('video_duration_s')) {
      context.handle(
        _videoDurationSMeta,
        videoDurationS.isAcceptableOrUnknown(
          data['video_duration_s']!,
          _videoDurationSMeta,
        ),
      );
    }
    if (data.containsKey('video_available')) {
      context.handle(
        _videoAvailableMeta,
        videoAvailable.isAcceptableOrUnknown(
          data['video_available']!,
          _videoAvailableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_videoAvailableMeta);
    }
    if (data.containsKey('video_checked_at')) {
      context.handle(
        _videoCheckedAtMeta,
        videoCheckedAt.isAcceptableOrUnknown(
          data['video_checked_at']!,
          _videoCheckedAtMeta,
        ),
      );
    }
    if (data.containsKey('video_unavailable_reason')) {
      context.handle(
        _videoUnavailableReasonMeta,
        videoUnavailableReason.isAcceptableOrUnknown(
          data['video_unavailable_reason']!,
          _videoUnavailableReasonMeta,
        ),
      );
    }
    if (data.containsKey('guide_steps')) {
      context.handle(
        _guideStepsMeta,
        guideSteps.isAcceptableOrUnknown(data['guide_steps']!, _guideStepsMeta),
      );
    } else if (isInserting) {
      context.missing(_guideStepsMeta);
    }
    if (data.containsKey('guide_safety')) {
      context.handle(
        _guideSafetyMeta,
        guideSafety.isAcceptableOrUnknown(
          data['guide_safety']!,
          _guideSafetyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_guideSafetyMeta);
    }
    if (data.containsKey('approved_at')) {
      context.handle(
        _approvedAtMeta,
        approvedAt.isAcceptableOrUnknown(data['approved_at']!, _approvedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_approvedAtMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    } else if (isInserting) {
      context.missing(_activeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      muscleGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}muscle_group'],
      )!,
      muscleRegion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}muscle_region'],
      )!,
      equipment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment'],
      )!,
      logsWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}logs_weight'],
      )!,
      nameVi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_vi'],
      )!,
      nameEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_en'],
      ),
      youtubeVideoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}youtube_video_id'],
      )!,
      videoChannel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_channel'],
      )!,
      videoDurationS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}video_duration_s'],
      ),
      videoAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}video_available'],
      )!,
      videoCheckedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}video_checked_at'],
      ),
      videoUnavailableReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_unavailable_reason'],
      ),
      guideSteps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guide_steps'],
      )!,
      guideSafety: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guide_safety'],
      )!,
      approvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approved_at'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class ExerciseRow extends DataClass implements Insertable<ExerciseRow> {
  final String id;
  final String muscleGroup;
  final String muscleRegion;

  /// `machine` / `free_weight` / `bodyweight`.
  final String equipment;
  final bool logsWeight;
  final String nameVi;
  final String? nameEn;
  final String youtubeVideoId;
  final String videoChannel;
  final int? videoDurationS;
  final bool videoAvailable;
  final DateTime? videoCheckedAt;
  final String? videoUnavailableReason;

  /// Danh sách chuỗi dạng JSON.
  final String guideSteps;
  final String guideSafety;

  /// `YYYY-MM-DD`.
  final String approvedAt;
  final int sortOrder;
  final bool active;
  const ExerciseRow({
    required this.id,
    required this.muscleGroup,
    required this.muscleRegion,
    required this.equipment,
    required this.logsWeight,
    required this.nameVi,
    this.nameEn,
    required this.youtubeVideoId,
    required this.videoChannel,
    this.videoDurationS,
    required this.videoAvailable,
    this.videoCheckedAt,
    this.videoUnavailableReason,
    required this.guideSteps,
    required this.guideSafety,
    required this.approvedAt,
    required this.sortOrder,
    required this.active,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['muscle_group'] = Variable<String>(muscleGroup);
    map['muscle_region'] = Variable<String>(muscleRegion);
    map['equipment'] = Variable<String>(equipment);
    map['logs_weight'] = Variable<bool>(logsWeight);
    map['name_vi'] = Variable<String>(nameVi);
    if (!nullToAbsent || nameEn != null) {
      map['name_en'] = Variable<String>(nameEn);
    }
    map['youtube_video_id'] = Variable<String>(youtubeVideoId);
    map['video_channel'] = Variable<String>(videoChannel);
    if (!nullToAbsent || videoDurationS != null) {
      map['video_duration_s'] = Variable<int>(videoDurationS);
    }
    map['video_available'] = Variable<bool>(videoAvailable);
    if (!nullToAbsent || videoCheckedAt != null) {
      map['video_checked_at'] = Variable<DateTime>(videoCheckedAt);
    }
    if (!nullToAbsent || videoUnavailableReason != null) {
      map['video_unavailable_reason'] = Variable<String>(
        videoUnavailableReason,
      );
    }
    map['guide_steps'] = Variable<String>(guideSteps);
    map['guide_safety'] = Variable<String>(guideSafety);
    map['approved_at'] = Variable<String>(approvedAt);
    map['sort_order'] = Variable<int>(sortOrder);
    map['active'] = Variable<bool>(active);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      muscleGroup: Value(muscleGroup),
      muscleRegion: Value(muscleRegion),
      equipment: Value(equipment),
      logsWeight: Value(logsWeight),
      nameVi: Value(nameVi),
      nameEn: nameEn == null && nullToAbsent
          ? const Value.absent()
          : Value(nameEn),
      youtubeVideoId: Value(youtubeVideoId),
      videoChannel: Value(videoChannel),
      videoDurationS: videoDurationS == null && nullToAbsent
          ? const Value.absent()
          : Value(videoDurationS),
      videoAvailable: Value(videoAvailable),
      videoCheckedAt: videoCheckedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(videoCheckedAt),
      videoUnavailableReason: videoUnavailableReason == null && nullToAbsent
          ? const Value.absent()
          : Value(videoUnavailableReason),
      guideSteps: Value(guideSteps),
      guideSafety: Value(guideSafety),
      approvedAt: Value(approvedAt),
      sortOrder: Value(sortOrder),
      active: Value(active),
    );
  }

  factory ExerciseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseRow(
      id: serializer.fromJson<String>(json['id']),
      muscleGroup: serializer.fromJson<String>(json['muscleGroup']),
      muscleRegion: serializer.fromJson<String>(json['muscleRegion']),
      equipment: serializer.fromJson<String>(json['equipment']),
      logsWeight: serializer.fromJson<bool>(json['logsWeight']),
      nameVi: serializer.fromJson<String>(json['nameVi']),
      nameEn: serializer.fromJson<String?>(json['nameEn']),
      youtubeVideoId: serializer.fromJson<String>(json['youtubeVideoId']),
      videoChannel: serializer.fromJson<String>(json['videoChannel']),
      videoDurationS: serializer.fromJson<int?>(json['videoDurationS']),
      videoAvailable: serializer.fromJson<bool>(json['videoAvailable']),
      videoCheckedAt: serializer.fromJson<DateTime?>(json['videoCheckedAt']),
      videoUnavailableReason: serializer.fromJson<String?>(
        json['videoUnavailableReason'],
      ),
      guideSteps: serializer.fromJson<String>(json['guideSteps']),
      guideSafety: serializer.fromJson<String>(json['guideSafety']),
      approvedAt: serializer.fromJson<String>(json['approvedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'muscleGroup': serializer.toJson<String>(muscleGroup),
      'muscleRegion': serializer.toJson<String>(muscleRegion),
      'equipment': serializer.toJson<String>(equipment),
      'logsWeight': serializer.toJson<bool>(logsWeight),
      'nameVi': serializer.toJson<String>(nameVi),
      'nameEn': serializer.toJson<String?>(nameEn),
      'youtubeVideoId': serializer.toJson<String>(youtubeVideoId),
      'videoChannel': serializer.toJson<String>(videoChannel),
      'videoDurationS': serializer.toJson<int?>(videoDurationS),
      'videoAvailable': serializer.toJson<bool>(videoAvailable),
      'videoCheckedAt': serializer.toJson<DateTime?>(videoCheckedAt),
      'videoUnavailableReason': serializer.toJson<String?>(
        videoUnavailableReason,
      ),
      'guideSteps': serializer.toJson<String>(guideSteps),
      'guideSafety': serializer.toJson<String>(guideSafety),
      'approvedAt': serializer.toJson<String>(approvedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'active': serializer.toJson<bool>(active),
    };
  }

  ExerciseRow copyWith({
    String? id,
    String? muscleGroup,
    String? muscleRegion,
    String? equipment,
    bool? logsWeight,
    String? nameVi,
    Value<String?> nameEn = const Value.absent(),
    String? youtubeVideoId,
    String? videoChannel,
    Value<int?> videoDurationS = const Value.absent(),
    bool? videoAvailable,
    Value<DateTime?> videoCheckedAt = const Value.absent(),
    Value<String?> videoUnavailableReason = const Value.absent(),
    String? guideSteps,
    String? guideSafety,
    String? approvedAt,
    int? sortOrder,
    bool? active,
  }) => ExerciseRow(
    id: id ?? this.id,
    muscleGroup: muscleGroup ?? this.muscleGroup,
    muscleRegion: muscleRegion ?? this.muscleRegion,
    equipment: equipment ?? this.equipment,
    logsWeight: logsWeight ?? this.logsWeight,
    nameVi: nameVi ?? this.nameVi,
    nameEn: nameEn.present ? nameEn.value : this.nameEn,
    youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
    videoChannel: videoChannel ?? this.videoChannel,
    videoDurationS: videoDurationS.present
        ? videoDurationS.value
        : this.videoDurationS,
    videoAvailable: videoAvailable ?? this.videoAvailable,
    videoCheckedAt: videoCheckedAt.present
        ? videoCheckedAt.value
        : this.videoCheckedAt,
    videoUnavailableReason: videoUnavailableReason.present
        ? videoUnavailableReason.value
        : this.videoUnavailableReason,
    guideSteps: guideSteps ?? this.guideSteps,
    guideSafety: guideSafety ?? this.guideSafety,
    approvedAt: approvedAt ?? this.approvedAt,
    sortOrder: sortOrder ?? this.sortOrder,
    active: active ?? this.active,
  );
  ExerciseRow copyWithCompanion(ExercisesCompanion data) {
    return ExerciseRow(
      id: data.id.present ? data.id.value : this.id,
      muscleGroup: data.muscleGroup.present
          ? data.muscleGroup.value
          : this.muscleGroup,
      muscleRegion: data.muscleRegion.present
          ? data.muscleRegion.value
          : this.muscleRegion,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      logsWeight: data.logsWeight.present
          ? data.logsWeight.value
          : this.logsWeight,
      nameVi: data.nameVi.present ? data.nameVi.value : this.nameVi,
      nameEn: data.nameEn.present ? data.nameEn.value : this.nameEn,
      youtubeVideoId: data.youtubeVideoId.present
          ? data.youtubeVideoId.value
          : this.youtubeVideoId,
      videoChannel: data.videoChannel.present
          ? data.videoChannel.value
          : this.videoChannel,
      videoDurationS: data.videoDurationS.present
          ? data.videoDurationS.value
          : this.videoDurationS,
      videoAvailable: data.videoAvailable.present
          ? data.videoAvailable.value
          : this.videoAvailable,
      videoCheckedAt: data.videoCheckedAt.present
          ? data.videoCheckedAt.value
          : this.videoCheckedAt,
      videoUnavailableReason: data.videoUnavailableReason.present
          ? data.videoUnavailableReason.value
          : this.videoUnavailableReason,
      guideSteps: data.guideSteps.present
          ? data.guideSteps.value
          : this.guideSteps,
      guideSafety: data.guideSafety.present
          ? data.guideSafety.value
          : this.guideSafety,
      approvedAt: data.approvedAt.present
          ? data.approvedAt.value
          : this.approvedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseRow(')
          ..write('id: $id, ')
          ..write('muscleGroup: $muscleGroup, ')
          ..write('muscleRegion: $muscleRegion, ')
          ..write('equipment: $equipment, ')
          ..write('logsWeight: $logsWeight, ')
          ..write('nameVi: $nameVi, ')
          ..write('nameEn: $nameEn, ')
          ..write('youtubeVideoId: $youtubeVideoId, ')
          ..write('videoChannel: $videoChannel, ')
          ..write('videoDurationS: $videoDurationS, ')
          ..write('videoAvailable: $videoAvailable, ')
          ..write('videoCheckedAt: $videoCheckedAt, ')
          ..write('videoUnavailableReason: $videoUnavailableReason, ')
          ..write('guideSteps: $guideSteps, ')
          ..write('guideSafety: $guideSafety, ')
          ..write('approvedAt: $approvedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    muscleGroup,
    muscleRegion,
    equipment,
    logsWeight,
    nameVi,
    nameEn,
    youtubeVideoId,
    videoChannel,
    videoDurationS,
    videoAvailable,
    videoCheckedAt,
    videoUnavailableReason,
    guideSteps,
    guideSafety,
    approvedAt,
    sortOrder,
    active,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseRow &&
          other.id == this.id &&
          other.muscleGroup == this.muscleGroup &&
          other.muscleRegion == this.muscleRegion &&
          other.equipment == this.equipment &&
          other.logsWeight == this.logsWeight &&
          other.nameVi == this.nameVi &&
          other.nameEn == this.nameEn &&
          other.youtubeVideoId == this.youtubeVideoId &&
          other.videoChannel == this.videoChannel &&
          other.videoDurationS == this.videoDurationS &&
          other.videoAvailable == this.videoAvailable &&
          other.videoCheckedAt == this.videoCheckedAt &&
          other.videoUnavailableReason == this.videoUnavailableReason &&
          other.guideSteps == this.guideSteps &&
          other.guideSafety == this.guideSafety &&
          other.approvedAt == this.approvedAt &&
          other.sortOrder == this.sortOrder &&
          other.active == this.active);
}

class ExercisesCompanion extends UpdateCompanion<ExerciseRow> {
  final Value<String> id;
  final Value<String> muscleGroup;
  final Value<String> muscleRegion;
  final Value<String> equipment;
  final Value<bool> logsWeight;
  final Value<String> nameVi;
  final Value<String?> nameEn;
  final Value<String> youtubeVideoId;
  final Value<String> videoChannel;
  final Value<int?> videoDurationS;
  final Value<bool> videoAvailable;
  final Value<DateTime?> videoCheckedAt;
  final Value<String?> videoUnavailableReason;
  final Value<String> guideSteps;
  final Value<String> guideSafety;
  final Value<String> approvedAt;
  final Value<int> sortOrder;
  final Value<bool> active;
  final Value<int> rowid;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.muscleGroup = const Value.absent(),
    this.muscleRegion = const Value.absent(),
    this.equipment = const Value.absent(),
    this.logsWeight = const Value.absent(),
    this.nameVi = const Value.absent(),
    this.nameEn = const Value.absent(),
    this.youtubeVideoId = const Value.absent(),
    this.videoChannel = const Value.absent(),
    this.videoDurationS = const Value.absent(),
    this.videoAvailable = const Value.absent(),
    this.videoCheckedAt = const Value.absent(),
    this.videoUnavailableReason = const Value.absent(),
    this.guideSteps = const Value.absent(),
    this.guideSafety = const Value.absent(),
    this.approvedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExercisesCompanion.insert({
    required String id,
    required String muscleGroup,
    required String muscleRegion,
    required String equipment,
    required bool logsWeight,
    required String nameVi,
    this.nameEn = const Value.absent(),
    required String youtubeVideoId,
    required String videoChannel,
    this.videoDurationS = const Value.absent(),
    required bool videoAvailable,
    this.videoCheckedAt = const Value.absent(),
    this.videoUnavailableReason = const Value.absent(),
    required String guideSteps,
    required String guideSafety,
    required String approvedAt,
    required int sortOrder,
    required bool active,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       muscleGroup = Value(muscleGroup),
       muscleRegion = Value(muscleRegion),
       equipment = Value(equipment),
       logsWeight = Value(logsWeight),
       nameVi = Value(nameVi),
       youtubeVideoId = Value(youtubeVideoId),
       videoChannel = Value(videoChannel),
       videoAvailable = Value(videoAvailable),
       guideSteps = Value(guideSteps),
       guideSafety = Value(guideSafety),
       approvedAt = Value(approvedAt),
       sortOrder = Value(sortOrder),
       active = Value(active);
  static Insertable<ExerciseRow> custom({
    Expression<String>? id,
    Expression<String>? muscleGroup,
    Expression<String>? muscleRegion,
    Expression<String>? equipment,
    Expression<bool>? logsWeight,
    Expression<String>? nameVi,
    Expression<String>? nameEn,
    Expression<String>? youtubeVideoId,
    Expression<String>? videoChannel,
    Expression<int>? videoDurationS,
    Expression<bool>? videoAvailable,
    Expression<DateTime>? videoCheckedAt,
    Expression<String>? videoUnavailableReason,
    Expression<String>? guideSteps,
    Expression<String>? guideSafety,
    Expression<String>? approvedAt,
    Expression<int>? sortOrder,
    Expression<bool>? active,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (muscleGroup != null) 'muscle_group': muscleGroup,
      if (muscleRegion != null) 'muscle_region': muscleRegion,
      if (equipment != null) 'equipment': equipment,
      if (logsWeight != null) 'logs_weight': logsWeight,
      if (nameVi != null) 'name_vi': nameVi,
      if (nameEn != null) 'name_en': nameEn,
      if (youtubeVideoId != null) 'youtube_video_id': youtubeVideoId,
      if (videoChannel != null) 'video_channel': videoChannel,
      if (videoDurationS != null) 'video_duration_s': videoDurationS,
      if (videoAvailable != null) 'video_available': videoAvailable,
      if (videoCheckedAt != null) 'video_checked_at': videoCheckedAt,
      if (videoUnavailableReason != null)
        'video_unavailable_reason': videoUnavailableReason,
      if (guideSteps != null) 'guide_steps': guideSteps,
      if (guideSafety != null) 'guide_safety': guideSafety,
      if (approvedAt != null) 'approved_at': approvedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (active != null) 'active': active,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExercisesCompanion copyWith({
    Value<String>? id,
    Value<String>? muscleGroup,
    Value<String>? muscleRegion,
    Value<String>? equipment,
    Value<bool>? logsWeight,
    Value<String>? nameVi,
    Value<String?>? nameEn,
    Value<String>? youtubeVideoId,
    Value<String>? videoChannel,
    Value<int?>? videoDurationS,
    Value<bool>? videoAvailable,
    Value<DateTime?>? videoCheckedAt,
    Value<String?>? videoUnavailableReason,
    Value<String>? guideSteps,
    Value<String>? guideSafety,
    Value<String>? approvedAt,
    Value<int>? sortOrder,
    Value<bool>? active,
    Value<int>? rowid,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      muscleRegion: muscleRegion ?? this.muscleRegion,
      equipment: equipment ?? this.equipment,
      logsWeight: logsWeight ?? this.logsWeight,
      nameVi: nameVi ?? this.nameVi,
      nameEn: nameEn ?? this.nameEn,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      videoChannel: videoChannel ?? this.videoChannel,
      videoDurationS: videoDurationS ?? this.videoDurationS,
      videoAvailable: videoAvailable ?? this.videoAvailable,
      videoCheckedAt: videoCheckedAt ?? this.videoCheckedAt,
      videoUnavailableReason:
          videoUnavailableReason ?? this.videoUnavailableReason,
      guideSteps: guideSteps ?? this.guideSteps,
      guideSafety: guideSafety ?? this.guideSafety,
      approvedAt: approvedAt ?? this.approvedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      active: active ?? this.active,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (muscleGroup.present) {
      map['muscle_group'] = Variable<String>(muscleGroup.value);
    }
    if (muscleRegion.present) {
      map['muscle_region'] = Variable<String>(muscleRegion.value);
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (logsWeight.present) {
      map['logs_weight'] = Variable<bool>(logsWeight.value);
    }
    if (nameVi.present) {
      map['name_vi'] = Variable<String>(nameVi.value);
    }
    if (nameEn.present) {
      map['name_en'] = Variable<String>(nameEn.value);
    }
    if (youtubeVideoId.present) {
      map['youtube_video_id'] = Variable<String>(youtubeVideoId.value);
    }
    if (videoChannel.present) {
      map['video_channel'] = Variable<String>(videoChannel.value);
    }
    if (videoDurationS.present) {
      map['video_duration_s'] = Variable<int>(videoDurationS.value);
    }
    if (videoAvailable.present) {
      map['video_available'] = Variable<bool>(videoAvailable.value);
    }
    if (videoCheckedAt.present) {
      map['video_checked_at'] = Variable<DateTime>(videoCheckedAt.value);
    }
    if (videoUnavailableReason.present) {
      map['video_unavailable_reason'] = Variable<String>(
        videoUnavailableReason.value,
      );
    }
    if (guideSteps.present) {
      map['guide_steps'] = Variable<String>(guideSteps.value);
    }
    if (guideSafety.present) {
      map['guide_safety'] = Variable<String>(guideSafety.value);
    }
    if (approvedAt.present) {
      map['approved_at'] = Variable<String>(approvedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('muscleGroup: $muscleGroup, ')
          ..write('muscleRegion: $muscleRegion, ')
          ..write('equipment: $equipment, ')
          ..write('logsWeight: $logsWeight, ')
          ..write('nameVi: $nameVi, ')
          ..write('nameEn: $nameEn, ')
          ..write('youtubeVideoId: $youtubeVideoId, ')
          ..write('videoChannel: $videoChannel, ')
          ..write('videoDurationS: $videoDurationS, ')
          ..write('videoAvailable: $videoAvailable, ')
          ..write('videoCheckedAt: $videoCheckedAt, ')
          ..write('videoUnavailableReason: $videoUnavailableReason, ')
          ..write('guideSteps: $guideSteps, ')
          ..write('guideSafety: $guideSafety, ')
          ..write('approvedAt: $approvedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('active: $active, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LiftLogsTable extends LiftLogs
    with TableInfo<$LiftLogsTable, LiftLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LiftLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startKgX10Meta = const VerificationMeta(
    'startKgX10',
  );
  @override
  late final GeneratedColumn<int> startKgX10 = GeneratedColumn<int>(
    'start_kg_x10',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endKgX10Meta = const VerificationMeta(
    'endKgX10',
  );
  @override
  late final GeneratedColumn<int> endKgX10 = GeneratedColumn<int>(
    'end_kg_x10',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    exerciseId,
    startKgX10,
    endKgX10,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lift_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LiftLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('start_kg_x10')) {
      context.handle(
        _startKgX10Meta,
        startKgX10.isAcceptableOrUnknown(
          data['start_kg_x10']!,
          _startKgX10Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startKgX10Meta);
    }
    if (data.containsKey('end_kg_x10')) {
      context.handle(
        _endKgX10Meta,
        endKgX10.isAcceptableOrUnknown(data['end_kg_x10']!, _endKgX10Meta),
      );
    } else if (isInserting) {
      context.missing(_endKgX10Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date, exerciseId};
  @override
  LiftLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LiftLogRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      startKgX10: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_kg_x10'],
      )!,
      endKgX10: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_kg_x10'],
      )!,
    );
  }

  @override
  $LiftLogsTable createAlias(String alias) {
    return $LiftLogsTable(attachedDatabase, alias);
  }
}

class LiftLogRow extends DataClass implements Insertable<LiftLogRow> {
  /// `YYYY-MM-DD`.
  final String date;
  final String exerciseId;
  final int startKgX10;
  final int endKgX10;
  const LiftLogRow({
    required this.date,
    required this.exerciseId,
    required this.startKgX10,
    required this.endKgX10,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['start_kg_x10'] = Variable<int>(startKgX10);
    map['end_kg_x10'] = Variable<int>(endKgX10);
    return map;
  }

  LiftLogsCompanion toCompanion(bool nullToAbsent) {
    return LiftLogsCompanion(
      date: Value(date),
      exerciseId: Value(exerciseId),
      startKgX10: Value(startKgX10),
      endKgX10: Value(endKgX10),
    );
  }

  factory LiftLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LiftLogRow(
      date: serializer.fromJson<String>(json['date']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      startKgX10: serializer.fromJson<int>(json['startKgX10']),
      endKgX10: serializer.fromJson<int>(json['endKgX10']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'startKgX10': serializer.toJson<int>(startKgX10),
      'endKgX10': serializer.toJson<int>(endKgX10),
    };
  }

  LiftLogRow copyWith({
    String? date,
    String? exerciseId,
    int? startKgX10,
    int? endKgX10,
  }) => LiftLogRow(
    date: date ?? this.date,
    exerciseId: exerciseId ?? this.exerciseId,
    startKgX10: startKgX10 ?? this.startKgX10,
    endKgX10: endKgX10 ?? this.endKgX10,
  );
  LiftLogRow copyWithCompanion(LiftLogsCompanion data) {
    return LiftLogRow(
      date: data.date.present ? data.date.value : this.date,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      startKgX10: data.startKgX10.present
          ? data.startKgX10.value
          : this.startKgX10,
      endKgX10: data.endKgX10.present ? data.endKgX10.value : this.endKgX10,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LiftLogRow(')
          ..write('date: $date, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('startKgX10: $startKgX10, ')
          ..write('endKgX10: $endKgX10')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, exerciseId, startKgX10, endKgX10);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LiftLogRow &&
          other.date == this.date &&
          other.exerciseId == this.exerciseId &&
          other.startKgX10 == this.startKgX10 &&
          other.endKgX10 == this.endKgX10);
}

class LiftLogsCompanion extends UpdateCompanion<LiftLogRow> {
  final Value<String> date;
  final Value<String> exerciseId;
  final Value<int> startKgX10;
  final Value<int> endKgX10;
  final Value<int> rowid;
  const LiftLogsCompanion({
    this.date = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.startKgX10 = const Value.absent(),
    this.endKgX10 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LiftLogsCompanion.insert({
    required String date,
    required String exerciseId,
    required int startKgX10,
    required int endKgX10,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       exerciseId = Value(exerciseId),
       startKgX10 = Value(startKgX10),
       endKgX10 = Value(endKgX10);
  static Insertable<LiftLogRow> custom({
    Expression<String>? date,
    Expression<String>? exerciseId,
    Expression<int>? startKgX10,
    Expression<int>? endKgX10,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (startKgX10 != null) 'start_kg_x10': startKgX10,
      if (endKgX10 != null) 'end_kg_x10': endKgX10,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LiftLogsCompanion copyWith({
    Value<String>? date,
    Value<String>? exerciseId,
    Value<int>? startKgX10,
    Value<int>? endKgX10,
    Value<int>? rowid,
  }) {
    return LiftLogsCompanion(
      date: date ?? this.date,
      exerciseId: exerciseId ?? this.exerciseId,
      startKgX10: startKgX10 ?? this.startKgX10,
      endKgX10: endKgX10 ?? this.endKgX10,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (startKgX10.present) {
      map['start_kg_x10'] = Variable<int>(startKgX10.value);
    }
    if (endKgX10.present) {
      map['end_kg_x10'] = Variable<int>(endKgX10.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LiftLogsCompanion(')
          ..write('date: $date, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('startKgX10: $startKgX10, ')
          ..write('endKgX10: $endKgX10, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $AccountTable account = $AccountTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $WeightsTable weights = $WeightsTable(this);
  late final $OnboardingDraftTable onboardingDraft = $OnboardingDraftTable(
    this,
  );
  late final $WeeklyTemplatesTable weeklyTemplates = $WeeklyTemplatesTable(
    this,
  );
  late final $MonthPlansTable monthPlans = $MonthPlansTable(this);
  late final $DaysTable days = $DaysTable(this);
  late final $MenusTable menus = $MenusTable(this);
  late final $AiDailyUsageTable aiDailyUsage = $AiDailyUsageTable(this);
  late final $DishImagesTable dishImages = $DishImagesTable(this);
  late final $MuscleRegionsTable muscleRegions = $MuscleRegionsTable(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $LiftLogsTable liftLogs = $LiftLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncState,
    outbox,
    account,
    profiles,
    weights,
    onboardingDraft,
    weeklyTemplates,
    monthPlans,
    days,
    menus,
    aiDailyUsage,
    dishImages,
    muscleRegions,
    exercises,
    liftLogs,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      Value<int> id,
      Value<int> cursor,
      Value<DateTime?> lastSyncedAt,
      Value<String?> aiBudget,
      Value<String?> knownEntities,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<int> id,
      Value<int> cursor,
      Value<DateTime?> lastSyncedAt,
      Value<String?> aiBudget,
      Value<String?> knownEntities,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
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

  ColumnFilters<int> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiBudget => $composableBuilder(
    column: $table.aiBudget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get knownEntities => $composableBuilder(
    column: $table.knownEntities,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
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

  ColumnOrderings<int> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiBudget => $composableBuilder(
    column: $table.aiBudget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get knownEntities => $composableBuilder(
    column: $table.knownEntities,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiBudget =>
      $composableBuilder(column: $table.aiBudget, builder: (column) => column);

  GeneratedColumn<String> get knownEntities => $composableBuilder(
    column: $table.knownEntities,
    builder: (column) => column,
  );
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateRow,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cursor = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String?> aiBudget = const Value.absent(),
                Value<String?> knownEntities = const Value.absent(),
              }) => SyncStateCompanion(
                id: id,
                cursor: cursor,
                lastSyncedAt: lastSyncedAt,
                aiBudget: aiBudget,
                knownEntities: knownEntities,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cursor = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String?> aiBudget = const Value.absent(),
                Value<String?> knownEntities = const Value.absent(),
              }) => SyncStateCompanion.insert(
                id: id,
                cursor: cursor,
                lastSyncedAt: lastSyncedAt,
                aiBudget: aiBudget,
                knownEntities: knownEntities,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateRow,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      required String mutationId,
      required String entity,
      required String entityKey,
      required String op,
      Value<String?> payload,
      required DateTime clientUpdatedAt,
      Value<int> attempts,
      Value<String?> lastError,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      Value<String> mutationId,
      Value<String> entity,
      Value<String> entityKey,
      Value<String> op,
      Value<String?> payload,
      Value<DateTime> clientUpdatedAt,
      Value<int> attempts,
      Value<String?> lastError,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
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

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityKey => $composableBuilder(
    column: $table.entityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
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

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityKey => $composableBuilder(
    column: $table.entityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityKey =>
      $composableBuilder(column: $table.entityKey, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityKey = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                mutationId: mutationId,
                entity: entity,
                entityKey: entityKey,
                op: op,
                payload: payload,
                clientUpdatedAt: clientUpdatedAt,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String mutationId,
                required String entity,
                required String entityKey,
                required String op,
                Value<String?> payload = const Value.absent(),
                required DateTime clientUpdatedAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                mutationId: mutationId,
                entity: entity,
                entityKey: entityKey,
                op: op,
                payload: payload,
                clientUpdatedAt: clientUpdatedAt,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$AccountTableCreateCompanionBuilder =
    AccountCompanion Function({
      required String key,
      required String displayName,
      Value<int> rowid,
    });
typedef $$AccountTableUpdateCompanionBuilder =
    AccountCompanion Function({
      Value<String> key,
      Value<String> displayName,
      Value<int> rowid,
    });

class $$AccountTableFilterComposer
    extends Composer<_$AppDatabase, $AccountTable> {
  $$AccountTableFilterComposer({
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

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountTable> {
  $$AccountTableOrderingComposer({
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

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountTable> {
  $$AccountTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );
}

class $$AccountTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountTable,
          AccountRow,
          $$AccountTableFilterComposer,
          $$AccountTableOrderingComposer,
          $$AccountTableAnnotationComposer,
          $$AccountTableCreateCompanionBuilder,
          $$AccountTableUpdateCompanionBuilder,
          (
            AccountRow,
            BaseReferences<_$AppDatabase, $AccountTable, AccountRow>,
          ),
          AccountRow,
          PrefetchHooks Function()
        > {
  $$AccountTableTableManager(_$AppDatabase db, $AccountTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountCompanion(
                key: key,
                displayName: displayName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String displayName,
                Value<int> rowid = const Value.absent(),
              }) => AccountCompanion.insert(
                key: key,
                displayName: displayName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountTable,
      AccountRow,
      $$AccountTableFilterComposer,
      $$AccountTableOrderingComposer,
      $$AccountTableAnnotationComposer,
      $$AccountTableCreateCompanionBuilder,
      $$AccountTableUpdateCompanionBuilder,
      (AccountRow, BaseReferences<_$AppDatabase, $AccountTable, AccountRow>),
      AccountRow,
      PrefetchHooks Function()
    >;
typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      required String key,
      required int onboardingStep,
      Value<int?> heightCm,
      Value<int?> birthYear,
      Value<String?> sex,
      Value<String?> activityLevel,
      Value<String?> setupDate,
      Value<String?> scheduleStartedOn,
      Value<DateTime?> disclaimerAcceptedAt,
      Value<DateTime?> onboardingCompletedAt,
      Value<String?> calorieMode,
      Value<int?> calorieKcal,
      Value<int?> caloriePendingKcal,
      Value<String?> caloriePendingReason,
      Value<bool> remindersEnabled,
      Value<String?> timezone,
      Value<int> rowid,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<String> key,
      Value<int> onboardingStep,
      Value<int?> heightCm,
      Value<int?> birthYear,
      Value<String?> sex,
      Value<String?> activityLevel,
      Value<String?> setupDate,
      Value<String?> scheduleStartedOn,
      Value<DateTime?> disclaimerAcceptedAt,
      Value<DateTime?> onboardingCompletedAt,
      Value<String?> calorieMode,
      Value<int?> calorieKcal,
      Value<int?> caloriePendingKcal,
      Value<String?> caloriePendingReason,
      Value<bool> remindersEnabled,
      Value<String?> timezone,
      Value<int> rowid,
    });

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
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

  ColumnFilters<int> get onboardingStep => $composableBuilder(
    column: $table.onboardingStep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthYear => $composableBuilder(
    column: $table.birthYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setupDate => $composableBuilder(
    column: $table.setupDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleStartedOn => $composableBuilder(
    column: $table.scheduleStartedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get disclaimerAcceptedAt => $composableBuilder(
    column: $table.disclaimerAcceptedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get onboardingCompletedAt => $composableBuilder(
    column: $table.onboardingCompletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calorieMode => $composableBuilder(
    column: $table.calorieMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calorieKcal => $composableBuilder(
    column: $table.calorieKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get caloriePendingKcal => $composableBuilder(
    column: $table.caloriePendingKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caloriePendingReason => $composableBuilder(
    column: $table.caloriePendingReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get remindersEnabled => $composableBuilder(
    column: $table.remindersEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
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

  ColumnOrderings<int> get onboardingStep => $composableBuilder(
    column: $table.onboardingStep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthYear => $composableBuilder(
    column: $table.birthYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setupDate => $composableBuilder(
    column: $table.setupDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleStartedOn => $composableBuilder(
    column: $table.scheduleStartedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get disclaimerAcceptedAt => $composableBuilder(
    column: $table.disclaimerAcceptedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get onboardingCompletedAt => $composableBuilder(
    column: $table.onboardingCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calorieMode => $composableBuilder(
    column: $table.calorieMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calorieKcal => $composableBuilder(
    column: $table.calorieKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get caloriePendingKcal => $composableBuilder(
    column: $table.caloriePendingKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caloriePendingReason => $composableBuilder(
    column: $table.caloriePendingReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get remindersEnabled => $composableBuilder(
    column: $table.remindersEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get onboardingStep => $composableBuilder(
    column: $table.onboardingStep,
    builder: (column) => column,
  );

  GeneratedColumn<int> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumn<int> get birthYear =>
      $composableBuilder(column: $table.birthYear, builder: (column) => column);

  GeneratedColumn<String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get setupDate =>
      $composableBuilder(column: $table.setupDate, builder: (column) => column);

  GeneratedColumn<String> get scheduleStartedOn => $composableBuilder(
    column: $table.scheduleStartedOn,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get disclaimerAcceptedAt => $composableBuilder(
    column: $table.disclaimerAcceptedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get onboardingCompletedAt => $composableBuilder(
    column: $table.onboardingCompletedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calorieMode => $composableBuilder(
    column: $table.calorieMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get calorieKcal => $composableBuilder(
    column: $table.calorieKcal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get caloriePendingKcal => $composableBuilder(
    column: $table.caloriePendingKcal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get caloriePendingReason => $composableBuilder(
    column: $table.caloriePendingReason,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get remindersEnabled => $composableBuilder(
    column: $table.remindersEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timezone =>
      $composableBuilder(column: $table.timezone, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          ProfileRow,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (
            ProfileRow,
            BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow>,
          ),
          ProfileRow,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> onboardingStep = const Value.absent(),
                Value<int?> heightCm = const Value.absent(),
                Value<int?> birthYear = const Value.absent(),
                Value<String?> sex = const Value.absent(),
                Value<String?> activityLevel = const Value.absent(),
                Value<String?> setupDate = const Value.absent(),
                Value<String?> scheduleStartedOn = const Value.absent(),
                Value<DateTime?> disclaimerAcceptedAt = const Value.absent(),
                Value<DateTime?> onboardingCompletedAt = const Value.absent(),
                Value<String?> calorieMode = const Value.absent(),
                Value<int?> calorieKcal = const Value.absent(),
                Value<int?> caloriePendingKcal = const Value.absent(),
                Value<String?> caloriePendingReason = const Value.absent(),
                Value<bool> remindersEnabled = const Value.absent(),
                Value<String?> timezone = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                key: key,
                onboardingStep: onboardingStep,
                heightCm: heightCm,
                birthYear: birthYear,
                sex: sex,
                activityLevel: activityLevel,
                setupDate: setupDate,
                scheduleStartedOn: scheduleStartedOn,
                disclaimerAcceptedAt: disclaimerAcceptedAt,
                onboardingCompletedAt: onboardingCompletedAt,
                calorieMode: calorieMode,
                calorieKcal: calorieKcal,
                caloriePendingKcal: caloriePendingKcal,
                caloriePendingReason: caloriePendingReason,
                remindersEnabled: remindersEnabled,
                timezone: timezone,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required int onboardingStep,
                Value<int?> heightCm = const Value.absent(),
                Value<int?> birthYear = const Value.absent(),
                Value<String?> sex = const Value.absent(),
                Value<String?> activityLevel = const Value.absent(),
                Value<String?> setupDate = const Value.absent(),
                Value<String?> scheduleStartedOn = const Value.absent(),
                Value<DateTime?> disclaimerAcceptedAt = const Value.absent(),
                Value<DateTime?> onboardingCompletedAt = const Value.absent(),
                Value<String?> calorieMode = const Value.absent(),
                Value<int?> calorieKcal = const Value.absent(),
                Value<int?> caloriePendingKcal = const Value.absent(),
                Value<String?> caloriePendingReason = const Value.absent(),
                Value<bool> remindersEnabled = const Value.absent(),
                Value<String?> timezone = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                key: key,
                onboardingStep: onboardingStep,
                heightCm: heightCm,
                birthYear: birthYear,
                sex: sex,
                activityLevel: activityLevel,
                setupDate: setupDate,
                scheduleStartedOn: scheduleStartedOn,
                disclaimerAcceptedAt: disclaimerAcceptedAt,
                onboardingCompletedAt: onboardingCompletedAt,
                calorieMode: calorieMode,
                calorieKcal: calorieKcal,
                caloriePendingKcal: caloriePendingKcal,
                caloriePendingReason: caloriePendingReason,
                remindersEnabled: remindersEnabled,
                timezone: timezone,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      ProfileRow,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (ProfileRow, BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow>),
      ProfileRow,
      PrefetchHooks Function()
    >;
typedef $$WeightsTableCreateCompanionBuilder =
    WeightsCompanion Function({
      required String weekStart,
      required int weightKgX10,
      Value<int> rowid,
    });
typedef $$WeightsTableUpdateCompanionBuilder =
    WeightsCompanion Function({
      Value<String> weekStart,
      Value<int> weightKgX10,
      Value<int> rowid,
    });

class $$WeightsTableFilterComposer
    extends Composer<_$AppDatabase, $WeightsTable> {
  $$WeightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weightKgX10 => $composableBuilder(
    column: $table.weightKgX10,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeightsTableOrderingComposer
    extends Composer<_$AppDatabase, $WeightsTable> {
  $$WeightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weightKgX10 => $composableBuilder(
    column: $table.weightKgX10,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeightsTable> {
  $$WeightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get weekStart =>
      $composableBuilder(column: $table.weekStart, builder: (column) => column);

  GeneratedColumn<int> get weightKgX10 => $composableBuilder(
    column: $table.weightKgX10,
    builder: (column) => column,
  );
}

class $$WeightsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeightsTable,
          WeightRow,
          $$WeightsTableFilterComposer,
          $$WeightsTableOrderingComposer,
          $$WeightsTableAnnotationComposer,
          $$WeightsTableCreateCompanionBuilder,
          $$WeightsTableUpdateCompanionBuilder,
          (WeightRow, BaseReferences<_$AppDatabase, $WeightsTable, WeightRow>),
          WeightRow,
          PrefetchHooks Function()
        > {
  $$WeightsTableTableManager(_$AppDatabase db, $WeightsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeightsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> weekStart = const Value.absent(),
                Value<int> weightKgX10 = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeightsCompanion(
                weekStart: weekStart,
                weightKgX10: weightKgX10,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String weekStart,
                required int weightKgX10,
                Value<int> rowid = const Value.absent(),
              }) => WeightsCompanion.insert(
                weekStart: weekStart,
                weightKgX10: weightKgX10,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeightsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeightsTable,
      WeightRow,
      $$WeightsTableFilterComposer,
      $$WeightsTableOrderingComposer,
      $$WeightsTableAnnotationComposer,
      $$WeightsTableCreateCompanionBuilder,
      $$WeightsTableUpdateCompanionBuilder,
      (WeightRow, BaseReferences<_$AppDatabase, $WeightsTable, WeightRow>),
      WeightRow,
      PrefetchHooks Function()
    >;
typedef $$OnboardingDraftTableCreateCompanionBuilder =
    OnboardingDraftCompanion Function({
      Value<int> id,
      Value<String> height,
      Value<int?> birthYear,
      Value<String?> sex,
      Value<String?> activityLevel,
      Value<String> weight,
      Value<String?> template,
    });
typedef $$OnboardingDraftTableUpdateCompanionBuilder =
    OnboardingDraftCompanion Function({
      Value<int> id,
      Value<String> height,
      Value<int?> birthYear,
      Value<String?> sex,
      Value<String?> activityLevel,
      Value<String> weight,
      Value<String?> template,
    });

class $$OnboardingDraftTableFilterComposer
    extends Composer<_$AppDatabase, $OnboardingDraftTable> {
  $$OnboardingDraftTableFilterComposer({
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

  ColumnFilters<String> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthYear => $composableBuilder(
    column: $table.birthYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get template => $composableBuilder(
    column: $table.template,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OnboardingDraftTableOrderingComposer
    extends Composer<_$AppDatabase, $OnboardingDraftTable> {
  $$OnboardingDraftTableOrderingComposer({
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

  ColumnOrderings<String> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthYear => $composableBuilder(
    column: $table.birthYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get template => $composableBuilder(
    column: $table.template,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OnboardingDraftTableAnnotationComposer
    extends Composer<_$AppDatabase, $OnboardingDraftTable> {
  $$OnboardingDraftTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get birthYear =>
      $composableBuilder(column: $table.birthYear, builder: (column) => column);

  GeneratedColumn<String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<String> get template =>
      $composableBuilder(column: $table.template, builder: (column) => column);
}

class $$OnboardingDraftTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OnboardingDraftTable,
          OnboardingDraftRow,
          $$OnboardingDraftTableFilterComposer,
          $$OnboardingDraftTableOrderingComposer,
          $$OnboardingDraftTableAnnotationComposer,
          $$OnboardingDraftTableCreateCompanionBuilder,
          $$OnboardingDraftTableUpdateCompanionBuilder,
          (
            OnboardingDraftRow,
            BaseReferences<
              _$AppDatabase,
              $OnboardingDraftTable,
              OnboardingDraftRow
            >,
          ),
          OnboardingDraftRow,
          PrefetchHooks Function()
        > {
  $$OnboardingDraftTableTableManager(
    _$AppDatabase db,
    $OnboardingDraftTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnboardingDraftTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OnboardingDraftTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OnboardingDraftTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> height = const Value.absent(),
                Value<int?> birthYear = const Value.absent(),
                Value<String?> sex = const Value.absent(),
                Value<String?> activityLevel = const Value.absent(),
                Value<String> weight = const Value.absent(),
                Value<String?> template = const Value.absent(),
              }) => OnboardingDraftCompanion(
                id: id,
                height: height,
                birthYear: birthYear,
                sex: sex,
                activityLevel: activityLevel,
                weight: weight,
                template: template,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> height = const Value.absent(),
                Value<int?> birthYear = const Value.absent(),
                Value<String?> sex = const Value.absent(),
                Value<String?> activityLevel = const Value.absent(),
                Value<String> weight = const Value.absent(),
                Value<String?> template = const Value.absent(),
              }) => OnboardingDraftCompanion.insert(
                id: id,
                height: height,
                birthYear: birthYear,
                sex: sex,
                activityLevel: activityLevel,
                weight: weight,
                template: template,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OnboardingDraftTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OnboardingDraftTable,
      OnboardingDraftRow,
      $$OnboardingDraftTableFilterComposer,
      $$OnboardingDraftTableOrderingComposer,
      $$OnboardingDraftTableAnnotationComposer,
      $$OnboardingDraftTableCreateCompanionBuilder,
      $$OnboardingDraftTableUpdateCompanionBuilder,
      (
        OnboardingDraftRow,
        BaseReferences<
          _$AppDatabase,
          $OnboardingDraftTable,
          OnboardingDraftRow
        >,
      ),
      OnboardingDraftRow,
      PrefetchHooks Function()
    >;
typedef $$WeeklyTemplatesTableCreateCompanionBuilder =
    WeeklyTemplatesCompanion Function({
      required String key,
      required String days,
      required String contentHash,
      Value<int> rowid,
    });
typedef $$WeeklyTemplatesTableUpdateCompanionBuilder =
    WeeklyTemplatesCompanion Function({
      Value<String> key,
      Value<String> days,
      Value<String> contentHash,
      Value<int> rowid,
    });

class $$WeeklyTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $WeeklyTemplatesTable> {
  $$WeeklyTemplatesTableFilterComposer({
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

  ColumnFilters<String> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeeklyTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $WeeklyTemplatesTable> {
  $$WeeklyTemplatesTableOrderingComposer({
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

  ColumnOrderings<String> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeeklyTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeeklyTemplatesTable> {
  $$WeeklyTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get days =>
      $composableBuilder(column: $table.days, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );
}

class $$WeeklyTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeeklyTemplatesTable,
          WeeklyTemplateRow,
          $$WeeklyTemplatesTableFilterComposer,
          $$WeeklyTemplatesTableOrderingComposer,
          $$WeeklyTemplatesTableAnnotationComposer,
          $$WeeklyTemplatesTableCreateCompanionBuilder,
          $$WeeklyTemplatesTableUpdateCompanionBuilder,
          (
            WeeklyTemplateRow,
            BaseReferences<
              _$AppDatabase,
              $WeeklyTemplatesTable,
              WeeklyTemplateRow
            >,
          ),
          WeeklyTemplateRow,
          PrefetchHooks Function()
        > {
  $$WeeklyTemplatesTableTableManager(
    _$AppDatabase db,
    $WeeklyTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeeklyTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeeklyTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeeklyTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> days = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeeklyTemplatesCompanion(
                key: key,
                days: days,
                contentHash: contentHash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String days,
                required String contentHash,
                Value<int> rowid = const Value.absent(),
              }) => WeeklyTemplatesCompanion.insert(
                key: key,
                days: days,
                contentHash: contentHash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeeklyTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeeklyTemplatesTable,
      WeeklyTemplateRow,
      $$WeeklyTemplatesTableFilterComposer,
      $$WeeklyTemplatesTableOrderingComposer,
      $$WeeklyTemplatesTableAnnotationComposer,
      $$WeeklyTemplatesTableCreateCompanionBuilder,
      $$WeeklyTemplatesTableUpdateCompanionBuilder,
      (
        WeeklyTemplateRow,
        BaseReferences<_$AppDatabase, $WeeklyTemplatesTable, WeeklyTemplateRow>,
      ),
      WeeklyTemplateRow,
      PrefetchHooks Function()
    >;
typedef $$MonthPlansTableCreateCompanionBuilder =
    MonthPlansCompanion Function({
      required String month,
      required String startDate,
      required String templateHash,
      required DateTime generatedAt,
      Value<DateTime?> redistributedAt,
      Value<int> rowid,
    });
typedef $$MonthPlansTableUpdateCompanionBuilder =
    MonthPlansCompanion Function({
      Value<String> month,
      Value<String> startDate,
      Value<String> templateHash,
      Value<DateTime> generatedAt,
      Value<DateTime?> redistributedAt,
      Value<int> rowid,
    });

class $$MonthPlansTableFilterComposer
    extends Composer<_$AppDatabase, $MonthPlansTable> {
  $$MonthPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateHash => $composableBuilder(
    column: $table.templateHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get redistributedAt => $composableBuilder(
    column: $table.redistributedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MonthPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $MonthPlansTable> {
  $$MonthPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateHash => $composableBuilder(
    column: $table.templateHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get redistributedAt => $composableBuilder(
    column: $table.redistributedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MonthPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $MonthPlansTable> {
  $$MonthPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get templateHash => $composableBuilder(
    column: $table.templateHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get redistributedAt => $composableBuilder(
    column: $table.redistributedAt,
    builder: (column) => column,
  );
}

class $$MonthPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MonthPlansTable,
          MonthPlanRow,
          $$MonthPlansTableFilterComposer,
          $$MonthPlansTableOrderingComposer,
          $$MonthPlansTableAnnotationComposer,
          $$MonthPlansTableCreateCompanionBuilder,
          $$MonthPlansTableUpdateCompanionBuilder,
          (
            MonthPlanRow,
            BaseReferences<_$AppDatabase, $MonthPlansTable, MonthPlanRow>,
          ),
          MonthPlanRow,
          PrefetchHooks Function()
        > {
  $$MonthPlansTableTableManager(_$AppDatabase db, $MonthPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MonthPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MonthPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MonthPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> month = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String> templateHash = const Value.absent(),
                Value<DateTime> generatedAt = const Value.absent(),
                Value<DateTime?> redistributedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MonthPlansCompanion(
                month: month,
                startDate: startDate,
                templateHash: templateHash,
                generatedAt: generatedAt,
                redistributedAt: redistributedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String month,
                required String startDate,
                required String templateHash,
                required DateTime generatedAt,
                Value<DateTime?> redistributedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MonthPlansCompanion.insert(
                month: month,
                startDate: startDate,
                templateHash: templateHash,
                generatedAt: generatedAt,
                redistributedAt: redistributedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MonthPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MonthPlansTable,
      MonthPlanRow,
      $$MonthPlansTableFilterComposer,
      $$MonthPlansTableOrderingComposer,
      $$MonthPlansTableAnnotationComposer,
      $$MonthPlansTableCreateCompanionBuilder,
      $$MonthPlansTableUpdateCompanionBuilder,
      (
        MonthPlanRow,
        BaseReferences<_$AppDatabase, $MonthPlansTable, MonthPlanRow>,
      ),
      MonthPlanRow,
      PrefetchHooks Function()
    >;
typedef $$DaysTableCreateCompanionBuilder =
    DaysCompanion Function({
      required String date,
      required String kind,
      Value<String?> time,
      Value<String?> muscles,
      required String source,
      Value<String?> mark,
      Value<String?> actualMuscles,
      Value<DateTime?> markedAt,
      Value<String?> extraMuscles,
      Value<DateTime?> extraLoggedAt,
      Value<int> rowid,
    });
typedef $$DaysTableUpdateCompanionBuilder =
    DaysCompanion Function({
      Value<String> date,
      Value<String> kind,
      Value<String?> time,
      Value<String?> muscles,
      Value<String> source,
      Value<String?> mark,
      Value<String?> actualMuscles,
      Value<DateTime?> markedAt,
      Value<String?> extraMuscles,
      Value<DateTime?> extraLoggedAt,
      Value<int> rowid,
    });

class $$DaysTableFilterComposer extends Composer<_$AppDatabase, $DaysTable> {
  $$DaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get muscles => $composableBuilder(
    column: $table.muscles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mark => $composableBuilder(
    column: $table.mark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actualMuscles => $composableBuilder(
    column: $table.actualMuscles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get markedAt => $composableBuilder(
    column: $table.markedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraMuscles => $composableBuilder(
    column: $table.extraMuscles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get extraLoggedAt => $composableBuilder(
    column: $table.extraLoggedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DaysTableOrderingComposer extends Composer<_$AppDatabase, $DaysTable> {
  $$DaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get muscles => $composableBuilder(
    column: $table.muscles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mark => $composableBuilder(
    column: $table.mark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actualMuscles => $composableBuilder(
    column: $table.actualMuscles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get markedAt => $composableBuilder(
    column: $table.markedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraMuscles => $composableBuilder(
    column: $table.extraMuscles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get extraLoggedAt => $composableBuilder(
    column: $table.extraLoggedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $DaysTable> {
  $$DaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get muscles =>
      $composableBuilder(column: $table.muscles, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get mark =>
      $composableBuilder(column: $table.mark, builder: (column) => column);

  GeneratedColumn<String> get actualMuscles => $composableBuilder(
    column: $table.actualMuscles,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get markedAt =>
      $composableBuilder(column: $table.markedAt, builder: (column) => column);

  GeneratedColumn<String> get extraMuscles => $composableBuilder(
    column: $table.extraMuscles,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get extraLoggedAt => $composableBuilder(
    column: $table.extraLoggedAt,
    builder: (column) => column,
  );
}

class $$DaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DaysTable,
          DayRow,
          $$DaysTableFilterComposer,
          $$DaysTableOrderingComposer,
          $$DaysTableAnnotationComposer,
          $$DaysTableCreateCompanionBuilder,
          $$DaysTableUpdateCompanionBuilder,
          (DayRow, BaseReferences<_$AppDatabase, $DaysTable, DayRow>),
          DayRow,
          PrefetchHooks Function()
        > {
  $$DaysTableTableManager(_$AppDatabase db, $DaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> time = const Value.absent(),
                Value<String?> muscles = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> mark = const Value.absent(),
                Value<String?> actualMuscles = const Value.absent(),
                Value<DateTime?> markedAt = const Value.absent(),
                Value<String?> extraMuscles = const Value.absent(),
                Value<DateTime?> extraLoggedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DaysCompanion(
                date: date,
                kind: kind,
                time: time,
                muscles: muscles,
                source: source,
                mark: mark,
                actualMuscles: actualMuscles,
                markedAt: markedAt,
                extraMuscles: extraMuscles,
                extraLoggedAt: extraLoggedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                required String kind,
                Value<String?> time = const Value.absent(),
                Value<String?> muscles = const Value.absent(),
                required String source,
                Value<String?> mark = const Value.absent(),
                Value<String?> actualMuscles = const Value.absent(),
                Value<DateTime?> markedAt = const Value.absent(),
                Value<String?> extraMuscles = const Value.absent(),
                Value<DateTime?> extraLoggedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DaysCompanion.insert(
                date: date,
                kind: kind,
                time: time,
                muscles: muscles,
                source: source,
                mark: mark,
                actualMuscles: actualMuscles,
                markedAt: markedAt,
                extraMuscles: extraMuscles,
                extraLoggedAt: extraLoggedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DaysTable,
      DayRow,
      $$DaysTableFilterComposer,
      $$DaysTableOrderingComposer,
      $$DaysTableAnnotationComposer,
      $$DaysTableCreateCompanionBuilder,
      $$DaysTableUpdateCompanionBuilder,
      (DayRow, BaseReferences<_$AppDatabase, $DaysTable, DayRow>),
      DayRow,
      PrefetchHooks Function()
    >;
typedef $$MenusTableCreateCompanionBuilder =
    MenusCompanion Function({
      required String date,
      Value<String?> payload,
      required int targetKcal,
      required bool usedSafetyFloor,
      Value<int?> totalKcal,
      required String lastAttemptStatus,
      Value<String?> lastErrorCode,
      Value<DateTime?> generatedAt,
      Value<int> rowid,
    });
typedef $$MenusTableUpdateCompanionBuilder =
    MenusCompanion Function({
      Value<String> date,
      Value<String?> payload,
      Value<int> targetKcal,
      Value<bool> usedSafetyFloor,
      Value<int?> totalKcal,
      Value<String> lastAttemptStatus,
      Value<String?> lastErrorCode,
      Value<DateTime?> generatedAt,
      Value<int> rowid,
    });

class $$MenusTableFilterComposer extends Composer<_$AppDatabase, $MenusTable> {
  $$MenusTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetKcal => $composableBuilder(
    column: $table.targetKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get usedSafetyFloor => $composableBuilder(
    column: $table.usedSafetyFloor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalKcal => $composableBuilder(
    column: $table.totalKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastAttemptStatus => $composableBuilder(
    column: $table.lastAttemptStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MenusTableOrderingComposer
    extends Composer<_$AppDatabase, $MenusTable> {
  $$MenusTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetKcal => $composableBuilder(
    column: $table.targetKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get usedSafetyFloor => $composableBuilder(
    column: $table.usedSafetyFloor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalKcal => $composableBuilder(
    column: $table.totalKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastAttemptStatus => $composableBuilder(
    column: $table.lastAttemptStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MenusTableAnnotationComposer
    extends Composer<_$AppDatabase, $MenusTable> {
  $$MenusTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get targetKcal => $composableBuilder(
    column: $table.targetKcal,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get usedSafetyFloor => $composableBuilder(
    column: $table.usedSafetyFloor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalKcal =>
      $composableBuilder(column: $table.totalKcal, builder: (column) => column);

  GeneratedColumn<String> get lastAttemptStatus => $composableBuilder(
    column: $table.lastAttemptStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );
}

class $$MenusTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MenusTable,
          MenuRow,
          $$MenusTableFilterComposer,
          $$MenusTableOrderingComposer,
          $$MenusTableAnnotationComposer,
          $$MenusTableCreateCompanionBuilder,
          $$MenusTableUpdateCompanionBuilder,
          (MenuRow, BaseReferences<_$AppDatabase, $MenusTable, MenuRow>),
          MenuRow,
          PrefetchHooks Function()
        > {
  $$MenusTableTableManager(_$AppDatabase db, $MenusTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MenusTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MenusTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MenusTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<int> targetKcal = const Value.absent(),
                Value<bool> usedSafetyFloor = const Value.absent(),
                Value<int?> totalKcal = const Value.absent(),
                Value<String> lastAttemptStatus = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<DateTime?> generatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MenusCompanion(
                date: date,
                payload: payload,
                targetKcal: targetKcal,
                usedSafetyFloor: usedSafetyFloor,
                totalKcal: totalKcal,
                lastAttemptStatus: lastAttemptStatus,
                lastErrorCode: lastErrorCode,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                Value<String?> payload = const Value.absent(),
                required int targetKcal,
                required bool usedSafetyFloor,
                Value<int?> totalKcal = const Value.absent(),
                required String lastAttemptStatus,
                Value<String?> lastErrorCode = const Value.absent(),
                Value<DateTime?> generatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MenusCompanion.insert(
                date: date,
                payload: payload,
                targetKcal: targetKcal,
                usedSafetyFloor: usedSafetyFloor,
                totalKcal: totalKcal,
                lastAttemptStatus: lastAttemptStatus,
                lastErrorCode: lastErrorCode,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MenusTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MenusTable,
      MenuRow,
      $$MenusTableFilterComposer,
      $$MenusTableOrderingComposer,
      $$MenusTableAnnotationComposer,
      $$MenusTableCreateCompanionBuilder,
      $$MenusTableUpdateCompanionBuilder,
      (MenuRow, BaseReferences<_$AppDatabase, $MenusTable, MenuRow>),
      MenuRow,
      PrefetchHooks Function()
    >;
typedef $$AiDailyUsageTableCreateCompanionBuilder =
    AiDailyUsageCompanion Function({
      required String key,
      required int successCount,
      Value<int> rowid,
    });
typedef $$AiDailyUsageTableUpdateCompanionBuilder =
    AiDailyUsageCompanion Function({
      Value<String> key,
      Value<int> successCount,
      Value<int> rowid,
    });

class $$AiDailyUsageTableFilterComposer
    extends Composer<_$AppDatabase, $AiDailyUsageTable> {
  $$AiDailyUsageTableFilterComposer({
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

  ColumnFilters<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiDailyUsageTableOrderingComposer
    extends Composer<_$AppDatabase, $AiDailyUsageTable> {
  $$AiDailyUsageTableOrderingComposer({
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

  ColumnOrderings<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiDailyUsageTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiDailyUsageTable> {
  $$AiDailyUsageTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => column,
  );
}

class $$AiDailyUsageTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiDailyUsageTable,
          AiDailyUsageRow,
          $$AiDailyUsageTableFilterComposer,
          $$AiDailyUsageTableOrderingComposer,
          $$AiDailyUsageTableAnnotationComposer,
          $$AiDailyUsageTableCreateCompanionBuilder,
          $$AiDailyUsageTableUpdateCompanionBuilder,
          (
            AiDailyUsageRow,
            BaseReferences<_$AppDatabase, $AiDailyUsageTable, AiDailyUsageRow>,
          ),
          AiDailyUsageRow,
          PrefetchHooks Function()
        > {
  $$AiDailyUsageTableTableManager(_$AppDatabase db, $AiDailyUsageTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiDailyUsageTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiDailyUsageTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiDailyUsageTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> successCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiDailyUsageCompanion(
                key: key,
                successCount: successCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required int successCount,
                Value<int> rowid = const Value.absent(),
              }) => AiDailyUsageCompanion.insert(
                key: key,
                successCount: successCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiDailyUsageTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiDailyUsageTable,
      AiDailyUsageRow,
      $$AiDailyUsageTableFilterComposer,
      $$AiDailyUsageTableOrderingComposer,
      $$AiDailyUsageTableAnnotationComposer,
      $$AiDailyUsageTableCreateCompanionBuilder,
      $$AiDailyUsageTableUpdateCompanionBuilder,
      (
        AiDailyUsageRow,
        BaseReferences<_$AppDatabase, $AiDailyUsageTable, AiDailyUsageRow>,
      ),
      AiDailyUsageRow,
      PrefetchHooks Function()
    >;
typedef $$DishImagesTableCreateCompanionBuilder =
    DishImagesCompanion Function({
      required String nameKey,
      required String id,
      required String displayName,
      required int width,
      required int height,
      required int bytes,
      required DateTime createdAt,
      Value<String?> cachedPath,
      Value<int> rowid,
    });
typedef $$DishImagesTableUpdateCompanionBuilder =
    DishImagesCompanion Function({
      Value<String> nameKey,
      Value<String> id,
      Value<String> displayName,
      Value<int> width,
      Value<int> height,
      Value<int> bytes,
      Value<DateTime> createdAt,
      Value<String?> cachedPath,
      Value<int> rowid,
    });

class $$DishImagesTableFilterComposer
    extends Composer<_$AppDatabase, $DishImagesTable> {
  $$DishImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cachedPath => $composableBuilder(
    column: $table.cachedPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DishImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $DishImagesTable> {
  $$DishImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cachedPath => $composableBuilder(
    column: $table.cachedPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DishImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DishImagesTable> {
  $$DishImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get nameKey =>
      $composableBuilder(column: $table.nameKey, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get cachedPath => $composableBuilder(
    column: $table.cachedPath,
    builder: (column) => column,
  );
}

class $$DishImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DishImagesTable,
          DishImageRow,
          $$DishImagesTableFilterComposer,
          $$DishImagesTableOrderingComposer,
          $$DishImagesTableAnnotationComposer,
          $$DishImagesTableCreateCompanionBuilder,
          $$DishImagesTableUpdateCompanionBuilder,
          (
            DishImageRow,
            BaseReferences<_$AppDatabase, $DishImagesTable, DishImageRow>,
          ),
          DishImageRow,
          PrefetchHooks Function()
        > {
  $$DishImagesTableTableManager(_$AppDatabase db, $DishImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DishImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DishImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DishImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> nameKey = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> cachedPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DishImagesCompanion(
                nameKey: nameKey,
                id: id,
                displayName: displayName,
                width: width,
                height: height,
                bytes: bytes,
                createdAt: createdAt,
                cachedPath: cachedPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String nameKey,
                required String id,
                required String displayName,
                required int width,
                required int height,
                required int bytes,
                required DateTime createdAt,
                Value<String?> cachedPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DishImagesCompanion.insert(
                nameKey: nameKey,
                id: id,
                displayName: displayName,
                width: width,
                height: height,
                bytes: bytes,
                createdAt: createdAt,
                cachedPath: cachedPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DishImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DishImagesTable,
      DishImageRow,
      $$DishImagesTableFilterComposer,
      $$DishImagesTableOrderingComposer,
      $$DishImagesTableAnnotationComposer,
      $$DishImagesTableCreateCompanionBuilder,
      $$DishImagesTableUpdateCompanionBuilder,
      (
        DishImageRow,
        BaseReferences<_$AppDatabase, $DishImagesTable, DishImageRow>,
      ),
      DishImageRow,
      PrefetchHooks Function()
    >;
typedef $$MuscleRegionsTableCreateCompanionBuilder =
    MuscleRegionsCompanion Function({
      required String id,
      required String muscleGroup,
      required String view,
      required int sortOrder,
      Value<int> rowid,
    });
typedef $$MuscleRegionsTableUpdateCompanionBuilder =
    MuscleRegionsCompanion Function({
      Value<String> id,
      Value<String> muscleGroup,
      Value<String> view,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$MuscleRegionsTableFilterComposer
    extends Composer<_$AppDatabase, $MuscleRegionsTable> {
  $$MuscleRegionsTableFilterComposer({
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

  ColumnFilters<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get view => $composableBuilder(
    column: $table.view,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MuscleRegionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MuscleRegionsTable> {
  $$MuscleRegionsTableOrderingComposer({
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

  ColumnOrderings<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get view => $composableBuilder(
    column: $table.view,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MuscleRegionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MuscleRegionsTable> {
  $$MuscleRegionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get view =>
      $composableBuilder(column: $table.view, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$MuscleRegionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MuscleRegionsTable,
          MuscleRegionRow,
          $$MuscleRegionsTableFilterComposer,
          $$MuscleRegionsTableOrderingComposer,
          $$MuscleRegionsTableAnnotationComposer,
          $$MuscleRegionsTableCreateCompanionBuilder,
          $$MuscleRegionsTableUpdateCompanionBuilder,
          (
            MuscleRegionRow,
            BaseReferences<_$AppDatabase, $MuscleRegionsTable, MuscleRegionRow>,
          ),
          MuscleRegionRow,
          PrefetchHooks Function()
        > {
  $$MuscleRegionsTableTableManager(_$AppDatabase db, $MuscleRegionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MuscleRegionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MuscleRegionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MuscleRegionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> muscleGroup = const Value.absent(),
                Value<String> view = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MuscleRegionsCompanion(
                id: id,
                muscleGroup: muscleGroup,
                view: view,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String muscleGroup,
                required String view,
                required int sortOrder,
                Value<int> rowid = const Value.absent(),
              }) => MuscleRegionsCompanion.insert(
                id: id,
                muscleGroup: muscleGroup,
                view: view,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MuscleRegionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MuscleRegionsTable,
      MuscleRegionRow,
      $$MuscleRegionsTableFilterComposer,
      $$MuscleRegionsTableOrderingComposer,
      $$MuscleRegionsTableAnnotationComposer,
      $$MuscleRegionsTableCreateCompanionBuilder,
      $$MuscleRegionsTableUpdateCompanionBuilder,
      (
        MuscleRegionRow,
        BaseReferences<_$AppDatabase, $MuscleRegionsTable, MuscleRegionRow>,
      ),
      MuscleRegionRow,
      PrefetchHooks Function()
    >;
typedef $$ExercisesTableCreateCompanionBuilder =
    ExercisesCompanion Function({
      required String id,
      required String muscleGroup,
      required String muscleRegion,
      required String equipment,
      required bool logsWeight,
      required String nameVi,
      Value<String?> nameEn,
      required String youtubeVideoId,
      required String videoChannel,
      Value<int?> videoDurationS,
      required bool videoAvailable,
      Value<DateTime?> videoCheckedAt,
      Value<String?> videoUnavailableReason,
      required String guideSteps,
      required String guideSafety,
      required String approvedAt,
      required int sortOrder,
      required bool active,
      Value<int> rowid,
    });
typedef $$ExercisesTableUpdateCompanionBuilder =
    ExercisesCompanion Function({
      Value<String> id,
      Value<String> muscleGroup,
      Value<String> muscleRegion,
      Value<String> equipment,
      Value<bool> logsWeight,
      Value<String> nameVi,
      Value<String?> nameEn,
      Value<String> youtubeVideoId,
      Value<String> videoChannel,
      Value<int?> videoDurationS,
      Value<bool> videoAvailable,
      Value<DateTime?> videoCheckedAt,
      Value<String?> videoUnavailableReason,
      Value<String> guideSteps,
      Value<String> guideSafety,
      Value<String> approvedAt,
      Value<int> sortOrder,
      Value<bool> active,
      Value<int> rowid,
    });

class $$ExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
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

  ColumnFilters<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get muscleRegion => $composableBuilder(
    column: $table.muscleRegion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get logsWeight => $composableBuilder(
    column: $table.logsWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameVi => $composableBuilder(
    column: $table.nameVi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameEn => $composableBuilder(
    column: $table.nameEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get youtubeVideoId => $composableBuilder(
    column: $table.youtubeVideoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoChannel => $composableBuilder(
    column: $table.videoChannel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get videoDurationS => $composableBuilder(
    column: $table.videoDurationS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get videoAvailable => $composableBuilder(
    column: $table.videoAvailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get videoCheckedAt => $composableBuilder(
    column: $table.videoCheckedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoUnavailableReason => $composableBuilder(
    column: $table.videoUnavailableReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guideSteps => $composableBuilder(
    column: $table.guideSteps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guideSafety => $composableBuilder(
    column: $table.guideSafety,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvedAt => $composableBuilder(
    column: $table.approvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
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

  ColumnOrderings<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get muscleRegion => $composableBuilder(
    column: $table.muscleRegion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get logsWeight => $composableBuilder(
    column: $table.logsWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameVi => $composableBuilder(
    column: $table.nameVi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameEn => $composableBuilder(
    column: $table.nameEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get youtubeVideoId => $composableBuilder(
    column: $table.youtubeVideoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoChannel => $composableBuilder(
    column: $table.videoChannel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get videoDurationS => $composableBuilder(
    column: $table.videoDurationS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get videoAvailable => $composableBuilder(
    column: $table.videoAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get videoCheckedAt => $composableBuilder(
    column: $table.videoCheckedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoUnavailableReason => $composableBuilder(
    column: $table.videoUnavailableReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guideSteps => $composableBuilder(
    column: $table.guideSteps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guideSafety => $composableBuilder(
    column: $table.guideSafety,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvedAt => $composableBuilder(
    column: $table.approvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get muscleRegion => $composableBuilder(
    column: $table.muscleRegion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get equipment =>
      $composableBuilder(column: $table.equipment, builder: (column) => column);

  GeneratedColumn<bool> get logsWeight => $composableBuilder(
    column: $table.logsWeight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nameVi =>
      $composableBuilder(column: $table.nameVi, builder: (column) => column);

  GeneratedColumn<String> get nameEn =>
      $composableBuilder(column: $table.nameEn, builder: (column) => column);

  GeneratedColumn<String> get youtubeVideoId => $composableBuilder(
    column: $table.youtubeVideoId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoChannel => $composableBuilder(
    column: $table.videoChannel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get videoDurationS => $composableBuilder(
    column: $table.videoDurationS,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get videoAvailable => $composableBuilder(
    column: $table.videoAvailable,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get videoCheckedAt => $composableBuilder(
    column: $table.videoCheckedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoUnavailableReason => $composableBuilder(
    column: $table.videoUnavailableReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get guideSteps => $composableBuilder(
    column: $table.guideSteps,
    builder: (column) => column,
  );

  GeneratedColumn<String> get guideSafety => $composableBuilder(
    column: $table.guideSafety,
    builder: (column) => column,
  );

  GeneratedColumn<String> get approvedAt => $composableBuilder(
    column: $table.approvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExercisesTable,
          ExerciseRow,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (
            ExerciseRow,
            BaseReferences<_$AppDatabase, $ExercisesTable, ExerciseRow>,
          ),
          ExerciseRow,
          PrefetchHooks Function()
        > {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> muscleGroup = const Value.absent(),
                Value<String> muscleRegion = const Value.absent(),
                Value<String> equipment = const Value.absent(),
                Value<bool> logsWeight = const Value.absent(),
                Value<String> nameVi = const Value.absent(),
                Value<String?> nameEn = const Value.absent(),
                Value<String> youtubeVideoId = const Value.absent(),
                Value<String> videoChannel = const Value.absent(),
                Value<int?> videoDurationS = const Value.absent(),
                Value<bool> videoAvailable = const Value.absent(),
                Value<DateTime?> videoCheckedAt = const Value.absent(),
                Value<String?> videoUnavailableReason = const Value.absent(),
                Value<String> guideSteps = const Value.absent(),
                Value<String> guideSafety = const Value.absent(),
                Value<String> approvedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                muscleGroup: muscleGroup,
                muscleRegion: muscleRegion,
                equipment: equipment,
                logsWeight: logsWeight,
                nameVi: nameVi,
                nameEn: nameEn,
                youtubeVideoId: youtubeVideoId,
                videoChannel: videoChannel,
                videoDurationS: videoDurationS,
                videoAvailable: videoAvailable,
                videoCheckedAt: videoCheckedAt,
                videoUnavailableReason: videoUnavailableReason,
                guideSteps: guideSteps,
                guideSafety: guideSafety,
                approvedAt: approvedAt,
                sortOrder: sortOrder,
                active: active,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String muscleGroup,
                required String muscleRegion,
                required String equipment,
                required bool logsWeight,
                required String nameVi,
                Value<String?> nameEn = const Value.absent(),
                required String youtubeVideoId,
                required String videoChannel,
                Value<int?> videoDurationS = const Value.absent(),
                required bool videoAvailable,
                Value<DateTime?> videoCheckedAt = const Value.absent(),
                Value<String?> videoUnavailableReason = const Value.absent(),
                required String guideSteps,
                required String guideSafety,
                required String approvedAt,
                required int sortOrder,
                required bool active,
                Value<int> rowid = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                muscleGroup: muscleGroup,
                muscleRegion: muscleRegion,
                equipment: equipment,
                logsWeight: logsWeight,
                nameVi: nameVi,
                nameEn: nameEn,
                youtubeVideoId: youtubeVideoId,
                videoChannel: videoChannel,
                videoDurationS: videoDurationS,
                videoAvailable: videoAvailable,
                videoCheckedAt: videoCheckedAt,
                videoUnavailableReason: videoUnavailableReason,
                guideSteps: guideSteps,
                guideSafety: guideSafety,
                approvedAt: approvedAt,
                sortOrder: sortOrder,
                active: active,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExercisesTable,
      ExerciseRow,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (
        ExerciseRow,
        BaseReferences<_$AppDatabase, $ExercisesTable, ExerciseRow>,
      ),
      ExerciseRow,
      PrefetchHooks Function()
    >;
typedef $$LiftLogsTableCreateCompanionBuilder =
    LiftLogsCompanion Function({
      required String date,
      required String exerciseId,
      required int startKgX10,
      required int endKgX10,
      Value<int> rowid,
    });
typedef $$LiftLogsTableUpdateCompanionBuilder =
    LiftLogsCompanion Function({
      Value<String> date,
      Value<String> exerciseId,
      Value<int> startKgX10,
      Value<int> endKgX10,
      Value<int> rowid,
    });

class $$LiftLogsTableFilterComposer
    extends Composer<_$AppDatabase, $LiftLogsTable> {
  $$LiftLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startKgX10 => $composableBuilder(
    column: $table.startKgX10,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endKgX10 => $composableBuilder(
    column: $table.endKgX10,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LiftLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $LiftLogsTable> {
  $$LiftLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startKgX10 => $composableBuilder(
    column: $table.startKgX10,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endKgX10 => $composableBuilder(
    column: $table.endKgX10,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LiftLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LiftLogsTable> {
  $$LiftLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startKgX10 => $composableBuilder(
    column: $table.startKgX10,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endKgX10 =>
      $composableBuilder(column: $table.endKgX10, builder: (column) => column);
}

class $$LiftLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LiftLogsTable,
          LiftLogRow,
          $$LiftLogsTableFilterComposer,
          $$LiftLogsTableOrderingComposer,
          $$LiftLogsTableAnnotationComposer,
          $$LiftLogsTableCreateCompanionBuilder,
          $$LiftLogsTableUpdateCompanionBuilder,
          (
            LiftLogRow,
            BaseReferences<_$AppDatabase, $LiftLogsTable, LiftLogRow>,
          ),
          LiftLogRow,
          PrefetchHooks Function()
        > {
  $$LiftLogsTableTableManager(_$AppDatabase db, $LiftLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LiftLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LiftLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LiftLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<int> startKgX10 = const Value.absent(),
                Value<int> endKgX10 = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LiftLogsCompanion(
                date: date,
                exerciseId: exerciseId,
                startKgX10: startKgX10,
                endKgX10: endKgX10,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                required String exerciseId,
                required int startKgX10,
                required int endKgX10,
                Value<int> rowid = const Value.absent(),
              }) => LiftLogsCompanion.insert(
                date: date,
                exerciseId: exerciseId,
                startKgX10: startKgX10,
                endKgX10: endKgX10,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LiftLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LiftLogsTable,
      LiftLogRow,
      $$LiftLogsTableFilterComposer,
      $$LiftLogsTableOrderingComposer,
      $$LiftLogsTableAnnotationComposer,
      $$LiftLogsTableCreateCompanionBuilder,
      $$LiftLogsTableUpdateCompanionBuilder,
      (LiftLogRow, BaseReferences<_$AppDatabase, $LiftLogsTable, LiftLogRow>),
      LiftLogRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$AccountTableTableManager get account =>
      $$AccountTableTableManager(_db, _db.account);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$WeightsTableTableManager get weights =>
      $$WeightsTableTableManager(_db, _db.weights);
  $$OnboardingDraftTableTableManager get onboardingDraft =>
      $$OnboardingDraftTableTableManager(_db, _db.onboardingDraft);
  $$WeeklyTemplatesTableTableManager get weeklyTemplates =>
      $$WeeklyTemplatesTableTableManager(_db, _db.weeklyTemplates);
  $$MonthPlansTableTableManager get monthPlans =>
      $$MonthPlansTableTableManager(_db, _db.monthPlans);
  $$DaysTableTableManager get days => $$DaysTableTableManager(_db, _db.days);
  $$MenusTableTableManager get menus =>
      $$MenusTableTableManager(_db, _db.menus);
  $$AiDailyUsageTableTableManager get aiDailyUsage =>
      $$AiDailyUsageTableTableManager(_db, _db.aiDailyUsage);
  $$DishImagesTableTableManager get dishImages =>
      $$DishImagesTableTableManager(_db, _db.dishImages);
  $$MuscleRegionsTableTableManager get muscleRegions =>
      $$MuscleRegionsTableTableManager(_db, _db.muscleRegions);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$LiftLogsTableTableManager get liftLogs =>
      $$LiftLogsTableTableManager(_db, _db.liftLogs);
}
