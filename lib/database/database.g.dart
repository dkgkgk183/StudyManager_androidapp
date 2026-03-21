// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SubjectCategoriesTable extends SubjectCategories
    with TableInfo<$SubjectCategoriesTable, SubjectCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectCategoriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subject_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubjectCategory> instance, {
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
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubjectCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubjectCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $SubjectCategoriesTable createAlias(String alias) {
    return $SubjectCategoriesTable(attachedDatabase, alias);
  }
}

class SubjectCategory extends DataClass implements Insertable<SubjectCategory> {
  final String id;
  final String name;
  final int sortOrder;
  const SubjectCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  SubjectCategoriesCompanion toCompanion(bool nullToAbsent) {
    return SubjectCategoriesCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
    );
  }

  factory SubjectCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubjectCategory(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  SubjectCategory copyWith({String? id, String? name, int? sortOrder}) =>
      SubjectCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  SubjectCategory copyWithCompanion(SubjectCategoriesCompanion data) {
    return SubjectCategory(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubjectCategory(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubjectCategory &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder);
}

class SubjectCategoriesCompanion extends UpdateCompanion<SubjectCategory> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const SubjectCategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubjectCategoriesCompanion.insert({
    required String id,
    required String name,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<SubjectCategory> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubjectCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return SubjectCategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
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
    return (StringBuffer('SubjectCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubjectsTable extends Subjects with TableInfo<$SubjectsTable, Subject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#4CAF50'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, categoryId, name, colorHex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subjects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Subject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
    );
  }

  @override
  $SubjectsTable createAlias(String alias) {
    return $SubjectsTable(attachedDatabase, alias);
  }
}

class Subject extends DataClass implements Insertable<Subject> {
  final String id;
  final String? categoryId;
  final String name;
  final String colorHex;
  const Subject({
    required this.id,
    this.categoryId,
    required this.name,
    required this.colorHex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['name'] = Variable<String>(name);
    map['color_hex'] = Variable<String>(colorHex);
    return map;
  }

  SubjectsCompanion toCompanion(bool nullToAbsent) {
    return SubjectsCompanion(
      id: Value(id),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      name: Value(name),
      colorHex: Value(colorHex),
    );
  }

  factory Subject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subject(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String?>(categoryId),
      'name': serializer.toJson<String>(name),
      'colorHex': serializer.toJson<String>(colorHex),
    };
  }

  Subject copyWith({
    String? id,
    Value<String?> categoryId = const Value.absent(),
    String? name,
    String? colorHex,
  }) => Subject(
    id: id ?? this.id,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    name: name ?? this.name,
    colorHex: colorHex ?? this.colorHex,
  );
  Subject copyWithCompanion(SubjectsCompanion data) {
    return Subject(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subject(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, categoryId, name, colorHex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subject &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.colorHex == this.colorHex);
}

class SubjectsCompanion extends UpdateCompanion<Subject> {
  final Value<String> id;
  final Value<String?> categoryId;
  final Value<String> name;
  final Value<String> colorHex;
  final Value<int> rowid;
  const SubjectsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubjectsCompanion.insert({
    required String id,
    this.categoryId = const Value.absent(),
    required String name,
    this.colorHex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Subject> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<String>? colorHex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (colorHex != null) 'color_hex': colorHex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubjectsCompanion copyWith({
    Value<String>? id,
    Value<String?>? categoryId,
    Value<String>? name,
    Value<String>? colorHex,
    Value<int>? rowid,
  }) {
    return SubjectsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudyPlansTable extends StudyPlans
    with TableInfo<$StudyPlansTable, StudyPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudyPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetDateMeta = const VerificationMeta(
    'targetDate',
  );
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
    'target_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalMinutesMeta = const VerificationMeta(
    'goalMinutes',
  );
  @override
  late final GeneratedColumn<int> goalMinutes = GeneratedColumn<int>(
    'goal_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    targetDate,
    goalMinutes,
    memo,
    isCompleted,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudyPlan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('target_date')) {
      context.handle(
        _targetDateMeta,
        targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta),
      );
    } else if (isInserting) {
      context.missing(_targetDateMeta);
    }
    if (data.containsKey('goal_minutes')) {
      context.handle(
        _goalMinutesMeta,
        goalMinutes.isAcceptableOrUnknown(
          data['goal_minutes']!,
          _goalMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_goalMinutesMeta);
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
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
  StudyPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyPlan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      targetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}target_date'],
      )!,
      goalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goal_minutes'],
      )!,
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StudyPlansTable createAlias(String alias) {
    return $StudyPlansTable(attachedDatabase, alias);
  }
}

class StudyPlan extends DataClass implements Insertable<StudyPlan> {
  final String id;
  final String subjectId;
  final DateTime targetDate;
  final int goalMinutes;
  final String memo;
  final bool isCompleted;
  final DateTime createdAt;
  const StudyPlan({
    required this.id,
    required this.subjectId,
    required this.targetDate,
    required this.goalMinutes,
    required this.memo,
    required this.isCompleted,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['subject_id'] = Variable<String>(subjectId);
    map['target_date'] = Variable<DateTime>(targetDate);
    map['goal_minutes'] = Variable<int>(goalMinutes);
    map['memo'] = Variable<String>(memo);
    map['is_completed'] = Variable<bool>(isCompleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StudyPlansCompanion toCompanion(bool nullToAbsent) {
    return StudyPlansCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      targetDate: Value(targetDate),
      goalMinutes: Value(goalMinutes),
      memo: Value(memo),
      isCompleted: Value(isCompleted),
      createdAt: Value(createdAt),
    );
  }

  factory StudyPlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudyPlan(
      id: serializer.fromJson<String>(json['id']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      targetDate: serializer.fromJson<DateTime>(json['targetDate']),
      goalMinutes: serializer.fromJson<int>(json['goalMinutes']),
      memo: serializer.fromJson<String>(json['memo']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'subjectId': serializer.toJson<String>(subjectId),
      'targetDate': serializer.toJson<DateTime>(targetDate),
      'goalMinutes': serializer.toJson<int>(goalMinutes),
      'memo': serializer.toJson<String>(memo),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StudyPlan copyWith({
    String? id,
    String? subjectId,
    DateTime? targetDate,
    int? goalMinutes,
    String? memo,
    bool? isCompleted,
    DateTime? createdAt,
  }) => StudyPlan(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    targetDate: targetDate ?? this.targetDate,
    goalMinutes: goalMinutes ?? this.goalMinutes,
    memo: memo ?? this.memo,
    isCompleted: isCompleted ?? this.isCompleted,
    createdAt: createdAt ?? this.createdAt,
  );
  StudyPlan copyWithCompanion(StudyPlansCompanion data) {
    return StudyPlan(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      targetDate: data.targetDate.present
          ? data.targetDate.value
          : this.targetDate,
      goalMinutes: data.goalMinutes.present
          ? data.goalMinutes.value
          : this.goalMinutes,
      memo: data.memo.present ? data.memo.value : this.memo,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudyPlan(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('targetDate: $targetDate, ')
          ..write('goalMinutes: $goalMinutes, ')
          ..write('memo: $memo, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subjectId,
    targetDate,
    goalMinutes,
    memo,
    isCompleted,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyPlan &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.targetDate == this.targetDate &&
          other.goalMinutes == this.goalMinutes &&
          other.memo == this.memo &&
          other.isCompleted == this.isCompleted &&
          other.createdAt == this.createdAt);
}

class StudyPlansCompanion extends UpdateCompanion<StudyPlan> {
  final Value<String> id;
  final Value<String> subjectId;
  final Value<DateTime> targetDate;
  final Value<int> goalMinutes;
  final Value<String> memo;
  final Value<bool> isCompleted;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const StudyPlansCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.goalMinutes = const Value.absent(),
    this.memo = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudyPlansCompanion.insert({
    required String id,
    required String subjectId,
    required DateTime targetDate,
    required int goalMinutes,
    this.memo = const Value.absent(),
    this.isCompleted = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       subjectId = Value(subjectId),
       targetDate = Value(targetDate),
       goalMinutes = Value(goalMinutes),
       createdAt = Value(createdAt);
  static Insertable<StudyPlan> custom({
    Expression<String>? id,
    Expression<String>? subjectId,
    Expression<DateTime>? targetDate,
    Expression<int>? goalMinutes,
    Expression<String>? memo,
    Expression<bool>? isCompleted,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (targetDate != null) 'target_date': targetDate,
      if (goalMinutes != null) 'goal_minutes': goalMinutes,
      if (memo != null) 'memo': memo,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudyPlansCompanion copyWith({
    Value<String>? id,
    Value<String>? subjectId,
    Value<DateTime>? targetDate,
    Value<int>? goalMinutes,
    Value<String>? memo,
    Value<bool>? isCompleted,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return StudyPlansCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      targetDate: targetDate ?? this.targetDate,
      goalMinutes: goalMinutes ?? this.goalMinutes,
      memo: memo ?? this.memo,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (goalMinutes.present) {
      map['goal_minutes'] = Variable<int>(goalMinutes.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudyPlansCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('targetDate: $targetDate, ')
          ..write('goalMinutes: $goalMinutes, ')
          ..write('memo: $memo, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudySessionsTable extends StudySessions
    with TableInfo<$StudySessionsTable, StudySession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudySessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _trayOpenCountMeta = const VerificationMeta(
    'trayOpenCount',
  );
  @override
  late final GeneratedColumn<int> trayOpenCount = GeneratedColumn<int>(
    'tray_open_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _selfScoreMeta = const VerificationMeta(
    'selfScore',
  );
  @override
  late final GeneratedColumn<int> selfScore = GeneratedColumn<int>(
    'self_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    planId,
    startTime,
    endTime,
    durationSeconds,
    trayOpenCount,
    selfScore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudySession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('tray_open_count')) {
      context.handle(
        _trayOpenCountMeta,
        trayOpenCount.isAcceptableOrUnknown(
          data['tray_open_count']!,
          _trayOpenCountMeta,
        ),
      );
    }
    if (data.containsKey('self_score')) {
      context.handle(
        _selfScoreMeta,
        selfScore.isAcceptableOrUnknown(data['self_score']!, _selfScoreMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudySession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudySession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      ),
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      trayOpenCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tray_open_count'],
      )!,
      selfScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}self_score'],
      )!,
    );
  }

  @override
  $StudySessionsTable createAlias(String alias) {
    return $StudySessionsTable(attachedDatabase, alias);
  }
}

class StudySession extends DataClass implements Insertable<StudySession> {
  final String id;
  final String subjectId;
  final String? planId;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final int trayOpenCount;
  final int selfScore;
  const StudySession({
    required this.id,
    required this.subjectId,
    this.planId,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    required this.trayOpenCount,
    required this.selfScore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['subject_id'] = Variable<String>(subjectId);
    if (!nullToAbsent || planId != null) {
      map['plan_id'] = Variable<String>(planId);
    }
    map['start_time'] = Variable<DateTime>(startTime);
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['tray_open_count'] = Variable<int>(trayOpenCount);
    map['self_score'] = Variable<int>(selfScore);
    return map;
  }

  StudySessionsCompanion toCompanion(bool nullToAbsent) {
    return StudySessionsCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      planId: planId == null && nullToAbsent
          ? const Value.absent()
          : Value(planId),
      startTime: Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      durationSeconds: Value(durationSeconds),
      trayOpenCount: Value(trayOpenCount),
      selfScore: Value(selfScore),
    );
  }

  factory StudySession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudySession(
      id: serializer.fromJson<String>(json['id']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      planId: serializer.fromJson<String?>(json['planId']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      trayOpenCount: serializer.fromJson<int>(json['trayOpenCount']),
      selfScore: serializer.fromJson<int>(json['selfScore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'subjectId': serializer.toJson<String>(subjectId),
      'planId': serializer.toJson<String?>(planId),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'trayOpenCount': serializer.toJson<int>(trayOpenCount),
      'selfScore': serializer.toJson<int>(selfScore),
    };
  }

  StudySession copyWith({
    String? id,
    String? subjectId,
    Value<String?> planId = const Value.absent(),
    DateTime? startTime,
    Value<DateTime?> endTime = const Value.absent(),
    int? durationSeconds,
    int? trayOpenCount,
    int? selfScore,
  }) => StudySession(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    planId: planId.present ? planId.value : this.planId,
    startTime: startTime ?? this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    trayOpenCount: trayOpenCount ?? this.trayOpenCount,
    selfScore: selfScore ?? this.selfScore,
  );
  StudySession copyWithCompanion(StudySessionsCompanion data) {
    return StudySession(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      planId: data.planId.present ? data.planId.value : this.planId,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      trayOpenCount: data.trayOpenCount.present
          ? data.trayOpenCount.value
          : this.trayOpenCount,
      selfScore: data.selfScore.present ? data.selfScore.value : this.selfScore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudySession(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('planId: $planId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('trayOpenCount: $trayOpenCount, ')
          ..write('selfScore: $selfScore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subjectId,
    planId,
    startTime,
    endTime,
    durationSeconds,
    trayOpenCount,
    selfScore,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudySession &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.planId == this.planId &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.durationSeconds == this.durationSeconds &&
          other.trayOpenCount == this.trayOpenCount &&
          other.selfScore == this.selfScore);
}

class StudySessionsCompanion extends UpdateCompanion<StudySession> {
  final Value<String> id;
  final Value<String> subjectId;
  final Value<String?> planId;
  final Value<DateTime> startTime;
  final Value<DateTime?> endTime;
  final Value<int> durationSeconds;
  final Value<int> trayOpenCount;
  final Value<int> selfScore;
  final Value<int> rowid;
  const StudySessionsCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.planId = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.trayOpenCount = const Value.absent(),
    this.selfScore = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudySessionsCompanion.insert({
    required String id,
    required String subjectId,
    this.planId = const Value.absent(),
    required DateTime startTime,
    this.endTime = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.trayOpenCount = const Value.absent(),
    this.selfScore = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       subjectId = Value(subjectId),
       startTime = Value(startTime);
  static Insertable<StudySession> custom({
    Expression<String>? id,
    Expression<String>? subjectId,
    Expression<String>? planId,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<int>? durationSeconds,
    Expression<int>? trayOpenCount,
    Expression<int>? selfScore,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (planId != null) 'plan_id': planId,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (trayOpenCount != null) 'tray_open_count': trayOpenCount,
      if (selfScore != null) 'self_score': selfScore,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudySessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? subjectId,
    Value<String?>? planId,
    Value<DateTime>? startTime,
    Value<DateTime?>? endTime,
    Value<int>? durationSeconds,
    Value<int>? trayOpenCount,
    Value<int>? selfScore,
    Value<int>? rowid,
  }) {
    return StudySessionsCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      planId: planId ?? this.planId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      trayOpenCount: trayOpenCount ?? this.trayOpenCount,
      selfScore: selfScore ?? this.selfScore,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (trayOpenCount.present) {
      map['tray_open_count'] = Variable<int>(trayOpenCount.value);
    }
    if (selfScore.present) {
      map['self_score'] = Variable<int>(selfScore.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudySessionsCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('planId: $planId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('trayOpenCount: $trayOpenCount, ')
          ..write('selfScore: $selfScore, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PomodoroSettingsTable extends PomodoroSettings
    with TableInfo<$PomodoroSettingsTable, PomodoroSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PomodoroSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _focusMinutesMeta = const VerificationMeta(
    'focusMinutes',
  );
  @override
  late final GeneratedColumn<int> focusMinutes = GeneratedColumn<int>(
    'focus_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(25),
  );
  static const VerificationMeta _breakMinutesMeta = const VerificationMeta(
    'breakMinutes',
  );
  @override
  late final GeneratedColumn<int> breakMinutes = GeneratedColumn<int>(
    'break_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _longBreakMinutesMeta = const VerificationMeta(
    'longBreakMinutes',
  );
  @override
  late final GeneratedColumn<int> longBreakMinutes = GeneratedColumn<int>(
    'long_break_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(15),
  );
  static const VerificationMeta _sessionsBeforeLongBreakMeta =
      const VerificationMeta('sessionsBeforeLongBreak');
  @override
  late final GeneratedColumn<int> sessionsBeforeLongBreak =
      GeneratedColumn<int>(
        'sessions_before_long_break',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(4),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    focusMinutes,
    breakMinutes,
    longBreakMinutes,
    sessionsBeforeLongBreak,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pomodoro_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<PomodoroSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('focus_minutes')) {
      context.handle(
        _focusMinutesMeta,
        focusMinutes.isAcceptableOrUnknown(
          data['focus_minutes']!,
          _focusMinutesMeta,
        ),
      );
    }
    if (data.containsKey('break_minutes')) {
      context.handle(
        _breakMinutesMeta,
        breakMinutes.isAcceptableOrUnknown(
          data['break_minutes']!,
          _breakMinutesMeta,
        ),
      );
    }
    if (data.containsKey('long_break_minutes')) {
      context.handle(
        _longBreakMinutesMeta,
        longBreakMinutes.isAcceptableOrUnknown(
          data['long_break_minutes']!,
          _longBreakMinutesMeta,
        ),
      );
    }
    if (data.containsKey('sessions_before_long_break')) {
      context.handle(
        _sessionsBeforeLongBreakMeta,
        sessionsBeforeLongBreak.isAcceptableOrUnknown(
          data['sessions_before_long_break']!,
          _sessionsBeforeLongBreakMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PomodoroSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PomodoroSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      focusMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}focus_minutes'],
      )!,
      breakMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}break_minutes'],
      )!,
      longBreakMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}long_break_minutes'],
      )!,
      sessionsBeforeLongBreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sessions_before_long_break'],
      )!,
    );
  }

  @override
  $PomodoroSettingsTable createAlias(String alias) {
    return $PomodoroSettingsTable(attachedDatabase, alias);
  }
}

class PomodoroSetting extends DataClass implements Insertable<PomodoroSetting> {
  final String id;
  final int focusMinutes;
  final int breakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;
  const PomodoroSetting({
    required this.id,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.longBreakMinutes,
    required this.sessionsBeforeLongBreak,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['focus_minutes'] = Variable<int>(focusMinutes);
    map['break_minutes'] = Variable<int>(breakMinutes);
    map['long_break_minutes'] = Variable<int>(longBreakMinutes);
    map['sessions_before_long_break'] = Variable<int>(sessionsBeforeLongBreak);
    return map;
  }

  PomodoroSettingsCompanion toCompanion(bool nullToAbsent) {
    return PomodoroSettingsCompanion(
      id: Value(id),
      focusMinutes: Value(focusMinutes),
      breakMinutes: Value(breakMinutes),
      longBreakMinutes: Value(longBreakMinutes),
      sessionsBeforeLongBreak: Value(sessionsBeforeLongBreak),
    );
  }

  factory PomodoroSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PomodoroSetting(
      id: serializer.fromJson<String>(json['id']),
      focusMinutes: serializer.fromJson<int>(json['focusMinutes']),
      breakMinutes: serializer.fromJson<int>(json['breakMinutes']),
      longBreakMinutes: serializer.fromJson<int>(json['longBreakMinutes']),
      sessionsBeforeLongBreak: serializer.fromJson<int>(
        json['sessionsBeforeLongBreak'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'focusMinutes': serializer.toJson<int>(focusMinutes),
      'breakMinutes': serializer.toJson<int>(breakMinutes),
      'longBreakMinutes': serializer.toJson<int>(longBreakMinutes),
      'sessionsBeforeLongBreak': serializer.toJson<int>(
        sessionsBeforeLongBreak,
      ),
    };
  }

  PomodoroSetting copyWith({
    String? id,
    int? focusMinutes,
    int? breakMinutes,
    int? longBreakMinutes,
    int? sessionsBeforeLongBreak,
  }) => PomodoroSetting(
    id: id ?? this.id,
    focusMinutes: focusMinutes ?? this.focusMinutes,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
    sessionsBeforeLongBreak:
        sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
  );
  PomodoroSetting copyWithCompanion(PomodoroSettingsCompanion data) {
    return PomodoroSetting(
      id: data.id.present ? data.id.value : this.id,
      focusMinutes: data.focusMinutes.present
          ? data.focusMinutes.value
          : this.focusMinutes,
      breakMinutes: data.breakMinutes.present
          ? data.breakMinutes.value
          : this.breakMinutes,
      longBreakMinutes: data.longBreakMinutes.present
          ? data.longBreakMinutes.value
          : this.longBreakMinutes,
      sessionsBeforeLongBreak: data.sessionsBeforeLongBreak.present
          ? data.sessionsBeforeLongBreak.value
          : this.sessionsBeforeLongBreak,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PomodoroSetting(')
          ..write('id: $id, ')
          ..write('focusMinutes: $focusMinutes, ')
          ..write('breakMinutes: $breakMinutes, ')
          ..write('longBreakMinutes: $longBreakMinutes, ')
          ..write('sessionsBeforeLongBreak: $sessionsBeforeLongBreak')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    focusMinutes,
    breakMinutes,
    longBreakMinutes,
    sessionsBeforeLongBreak,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PomodoroSetting &&
          other.id == this.id &&
          other.focusMinutes == this.focusMinutes &&
          other.breakMinutes == this.breakMinutes &&
          other.longBreakMinutes == this.longBreakMinutes &&
          other.sessionsBeforeLongBreak == this.sessionsBeforeLongBreak);
}

class PomodoroSettingsCompanion extends UpdateCompanion<PomodoroSetting> {
  final Value<String> id;
  final Value<int> focusMinutes;
  final Value<int> breakMinutes;
  final Value<int> longBreakMinutes;
  final Value<int> sessionsBeforeLongBreak;
  final Value<int> rowid;
  const PomodoroSettingsCompanion({
    this.id = const Value.absent(),
    this.focusMinutes = const Value.absent(),
    this.breakMinutes = const Value.absent(),
    this.longBreakMinutes = const Value.absent(),
    this.sessionsBeforeLongBreak = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PomodoroSettingsCompanion.insert({
    required String id,
    this.focusMinutes = const Value.absent(),
    this.breakMinutes = const Value.absent(),
    this.longBreakMinutes = const Value.absent(),
    this.sessionsBeforeLongBreak = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<PomodoroSetting> custom({
    Expression<String>? id,
    Expression<int>? focusMinutes,
    Expression<int>? breakMinutes,
    Expression<int>? longBreakMinutes,
    Expression<int>? sessionsBeforeLongBreak,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (focusMinutes != null) 'focus_minutes': focusMinutes,
      if (breakMinutes != null) 'break_minutes': breakMinutes,
      if (longBreakMinutes != null) 'long_break_minutes': longBreakMinutes,
      if (sessionsBeforeLongBreak != null)
        'sessions_before_long_break': sessionsBeforeLongBreak,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PomodoroSettingsCompanion copyWith({
    Value<String>? id,
    Value<int>? focusMinutes,
    Value<int>? breakMinutes,
    Value<int>? longBreakMinutes,
    Value<int>? sessionsBeforeLongBreak,
    Value<int>? rowid,
  }) {
    return PomodoroSettingsCompanion(
      id: id ?? this.id,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      sessionsBeforeLongBreak:
          sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (focusMinutes.present) {
      map['focus_minutes'] = Variable<int>(focusMinutes.value);
    }
    if (breakMinutes.present) {
      map['break_minutes'] = Variable<int>(breakMinutes.value);
    }
    if (longBreakMinutes.present) {
      map['long_break_minutes'] = Variable<int>(longBreakMinutes.value);
    }
    if (sessionsBeforeLongBreak.present) {
      map['sessions_before_long_break'] = Variable<int>(
        sessionsBeforeLongBreak.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PomodoroSettingsCompanion(')
          ..write('id: $id, ')
          ..write('focusMinutes: $focusMinutes, ')
          ..write('breakMinutes: $breakMinutes, ')
          ..write('longBreakMinutes: $longBreakMinutes, ')
          ..write('sessionsBeforeLongBreak: $sessionsBeforeLongBreak, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SubjectCategoriesTable subjectCategories =
      $SubjectCategoriesTable(this);
  late final $SubjectsTable subjects = $SubjectsTable(this);
  late final $StudyPlansTable studyPlans = $StudyPlansTable(this);
  late final $StudySessionsTable studySessions = $StudySessionsTable(this);
  late final $PomodoroSettingsTable pomodoroSettings = $PomodoroSettingsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    subjectCategories,
    subjects,
    studyPlans,
    studySessions,
    pomodoroSettings,
  ];
}

typedef $$SubjectCategoriesTableCreateCompanionBuilder =
    SubjectCategoriesCompanion Function({
      required String id,
      required String name,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$SubjectCategoriesTableUpdateCompanionBuilder =
    SubjectCategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$SubjectCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectCategoriesTable> {
  $$SubjectCategoriesTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubjectCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectCategoriesTable> {
  $$SubjectCategoriesTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubjectCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectCategoriesTable> {
  $$SubjectCategoriesTableAnnotationComposer({
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

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$SubjectCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectCategoriesTable,
          SubjectCategory,
          $$SubjectCategoriesTableFilterComposer,
          $$SubjectCategoriesTableOrderingComposer,
          $$SubjectCategoriesTableAnnotationComposer,
          $$SubjectCategoriesTableCreateCompanionBuilder,
          $$SubjectCategoriesTableUpdateCompanionBuilder,
          (
            SubjectCategory,
            BaseReferences<
              _$AppDatabase,
              $SubjectCategoriesTable,
              SubjectCategory
            >,
          ),
          SubjectCategory,
          PrefetchHooks Function()
        > {
  $$SubjectCategoriesTableTableManager(
    _$AppDatabase db,
    $SubjectCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectCategoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectCategoriesCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectCategoriesCompanion.insert(
                id: id,
                name: name,
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

typedef $$SubjectCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectCategoriesTable,
      SubjectCategory,
      $$SubjectCategoriesTableFilterComposer,
      $$SubjectCategoriesTableOrderingComposer,
      $$SubjectCategoriesTableAnnotationComposer,
      $$SubjectCategoriesTableCreateCompanionBuilder,
      $$SubjectCategoriesTableUpdateCompanionBuilder,
      (
        SubjectCategory,
        BaseReferences<_$AppDatabase, $SubjectCategoriesTable, SubjectCategory>,
      ),
      SubjectCategory,
      PrefetchHooks Function()
    >;
typedef $$SubjectsTableCreateCompanionBuilder =
    SubjectsCompanion Function({
      required String id,
      Value<String?> categoryId,
      required String name,
      Value<String> colorHex,
      Value<int> rowid,
    });
typedef $$SubjectsTableUpdateCompanionBuilder =
    SubjectsCompanion Function({
      Value<String> id,
      Value<String?> categoryId,
      Value<String> name,
      Value<String> colorHex,
      Value<int> rowid,
    });

class $$SubjectsTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableFilterComposer({
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

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableOrderingComposer({
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

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);
}

class $$SubjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectsTable,
          Subject,
          $$SubjectsTableFilterComposer,
          $$SubjectsTableOrderingComposer,
          $$SubjectsTableAnnotationComposer,
          $$SubjectsTableCreateCompanionBuilder,
          $$SubjectsTableUpdateCompanionBuilder,
          (Subject, BaseReferences<_$AppDatabase, $SubjectsTable, Subject>),
          Subject,
          PrefetchHooks Function()
        > {
  $$SubjectsTableTableManager(_$AppDatabase db, $SubjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectsCompanion(
                id: id,
                categoryId: categoryId,
                name: name,
                colorHex: colorHex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> categoryId = const Value.absent(),
                required String name,
                Value<String> colorHex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectsCompanion.insert(
                id: id,
                categoryId: categoryId,
                name: name,
                colorHex: colorHex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectsTable,
      Subject,
      $$SubjectsTableFilterComposer,
      $$SubjectsTableOrderingComposer,
      $$SubjectsTableAnnotationComposer,
      $$SubjectsTableCreateCompanionBuilder,
      $$SubjectsTableUpdateCompanionBuilder,
      (Subject, BaseReferences<_$AppDatabase, $SubjectsTable, Subject>),
      Subject,
      PrefetchHooks Function()
    >;
typedef $$StudyPlansTableCreateCompanionBuilder =
    StudyPlansCompanion Function({
      required String id,
      required String subjectId,
      required DateTime targetDate,
      required int goalMinutes,
      Value<String> memo,
      Value<bool> isCompleted,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$StudyPlansTableUpdateCompanionBuilder =
    StudyPlansCompanion Function({
      Value<String> id,
      Value<String> subjectId,
      Value<DateTime> targetDate,
      Value<int> goalMinutes,
      Value<String> memo,
      Value<bool> isCompleted,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$StudyPlansTableFilterComposer
    extends Composer<_$AppDatabase, $StudyPlansTable> {
  $$StudyPlansTableFilterComposer({
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

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalMinutes => $composableBuilder(
    column: $table.goalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudyPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $StudyPlansTable> {
  $$StudyPlansTableOrderingComposer({
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

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalMinutes => $composableBuilder(
    column: $table.goalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudyPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudyPlansTable> {
  $$StudyPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get goalMinutes => $composableBuilder(
    column: $table.goalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$StudyPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudyPlansTable,
          StudyPlan,
          $$StudyPlansTableFilterComposer,
          $$StudyPlansTableOrderingComposer,
          $$StudyPlansTableAnnotationComposer,
          $$StudyPlansTableCreateCompanionBuilder,
          $$StudyPlansTableUpdateCompanionBuilder,
          (
            StudyPlan,
            BaseReferences<_$AppDatabase, $StudyPlansTable, StudyPlan>,
          ),
          StudyPlan,
          PrefetchHooks Function()
        > {
  $$StudyPlansTableTableManager(_$AppDatabase db, $StudyPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudyPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudyPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudyPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<DateTime> targetDate = const Value.absent(),
                Value<int> goalMinutes = const Value.absent(),
                Value<String> memo = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudyPlansCompanion(
                id: id,
                subjectId: subjectId,
                targetDate: targetDate,
                goalMinutes: goalMinutes,
                memo: memo,
                isCompleted: isCompleted,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String subjectId,
                required DateTime targetDate,
                required int goalMinutes,
                Value<String> memo = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => StudyPlansCompanion.insert(
                id: id,
                subjectId: subjectId,
                targetDate: targetDate,
                goalMinutes: goalMinutes,
                memo: memo,
                isCompleted: isCompleted,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudyPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudyPlansTable,
      StudyPlan,
      $$StudyPlansTableFilterComposer,
      $$StudyPlansTableOrderingComposer,
      $$StudyPlansTableAnnotationComposer,
      $$StudyPlansTableCreateCompanionBuilder,
      $$StudyPlansTableUpdateCompanionBuilder,
      (StudyPlan, BaseReferences<_$AppDatabase, $StudyPlansTable, StudyPlan>),
      StudyPlan,
      PrefetchHooks Function()
    >;
typedef $$StudySessionsTableCreateCompanionBuilder =
    StudySessionsCompanion Function({
      required String id,
      required String subjectId,
      Value<String?> planId,
      required DateTime startTime,
      Value<DateTime?> endTime,
      Value<int> durationSeconds,
      Value<int> trayOpenCount,
      Value<int> selfScore,
      Value<int> rowid,
    });
typedef $$StudySessionsTableUpdateCompanionBuilder =
    StudySessionsCompanion Function({
      Value<String> id,
      Value<String> subjectId,
      Value<String?> planId,
      Value<DateTime> startTime,
      Value<DateTime?> endTime,
      Value<int> durationSeconds,
      Value<int> trayOpenCount,
      Value<int> selfScore,
      Value<int> rowid,
    });

class $$StudySessionsTableFilterComposer
    extends Composer<_$AppDatabase, $StudySessionsTable> {
  $$StudySessionsTableFilterComposer({
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

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trayOpenCount => $composableBuilder(
    column: $table.trayOpenCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get selfScore => $composableBuilder(
    column: $table.selfScore,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudySessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudySessionsTable> {
  $$StudySessionsTableOrderingComposer({
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

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trayOpenCount => $composableBuilder(
    column: $table.trayOpenCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get selfScore => $composableBuilder(
    column: $table.selfScore,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudySessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudySessionsTable> {
  $$StudySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trayOpenCount => $composableBuilder(
    column: $table.trayOpenCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get selfScore =>
      $composableBuilder(column: $table.selfScore, builder: (column) => column);
}

class $$StudySessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudySessionsTable,
          StudySession,
          $$StudySessionsTableFilterComposer,
          $$StudySessionsTableOrderingComposer,
          $$StudySessionsTableAnnotationComposer,
          $$StudySessionsTableCreateCompanionBuilder,
          $$StudySessionsTableUpdateCompanionBuilder,
          (
            StudySession,
            BaseReferences<_$AppDatabase, $StudySessionsTable, StudySession>,
          ),
          StudySession,
          PrefetchHooks Function()
        > {
  $$StudySessionsTableTableManager(_$AppDatabase db, $StudySessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudySessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudySessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudySessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String?> planId = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime?> endTime = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> trayOpenCount = const Value.absent(),
                Value<int> selfScore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudySessionsCompanion(
                id: id,
                subjectId: subjectId,
                planId: planId,
                startTime: startTime,
                endTime: endTime,
                durationSeconds: durationSeconds,
                trayOpenCount: trayOpenCount,
                selfScore: selfScore,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String subjectId,
                Value<String?> planId = const Value.absent(),
                required DateTime startTime,
                Value<DateTime?> endTime = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> trayOpenCount = const Value.absent(),
                Value<int> selfScore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudySessionsCompanion.insert(
                id: id,
                subjectId: subjectId,
                planId: planId,
                startTime: startTime,
                endTime: endTime,
                durationSeconds: durationSeconds,
                trayOpenCount: trayOpenCount,
                selfScore: selfScore,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudySessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudySessionsTable,
      StudySession,
      $$StudySessionsTableFilterComposer,
      $$StudySessionsTableOrderingComposer,
      $$StudySessionsTableAnnotationComposer,
      $$StudySessionsTableCreateCompanionBuilder,
      $$StudySessionsTableUpdateCompanionBuilder,
      (
        StudySession,
        BaseReferences<_$AppDatabase, $StudySessionsTable, StudySession>,
      ),
      StudySession,
      PrefetchHooks Function()
    >;
typedef $$PomodoroSettingsTableCreateCompanionBuilder =
    PomodoroSettingsCompanion Function({
      required String id,
      Value<int> focusMinutes,
      Value<int> breakMinutes,
      Value<int> longBreakMinutes,
      Value<int> sessionsBeforeLongBreak,
      Value<int> rowid,
    });
typedef $$PomodoroSettingsTableUpdateCompanionBuilder =
    PomodoroSettingsCompanion Function({
      Value<String> id,
      Value<int> focusMinutes,
      Value<int> breakMinutes,
      Value<int> longBreakMinutes,
      Value<int> sessionsBeforeLongBreak,
      Value<int> rowid,
    });

class $$PomodoroSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $PomodoroSettingsTable> {
  $$PomodoroSettingsTableFilterComposer({
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

  ColumnFilters<int> get focusMinutes => $composableBuilder(
    column: $table.focusMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get breakMinutes => $composableBuilder(
    column: $table.breakMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get longBreakMinutes => $composableBuilder(
    column: $table.longBreakMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionsBeforeLongBreak => $composableBuilder(
    column: $table.sessionsBeforeLongBreak,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PomodoroSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $PomodoroSettingsTable> {
  $$PomodoroSettingsTableOrderingComposer({
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

  ColumnOrderings<int> get focusMinutes => $composableBuilder(
    column: $table.focusMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get breakMinutes => $composableBuilder(
    column: $table.breakMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get longBreakMinutes => $composableBuilder(
    column: $table.longBreakMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionsBeforeLongBreak => $composableBuilder(
    column: $table.sessionsBeforeLongBreak,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PomodoroSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PomodoroSettingsTable> {
  $$PomodoroSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get focusMinutes => $composableBuilder(
    column: $table.focusMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get breakMinutes => $composableBuilder(
    column: $table.breakMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get longBreakMinutes => $composableBuilder(
    column: $table.longBreakMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sessionsBeforeLongBreak => $composableBuilder(
    column: $table.sessionsBeforeLongBreak,
    builder: (column) => column,
  );
}

class $$PomodoroSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PomodoroSettingsTable,
          PomodoroSetting,
          $$PomodoroSettingsTableFilterComposer,
          $$PomodoroSettingsTableOrderingComposer,
          $$PomodoroSettingsTableAnnotationComposer,
          $$PomodoroSettingsTableCreateCompanionBuilder,
          $$PomodoroSettingsTableUpdateCompanionBuilder,
          (
            PomodoroSetting,
            BaseReferences<
              _$AppDatabase,
              $PomodoroSettingsTable,
              PomodoroSetting
            >,
          ),
          PomodoroSetting,
          PrefetchHooks Function()
        > {
  $$PomodoroSettingsTableTableManager(
    _$AppDatabase db,
    $PomodoroSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PomodoroSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PomodoroSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PomodoroSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> focusMinutes = const Value.absent(),
                Value<int> breakMinutes = const Value.absent(),
                Value<int> longBreakMinutes = const Value.absent(),
                Value<int> sessionsBeforeLongBreak = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PomodoroSettingsCompanion(
                id: id,
                focusMinutes: focusMinutes,
                breakMinutes: breakMinutes,
                longBreakMinutes: longBreakMinutes,
                sessionsBeforeLongBreak: sessionsBeforeLongBreak,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> focusMinutes = const Value.absent(),
                Value<int> breakMinutes = const Value.absent(),
                Value<int> longBreakMinutes = const Value.absent(),
                Value<int> sessionsBeforeLongBreak = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PomodoroSettingsCompanion.insert(
                id: id,
                focusMinutes: focusMinutes,
                breakMinutes: breakMinutes,
                longBreakMinutes: longBreakMinutes,
                sessionsBeforeLongBreak: sessionsBeforeLongBreak,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PomodoroSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PomodoroSettingsTable,
      PomodoroSetting,
      $$PomodoroSettingsTableFilterComposer,
      $$PomodoroSettingsTableOrderingComposer,
      $$PomodoroSettingsTableAnnotationComposer,
      $$PomodoroSettingsTableCreateCompanionBuilder,
      $$PomodoroSettingsTableUpdateCompanionBuilder,
      (
        PomodoroSetting,
        BaseReferences<_$AppDatabase, $PomodoroSettingsTable, PomodoroSetting>,
      ),
      PomodoroSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SubjectCategoriesTableTableManager get subjectCategories =>
      $$SubjectCategoriesTableTableManager(_db, _db.subjectCategories);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db, _db.subjects);
  $$StudyPlansTableTableManager get studyPlans =>
      $$StudyPlansTableTableManager(_db, _db.studyPlans);
  $$StudySessionsTableTableManager get studySessions =>
      $$StudySessionsTableTableManager(_db, _db.studySessions);
  $$PomodoroSettingsTableTableManager get pomodoroSettings =>
      $$PomodoroSettingsTableTableManager(_db, _db.pomodoroSettings);
}
