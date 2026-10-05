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
  @override
  List<GeneratedColumn> get $columns => [id, cursor, lastSyncedAt];
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
  const SyncStateRow({
    required this.id,
    required this.cursor,
    this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cursor'] = Variable<int>(cursor);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
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
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cursor': serializer.toJson<int>(cursor),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  SyncStateRow copyWith({
    int? id,
    int? cursor,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
  }) => SyncStateRow(
    id: id ?? this.id,
    cursor: cursor ?? this.cursor,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      id: data.id.present ? data.id.value : this.id,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('id: $id, ')
          ..write('cursor: $cursor, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, cursor, lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.id == this.id &&
          other.cursor == this.cursor &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<int> id;
  final Value<int> cursor;
  final Value<DateTime?> lastSyncedAt;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  });
  static Insertable<SyncStateRow> custom({
    Expression<int>? id,
    Expression<int>? cursor,
    Expression<DateTime>? lastSyncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cursor != null) 'cursor': cursor,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
    });
  }

  SyncStateCompanion copyWith({
    Value<int>? id,
    Value<int>? cursor,
    Value<DateTime?>? lastSyncedAt,
  }) {
    return SyncStateCompanion(
      id: id ?? this.id,
      cursor: cursor ?? this.cursor,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('cursor: $cursor, ')
          ..write('lastSyncedAt: $lastSyncedAt')
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
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<int> id,
      Value<int> cursor,
      Value<DateTime?> lastSyncedAt,
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
              }) => SyncStateCompanion(
                id: id,
                cursor: cursor,
                lastSyncedAt: lastSyncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cursor = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
              }) => SyncStateCompanion.insert(
                id: id,
                cursor: cursor,
                lastSyncedAt: lastSyncedAt,
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
}
