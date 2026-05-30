import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ── 오전 6시 기준 하루 경계 헬퍼 ──────────────────────────
const int _dayBoundaryHour = 6; // 오전 6시

DateTime studyDayStart(DateTime calendarDate) =>
    DateTime(calendarDate.year, calendarDate.month, calendarDate.day, _dayBoundaryHour);

DateTime studyDayEnd(DateTime calendarDate) =>
    studyDayStart(calendarDate).add(const Duration(days: 1));

/// 임의 DateTime이 속하는 "공부일"의 달력 날짜 반환
/// (06:00 이전 → 전날)
DateTime toStudyDate(DateTime dt) {
  if (dt.hour < _dayBoundaryHour) {
    final d = DateTime(dt.year, dt.month, dt.day);
    return d.subtract(const Duration(days: 1));
  }
  return DateTime(dt.year, dt.month, dt.day);
}

// ── 카테고리 테이블 (학교공부, 자격증 등) ──────────────────
class SubjectCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 과목 테이블 ───────────────────────────────────────────
class Subjects extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().nullable()(); // nullable = 미분류
  TextColumn get name => text()();
  TextColumn get colorHex => text().withDefault(const Constant('#4CAF50'))();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 공부 계획 테이블 ──────────────────────────────────────
class StudyPlans extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text()();
  DateTimeColumn get targetDate => dateTime()();
  IntColumn get goalMinutes => integer()();
  TextColumn get memo => text().withDefault(const Constant(''))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 실제 공부 세션 테이블 ─────────────────────────────────
class StudySessions extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text()();
  TextColumn get planId => text().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  IntColumn get trayOpenCount => integer().withDefault(const Constant(0))();
  IntColumn get selfScore => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 뽀모도로 설정 테이블 ──────────────────────────────────
class PomodoroSettings extends Table {
  TextColumn get id => text()();
  IntColumn get focusMinutes => integer().withDefault(const Constant(25))();
  IntColumn get breakMinutes => integer().withDefault(const Constant(5))();
  IntColumn get longBreakMinutes => integer().withDefault(const Constant(15))();
  IntColumn get sessionsBeforeLongBreak => integer().withDefault(const Constant(4))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [SubjectCategories, Subjects, StudyPlans, StudySessions, PomodoroSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(subjectCategories);
        await m.addColumn(subjects, subjects.categoryId);
      }
    },
  );

  // ── SubjectCategories ─────────────────────────────────
  Future<int> insertCategory(SubjectCategoriesCompanion entry) =>
      into(subjectCategories).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<SubjectCategory>> getAllCategories() =>
      (select(subjectCategories)
        ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  Future<bool> updateCategory(SubjectCategory category) =>
      update(subjectCategories).replace(category);

  Future<int> deleteCategory(String id) =>
      (delete(subjectCategories)..where((t) => t.id.equals(id))).go();

  // 카테고리 + 소속 과목 한꺼번에 조회
  Future<List<Map<String, dynamic>>> getCategoriesWithSubjects() async {
    final cats = await getAllCategories();
    final allSubs = await getAllSubjects();
    return cats.map((cat) {
      final subs = allSubs.where((s) => s.categoryId == cat.id).toList();
      return {'category': cat, 'subjects': subs};
    }).toList();
  }

  // ── Subjects ──────────────────────────────────────────
  Future<int> insertSubject(SubjectsCompanion entry) =>
      into(subjects).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<Subject>> getAllSubjects() =>
      (select(subjects)..orderBy([(t) => OrderingTerm(expression: t.name)])).get();

  Future<List<Subject>> getSubjectsByCategory(String categoryId) =>
      (select(subjects)
        ..where((t) => t.categoryId.equals(categoryId))
        ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();

  Future<bool> updateSubject(Subject subject) =>
      update(subjects).replace(subject);

  Future<int> deleteSubject(String id) =>
      (delete(subjects)..where((t) => t.id.equals(id))).go();

  // ── StudyPlans ────────────────────────────────────────
  Future<int> insertPlan(StudyPlansCompanion entry) =>
      into(studyPlans).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<StudyPlan>> getAllPlans() =>
      (select(studyPlans)..orderBy([(t) => OrderingTerm(expression: t.targetDate)])).get();

  // DEBUG: 모든 plan의 target_date 확인
  Future<void> debugAllPlanDates() async {
    final result = await customSelect(
      'SELECT id, target_date FROM study_plans ORDER BY target_date',
    ).get();
    for (final row in result) {
      final raw = row.data['target_date'];
      final id = row.data['id'];
      final dt = DateTime.fromMillisecondsSinceEpoch((raw as int) * 1000);
      print('[ALL PLANS] id=$id, raw=$raw, local=$dt, hour=${dt.hour}');
    }
  }

  // DEBUG: raw SQL로 target_date 확인
  Future<void> debugRawTargetDate(String id) async {
    final result = await customSelect(
      'SELECT target_date, typeof(target_date) as col_type FROM study_plans WHERE id = ?',
      variables: [Variable.withString(id)],
    ).get();
    for (final row in result) {
      final raw = row.data['target_date'];
      final type = row.data['col_type'];
      print('[DB RAW] id=$id, target_date=$raw, type=$type');
    }
  }

  Future<List<StudyPlan>> getPlansByDate(DateTime date) {
    final start = studyDayStart(date);
    final end = studyDayEnd(date);
    return (select(studyPlans)
      ..where((t) => t.targetDate.isBiggerOrEqualValue(start) &
      t.targetDate.isSmallerThanValue(end))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  Future<bool> updatePlan(StudyPlan plan) =>
      update(studyPlans).replace(plan);

  Future<int> deletePlan(String id) =>
      (delete(studyPlans)..where((t) => t.id.equals(id))).go();

  Future<void> markPlanCompleted(String id, bool completed) =>
      (update(studyPlans)..where((t) => t.id.equals(id)))
          .write(StudyPlansCompanion(isCompleted: Value(completed)));

  // ── 특정 날짜의 계획 전체 삭제 (캘린더일 기준) ────────
  Future<int> deletePlansByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (delete(studyPlans)
      ..where((t) =>
      t.targetDate.isBiggerOrEqualValue(start) &
      t.targetDate.isSmallerThanValue(end)))
        .go();
  }

  // ── 특정 월의 계획이 존재하는 날짜 Set 반환 ──────────
  Future<Set<DateTime>> getPlanDatesInMonth(int year, int month) async {
    // 캘린더일 기준: 월의 시작은 1일 00:00, 월의 끝은 다음달 1일 00:00
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final plans = await (select(studyPlans)
      ..where((t) =>
      t.targetDate.isBiggerOrEqualValue(start) &
      t.targetDate.isSmallerThanValue(end)))
        .get();
    // 캘린더일 기준으로 반환 (toStudyDate 사용 안 함)
    return plans
        .map((p) => DateTime(p.targetDate.year, p.targetDate.month, p.targetDate.day))
        .toSet();
  }

  // ── StudySessions ─────────────────────────────────────
  Future<int> insertSession(StudySessionsCompanion entry) =>
      into(studySessions).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<StudySession>> getAllSessions() =>
      (select(studySessions)
        ..orderBy([(t) => OrderingTerm(expression: t.startTime, mode: OrderingMode.desc)]))
          .get();

  Future<List<StudySession>> getSessionsByDate(DateTime date) {
    final start = studyDayStart(date);
    final end = studyDayEnd(date);
    return (select(studySessions)
      ..where((t) => t.startTime.isBiggerOrEqualValue(start) &
      t.startTime.isSmallerThanValue(end)))
        .get();
  }

  Future<bool> updateSession(StudySession session) =>
      update(studySessions).replace(session);

  Future<int> deleteSession(String id) =>
      (delete(studySessions)..where((t) => t.id.equals(id))).go();

  // 특정 과목의 세션 전체 삭제
  Future<int> deleteSessionsBySubject(String subjectId) =>
      (delete(studySessions)..where((t) => t.subjectId.equals(subjectId))).go();

  // 특정 과목의 계획 날짜 목록 조회
  Future<List<DateTime>> getPlanDatesBySubject(String subjectId) async {
    final plans = await (select(studyPlans)
      ..where((t) => t.subjectId.equals(subjectId))
      ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]))
        .get();
    return plans.map((p) => p.targetDate).toList();
  }

  // 특정 과목의 계획 전체 삭제
  Future<int> deletePlansBySubject(String subjectId) =>
      (delete(studyPlans)..where((t) => t.subjectId.equals(subjectId))).go();

  // ── PomodoroSettings ──────────────────────────────────
  Future<PomodoroSetting?> getSettings() =>
      (select(pomodoroSettings)..limit(1)).getSingleOrNull();

  Future<void> saveSettings(PomodoroSettingsCompanion entry) =>
      into(pomodoroSettings).insertOnConflictUpdate(entry);

  // ── 조인 쿼리 ─────────────────────────────────────────
  Selectable<TypedResult> getPlansWithSubject(DateTime date) {
    final start = studyDayStart(date);
    final end = studyDayEnd(date);
    return (select(studyPlans).join([
      innerJoin(subjects, subjects.id.equalsExp(studyPlans.subjectId)),
    ])
      ..where(studyPlans.targetDate.isBiggerOrEqualValue(start) &
      studyPlans.targetDate.isSmallerThanValue(end))
      ..orderBy([OrderingTerm.asc(studyPlans.createdAt)]));
  }

  /// 캘린더일 기준(00:00~23:59:59) 쿼리 — 오늘 탭 전용
  Selectable<TypedResult> getPlansWithSubjectByCalendarDay(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(studyPlans).join([
      innerJoin(subjects, subjects.id.equalsExp(studyPlans.subjectId)),
    ])
      ..where(studyPlans.targetDate.isBiggerOrEqualValue(start) &
      studyPlans.targetDate.isSmallerThanValue(end))
      ..orderBy([OrderingTerm.asc(studyPlans.createdAt)]));
  }

  Selectable<TypedResult> getSessionsWithSubject(DateTime date) {
    final start = studyDayStart(date);
    final end = studyDayEnd(date);
    return (select(studySessions).join([
      innerJoin(subjects, subjects.id.equalsExp(studySessions.subjectId)),
    ])
      ..where(studySessions.startTime.isBiggerOrEqualValue(start) &
      studySessions.startTime.isSmallerThanValue(end)));
  }

  Future<List<Map<String, dynamic>>> getTotalSecondsBySubject() async {
    final allSessions = await getAllSessions();
    final allSubjects = await getAllSubjects();
    final Map<String, int> totals = {};
    for (final session in allSessions) {
      totals[session.subjectId] =
          (totals[session.subjectId] ?? 0) + session.durationSeconds;
    }
    return allSubjects.map((sub) {
      return {'subject': sub, 'totalSeconds': totals[sub.id] ?? 0};
    }).toList()
      ..sort((a, b) =>
          (b['totalSeconds'] as int).compareTo(a['totalSeconds'] as int));
  }

  // ── 전체 초기화 ───────────────────────────────────────
  Future<void> clearAllData() => transaction(() async {
    await delete(studySessions).go();
    await delete(studyPlans).go();
    await delete(subjects).go();
    await delete(subjectCategories).go();
  });
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'study_manager.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}