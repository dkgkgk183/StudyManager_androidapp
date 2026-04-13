import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/database.dart';
import '../main.dart';
import '../services/supabase_sync_service.dart';

part 'study_view_model.g.dart';

String _generateId() =>
    '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode.abs()}';

// ─────────────────────────────────────────────────────────────
// 공통 sync 헬퍼 — try/catch 반복 제거
// ─────────────────────────────────────────────────────────────

Future<void> _safeSync(
    String label,
    Future<void> Function(SupabaseSyncService svc) action,
    AppDatabase db,
    ) async {
  try {
    await action(SupabaseSyncService(db));
  } catch (e) {
    debugPrint('[$label] Supabase 동기화 실패: $e');
  }
}

// ─────────────────────────────────────────────────────────────
// CategoryViewModel
// ─────────────────────────────────────────────────────────────

@riverpod
class CategoryViewModel extends _$CategoryViewModel {
  @override
  Future<List<Map<String, dynamic>>> build() =>
      database.getCategoriesWithSubjects();

  Future<void> addCategory(String name) async {
    final cats = await database.getAllCategories();
    final id = _generateId();
    final sortOrder = cats.length;

    await database.insertCategory(SubjectCategoriesCompanion.insert(
      id: id,
      name: name,
      sortOrder: drift.Value(sortOrder),
    ));

    await _safeSync('addCategory', (svc) => svc.syncCategory(
      SubjectCategory(id: id, name: name, sortOrder: sortOrder),
    ), database);

    ref.invalidateSelf();
  }

  Future<void> renameCategory(
      SubjectCategory category, String newName) async {
    final updated = category.copyWith(name: newName);
    await database.updateCategory(updated);
    await _safeSync(
        'renameCategory', (svc) => svc.syncCategory(updated), database);
    ref.invalidateSelf();
  }

  Future<void> deleteCategory(String categoryId) async {
    final subs = await database.getSubjectsByCategory(categoryId);
    for (final sub in subs) {
      await database.deleteSessionsBySubject(sub.id);
      await database.deletePlansBySubject(sub.id);
      await database.deleteSubject(sub.id);

      // 세션/계획도 Supabase에서 삭제
      await _safeSync('deleteCategory/sessions',
              (svc) => _deletePlanAndSessionsBySubject(svc, sub.id), database);
      await _safeSync('deleteCategory/subject',
              (svc) => svc.deleteSubject(sub.id), database);
    }

    await database.deleteCategory(categoryId);
    await _safeSync('deleteCategory',
            (svc) => svc.deleteCategory(categoryId), database);

    ref.invalidateSelf();
    ref.invalidate(subjectViewModelProvider);
    ref.invalidate(studySessionViewModelProvider(DateTime.now()));
    ref.invalidate(statsViewModelProvider);
  }

  Future<void> addSubjectToCategory({
    required String categoryId,
    required String name,
    required String colorHex,
  }) async {
    final id = _generateId();
    await database.insertSubject(SubjectsCompanion.insert(
      id: id,
      categoryId: drift.Value(categoryId),
      name: name,
      colorHex: drift.Value(colorHex),
    ));

    await _safeSync('addSubjectToCategory', (svc) => svc.syncSubject(
      Subject(id: id, categoryId: categoryId, name: name, colorHex: colorHex),
    ), database);

    ref.invalidateSelf();
    ref.invalidate(subjectViewModelProvider);
    ref.invalidate(statsViewModelProvider);
  }
}

// Supabase에서 특정 과목의 계획/세션 삭제 (DB 조회 후 일괄 삭제)
Future<void> _deletePlanAndSessionsBySubject(
    SupabaseSyncService svc, String subjectId) async {
  final db = database;
  final plans = await db.getAllPlans();
  for (final p in plans.where((p) => p.subjectId == subjectId)) {
    await svc.deletePlan(p.id);
  }
  final sessions = await db.getAllSessions();
  for (final s in sessions.where((s) => s.subjectId == subjectId)) {
    await svc.deleteSession(s.id);
  }
}

// ─────────────────────────────────────────────────────────────
// SubjectViewModel
// ─────────────────────────────────────────────────────────────

@riverpod
class SubjectViewModel extends _$SubjectViewModel {
  @override
  Future<List<Subject>> build() => database.getAllSubjects();

  Future<void> addSubject(String name, String colorHex,
      {String? categoryId}) async {
    final id = _generateId();
    await database.insertSubject(SubjectsCompanion.insert(
      id: id,
      categoryId: drift.Value(categoryId),
      name: name,
      colorHex: drift.Value(colorHex),
    ));

    await _safeSync('addSubject', (svc) => svc.syncSubject(
      Subject(id: id, categoryId: categoryId, name: name, colorHex: colorHex),
    ), database);

    ref.invalidateSelf();
    ref.invalidate(categoryViewModelProvider);
    ref.invalidate(statsViewModelProvider);
  }

  Future<void> updateSubject(Subject subject) async {
    await database.updateSubject(subject);
    await _safeSync(
        'updateSubject', (svc) => svc.syncSubject(subject), database);
    ref.invalidateSelf();
    ref.invalidate(categoryViewModelProvider);
    ref.invalidate(statsViewModelProvider);
  }

  Future<void> deleteSubject(String id) async {
    await database.deleteSessionsBySubject(id);
    await database.deletePlansBySubject(id);
    await database.deleteSubject(id);

    await _safeSync('deleteSubject/plans+sessions',
            (svc) => _deletePlanAndSessionsBySubject(svc, id), database);
    await _safeSync(
        'deleteSubject', (svc) => svc.deleteSubject(id), database);

    ref.invalidateSelf();
    ref.invalidate(categoryViewModelProvider);
    ref.invalidate(statsViewModelProvider);
  }
}

// ─────────────────────────────────────────────────────────────
// StudyPlanViewModel  ← 계획 sync 추가
// ─────────────────────────────────────────────────────────────

@riverpod
class StudyPlanViewModel extends _$StudyPlanViewModel {
  @override
  Future<List<Map<String, dynamic>>> build(DateTime date) async {
    final results = await database.getPlansWithSubject(date).get();
    return results.map((row) => {
      'plan': row.readTable(database.studyPlans),
      'subject': row.readTable(database.subjects),
    }).toList();
  }

  Future<void> addPlan({
    required String subjectId,
    required DateTime targetDate,
    required int goalMinutes,
    String memo = '',
  }) async {
    final id = _generateId();
    final now = DateTime.now();

    await database.insertPlan(StudyPlansCompanion.insert(
      id: id,
      subjectId: subjectId,
      targetDate: targetDate,
      goalMinutes: goalMinutes,
      memo: drift.Value(memo),
      createdAt: now,
    ));

    // ← 계획 sync 추가
    await _safeSync('addPlan', (svc) => svc.syncPlan(StudyPlan(
      id: id,
      subjectId: subjectId,
      targetDate: targetDate,
      goalMinutes: goalMinutes,
      memo: memo,
      isCompleted: false,
      createdAt: now,
    )), database);

    ref.invalidateSelf();
  }

  Future<void> toggleComplete(String planId, bool completed) async {
    await database.markPlanCompleted(planId, completed);

    // 변경된 plan 조회 후 sync
    final plans = await database.getAllPlans();
    final plan = plans.where((p) => p.id == planId).firstOrNull;
    if (plan != null) {
      await _safeSync(
          'toggleComplete', (svc) => svc.syncPlan(plan), database);
    }

    ref.invalidateSelf();
  }

  Future<void> deletePlan(String planId) async {
    await database.deletePlan(planId);
    await _safeSync(
        'deletePlan', (svc) => svc.deletePlan(planId), database);
    ref.invalidateSelf();
  }

  Future<void> addPlansFromAI(List<Map<String, dynamic>> plans) async {
    for (final plan in plans) {
      final id = _generateId();
      final now = DateTime.now();
      final subjectId = plan['subjectId'] as String;
      final targetDate = plan['targetDate'] as DateTime;
      final goalMinutes = plan['goalMinutes'] as int;
      final memo = plan['memo'] as String? ?? '';

      await database.insertPlan(StudyPlansCompanion.insert(
        id: id,
        subjectId: subjectId,
        targetDate: targetDate,
        goalMinutes: goalMinutes,
        memo: drift.Value(memo),
        createdAt: now,
      ));

      await _safeSync('addPlansFromAI', (svc) => svc.syncPlan(StudyPlan(
        id: id,
        subjectId: subjectId,
        targetDate: targetDate,
        goalMinutes: goalMinutes,
        memo: memo,
        isCompleted: false,
        createdAt: now,
      )), database);
    }
    ref.invalidateSelf();
  }
}

// ─────────────────────────────────────────────────────────────
// StudySessionViewModel  ← 세션 sync 추가
// ─────────────────────────────────────────────────────────────

@riverpod
class StudySessionViewModel extends _$StudySessionViewModel {
  @override
  Future<List<Map<String, dynamic>>> build(DateTime date) async {
    final results = await database.getSessionsWithSubject(date).get();
    return results.map((row) => {
      'session': row.readTable(database.studySessions),
      'subject': row.readTable(database.subjects),
    }).toList();
  }

  Future<String> startSession({
    required String subjectId,
    String? planId,
  }) async {
    final id = _generateId();
    final startTime = DateTime.now();

    await database.insertSession(StudySessionsCompanion.insert(
      id: id,
      subjectId: subjectId,
      planId: drift.Value(planId),
      startTime: startTime,
    ));

    // 세션 시작 시 Supabase에 즉시 push (endTime=null 상태)
    await _safeSync('startSession', (svc) => svc.syncSession(StudySession(
      id: id,
      subjectId: subjectId,
      planId: planId,
      startTime: startTime,
      endTime: null,
      durationSeconds: 0,
      trayOpenCount: 0,
      selfScore: 0,
    )), database);

    ref.invalidateSelf();
    return id;
  }

  Future<void> endSession(String sessionId, int durationSeconds) async {
    final sessions = await database.getAllSessions();
    final session = sessions.firstWhere((s) => s.id == sessionId);
    final updated = session.copyWith(
      endTime: drift.Value(DateTime.now()),
      durationSeconds: durationSeconds,
    );
    await database.updateSession(updated);

    // 종료된 세션 sync
    await _safeSync(
        'endSession', (svc) => svc.syncSession(updated), database);

    ref.invalidateSelf();
  }

  Future<void> incrementTrayOpen(String sessionId) async {
    final sessions = await database.getAllSessions();
    final session = sessions.firstWhere((s) => s.id == sessionId);
    final updated =
    session.copyWith(trayOpenCount: session.trayOpenCount + 1);
    await database.updateSession(updated);
    await _safeSync(
        'incrementTrayOpen', (svc) => svc.syncSession(updated), database);
    ref.invalidateSelf();
  }

  Future<void> setScore(String sessionId, int score) async {
    final sessions = await database.getAllSessions();
    final session = sessions.firstWhere((s) => s.id == sessionId);
    final updated = session.copyWith(selfScore: score);
    await database.updateSession(updated);
    await _safeSync(
        'setScore', (svc) => svc.syncSession(updated), database);
    ref.invalidateSelf();
  }

  Future<void> deleteSession(String id) async {
    await database.deleteSession(id);
    await _safeSync(
        'deleteSession', (svc) => svc.deleteSession(id), database);
    ref.invalidateSelf();
  }
}

// ─────────────────────────────────────────────────────────────
// StatsViewModel
// ─────────────────────────────────────────────────────────────

@riverpod
class StatsViewModel extends _$StatsViewModel {
  @override
  Future<List<Map<String, dynamic>>> build() =>
      database.getTotalSecondsBySubject();
}