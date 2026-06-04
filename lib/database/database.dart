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

// ── yyyy-MM-dd 포맷 헬퍼 ────────────────────────────────
//
// DateTime → "yyyy-MM-dd" 변환은 여러 곳에서 반복되므로 헬퍼로 통일.
// 이미 "공부일"로 환산된 DateTime(자정 기준)에는 formatDateStr,
// "지금" 기준으로 환산할 때는 formatStudyDateStr 를 사용.

/// DateTime을 "yyyy-MM-dd" 문자열로 변환 (boundary 미적용).
/// 인자는 이미 study day인 자정 DateTime이어야 함.
String formatDateStr(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// DateTime에 6시 경계를 적용한 뒤 "yyyy-MM-dd" 문자열로 변환.
/// DateTime.now() 같이 "실시간" 값을 넣을 때 사용.
String formatStudyDateStr(DateTime dt) => formatDateStr(toStudyDate(dt));

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

// ── 체크리스트 항목 테이블 ─────────────────────────────────
class ChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text()();
  TextColumn get date => text()();           // "yyyy-MM-dd"
  TextColumn get content => text()();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
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
  IntColumn get selfScore => integer().withDefault(const Constant(0))();
  IntColumn get penaltyCount => integer().withDefault(const Constant(0))();
  IntColumn get trayOpenCount => integer().withDefault(const Constant(0))();

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

@DriftDatabase(tables: [SubjectCategories, Subjects, ChecklistItems, StudySessions, PomodoroSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

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
      if (from < 3) {
        await m.createTable(checklistItems);
        await m.addColumn(studySessions, studySessions.penaltyCount);
        await customStatement('DROP TABLE IF EXISTS study_plans');
      }
      if (from < 4) {
        // tray_open_count 컬럼이 실제 DB에 존재할 때만 DROP.
        // v1/v2에서 점프업한 사용자처럼 컬럼이 없는 경우 SQLite가
        // "no such column" 에러를 내며 마이그레이션이 중단되는 것을 방지.
        final cols = await customSelect(
          "PRAGMA table_info(study_sessions)",
          readsFrom: {studySessions},
        ).get();
        final hasTrayOpen = cols.any((r) => r.data['name'] == 'tray_open_count');
        if (hasTrayOpen) {
          await customStatement(
            'ALTER TABLE study_sessions DROP COLUMN tray_open_count',
          );
        }
      }
      if (from < 5) {
        // tray_open_count 재도입: 폰 들어올림 횟수 카운트용.
        // v3 이하에서 v5로 직행하는 경우(컬럼 없음)와 v4에서 DROP이 적용된
        // 경우(컬럼 없음) 모두 안전하게 통과해야 하므로 컬럼 존재 여부 확인 후 추가.
        final cols = await customSelect(
          "PRAGMA table_info(study_sessions)",
          readsFrom: {studySessions},
        ).get();
        final hasTrayOpen = cols.any((r) => r.data['name'] == 'tray_open_count');
        if (!hasTrayOpen) {
          await m.addColumn(studySessions, studySessions.trayOpenCount);
        }
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

  // ── PomodoroSettings ──────────────────────────────────
  Future<PomodoroSetting?> getSettings() =>
      (select(pomodoroSettings)..limit(1)).getSingleOrNull();

  Future<void> saveSettings(PomodoroSettingsCompanion entry) =>
      into(pomodoroSettings).insertOnConflictUpdate(entry);

  // ── 조인 쿼리 ─────────────────────────────────────────
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

  // ── ChecklistItems ────────────────────────────────────
  Future<int> insertChecklistItem(ChecklistItemsCompanion entry) =>
      into(checklistItems).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<ChecklistItem>> getAllChecklistItems() =>
      (select(checklistItems)..orderBy([(t) => OrderingTerm(expression: t.date)])).get();

  Future<List<ChecklistItem>> getChecklistItemsByDate(String date) =>
      (select(checklistItems)
        ..where((t) => t.date.equals(date))
        ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  Selectable<TypedResult> getChecklistItemsWithSubject(String date) {
    return (select(checklistItems).join([
      innerJoin(subjects, subjects.id.equalsExp(checklistItems.subjectId)),
    ])
      ..where(checklistItems.date.equals(date))
      ..orderBy([OrderingTerm.asc(checklistItems.sortOrder)]));
  }

  Future<void> toggleChecklistItem(String id, bool isChecked) =>
      (update(checklistItems)..where((t) => t.id.equals(id)))
          .write(ChecklistItemsCompanion(isChecked: Value(isChecked)));

  Future<bool> updateChecklistItem(ChecklistItem item) =>
      update(checklistItems).replace(item);

  Future<int> deleteChecklistItem(String id) =>
      (delete(checklistItems)..where((t) => t.id.equals(id))).go();

  // 특정 과목의 체크리스트 전체 삭제
  Future<int> deleteChecklistItemsBySubject(String subjectId) =>
      (delete(checklistItems)..where((t) => t.subjectId.equals(subjectId))).go();

  Future<int> deleteChecklistItemsByDate(String date) =>
      (delete(checklistItems)..where((t) => t.date.equals(date))).go();

  Future<Set<DateTime>> getChecklistDatesInMonth(int year, int month) async {
    final start = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
    final end = '${year.toString().padLeft(4, '0')}-${(month + 1).toString().padLeft(2, '0')}-01';
    final items = await (select(checklistItems)
      ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end)))
        .get();
    return items.map((item) {
      final parts = item.date.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }).toSet();
  }

  // ── 전체 초기화 ───────────────────────────────────────
  Future<void> clearAllData() => transaction(() async {
    await delete(studySessions).go();
    await delete(checklistItems).go();
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