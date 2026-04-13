import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/database.dart';
import '../main.dart';
import '../services/supabase_sync_service.dart';

part 'study_view_model.g.dart';

String _generateId() =>
    '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode.abs()}';

@riverpod
class CategoryViewModel extends _$CategoryViewModel {
  @override
  Future<List<Map<String, dynamic>>> build() =>
      database.getCategoriesWithSubjects();

  Future<void> addCategory(String name) async {
    final cats = await database.getAllCategories();
    final id = _generateId();
    final sortOrder = cats.length;

    // 1. 로컬 DB에 저장
    await database.insertCategory(SubjectCategoriesCompanion.insert(
      id: id,
      name: name,
      sortOrder: drift.Value(sortOrder),
    ));

    // 2. Supabase에 동기화
    try {
      final syncService = SupabaseSyncService(database);
      await syncService.syncCategory(SubjectCategory(
          id: id,
          name: name,
          sortOrder: sortOrder
      ));
    } catch (e) {
      debugPrint('카테고리 동기화 실패: $e');
    }

    ref.invalidateSelf();
  }

  Future<void> renameCategory(SubjectCategory category, String newName) async {
    final updatedCategory = category.copyWith(name: newName);
    await database.updateCategory(updatedCategory);

    try {
      final syncService = SupabaseSyncService(database);
      await syncService.syncCategory(updatedCategory);
    } catch (e) {
      debugPrint('카테고리 이름 변경 동기화 실패: $e');
    }

    ref.invalidateSelf();
  }

  Future<void> deleteCategory(String categoryId) async {
    final subs = await database.getSubjectsByCategory(categoryId);
    for (final sub in subs) {
      await database.deleteSessionsBySubject(sub.id);
      await database.deletePlansBySubject(sub.id);
      await database.deleteSubject(sub.id);

      // 소속된 과목도 웹에서 지워줌
      try {
        await SupabaseSyncService(database).deleteSubject(sub.id);
      } catch (_) {}
    }

    await database.deleteCategory(categoryId);

    try {
      await SupabaseSyncService(database).deleteCategory(categoryId);
    } catch (e) {
      debugPrint('카테고리 삭제 동기화 실패: $e');
    }

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

    try {
      final syncService = SupabaseSyncService(database);
      await syncService.syncSubject(Subject(
          id: id,
          categoryId: categoryId,
          name: name,
          colorHex: colorHex
      ));
    } catch (e) {
      debugPrint('과목 동기화 실패: $e');
    }

    ref.invalidateSelf();
    ref.invalidate(subjectViewModelProvider);
    ref.invalidate(statsViewModelProvider);
  }
}

// ── 과목 뷰모델 ───────────────────────────────────────────
@riverpod
class SubjectViewModel extends _$SubjectViewModel {
  @override
  Future<List<Subject>> build() => database.getAllSubjects();

  Future<void> addSubject(String name, String colorHex, {String? categoryId}) async {
    final id = _generateId();
    await database.insertSubject(SubjectsCompanion.insert(
      id: id,
      categoryId: drift.Value(categoryId),
      name: name,
      colorHex: drift.Value(colorHex),
    ));

    try {
      final syncService = SupabaseSyncService(database);
      await syncService.syncSubject(Subject(
          id: id,
          categoryId: categoryId,
          name: name,
          colorHex: colorHex
      ));
    } catch (e) {
      debugPrint('과목 동기화 실패: $e');
    }

    ref.invalidateSelf();
    ref.invalidate(categoryViewModelProvider);
    ref.invalidate(statsViewModelProvider);
  }

  Future<void> updateSubject(Subject subject) async {
    await database.updateSubject(subject);

    try {
      final syncService = SupabaseSyncService(database);
      await syncService.syncSubject(subject);
    } catch (e) {
      debugPrint('과목 수정 동기화 실패: $e');
    }

    ref.invalidateSelf();
    ref.invalidate(categoryViewModelProvider);
    ref.invalidate(statsViewModelProvider);
  }

  Future<void> deleteSubject(String id) async {
    await database.deleteSessionsBySubject(id);
    await database.deletePlansBySubject(id);
    await database.deleteSubject(id);

    try {
      final syncService = SupabaseSyncService(database);
      await syncService.deleteSubject(id);
    } catch (e) {
      debugPrint('과목 삭제 동기화 실패: $e');
    }

    ref.invalidateSelf();
    ref.invalidate(categoryViewModelProvider);
    ref.invalidate(statsViewModelProvider);
  }
}

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
    await database.insertPlan(StudyPlansCompanion.insert(
      id: _generateId(),
      subjectId: subjectId,
      targetDate: targetDate,
      goalMinutes: goalMinutes,
      memo: drift.Value(memo),
      createdAt: DateTime.now(),
    ));
    ref.invalidateSelf();
  }

  Future<void> toggleComplete(String planId, bool completed) async {
    await database.markPlanCompleted(planId, completed);
    ref.invalidateSelf();
  }

  Future<void> deletePlan(String planId) async {
    await database.deletePlan(planId);
    ref.invalidateSelf();
  }

  Future<void> addPlansFromAI(List<Map<String, dynamic>> plans) async {
    for (final plan in plans) {
      await database.insertPlan(StudyPlansCompanion.insert(
        id: _generateId(),
        subjectId: plan['subjectId'] as String,
        targetDate: plan['targetDate'] as DateTime,
        goalMinutes: plan['goalMinutes'] as int,
        memo: drift.Value(plan['memo'] as String? ?? ''),
        createdAt: DateTime.now(),
      ));
    }
    ref.invalidateSelf();
  }
}

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
    await database.insertSession(StudySessionsCompanion.insert(
      id: id,
      subjectId: subjectId,
      planId: drift.Value(planId),
      startTime: DateTime.now(),
    ));
    ref.invalidateSelf();
    return id;
  }

  Future<void> endSession(String sessionId, int durationSeconds) async {
    final sessions = await database.getAllSessions();
    final session = sessions.firstWhere((s) => s.id == sessionId);
    await database.updateSession(session.copyWith(
      endTime: drift.Value(DateTime.now()),
      durationSeconds: durationSeconds,
    ));
    ref.invalidateSelf();
  }

  Future<void> incrementTrayOpen(String sessionId) async {
    final sessions = await database.getAllSessions();
    final session = sessions.firstWhere((s) => s.id == sessionId);
    await database.updateSession(
        session.copyWith(trayOpenCount: session.trayOpenCount + 1));
    ref.invalidateSelf();
  }

  Future<void> setScore(String sessionId, int score) async {
    final sessions = await database.getAllSessions();
    final session = sessions.firstWhere((s) => s.id == sessionId);
    await database.updateSession(session.copyWith(selfScore: score));
    ref.invalidateSelf();
  }

  Future<void> deleteSession(String id) async {
    await database.deleteSession(id);
    ref.invalidateSelf();
  }
}

@riverpod
class StatsViewModel extends _$StatsViewModel {
  @override
  Future<List<Map<String, dynamic>>> build() =>
      database.getTotalSecondsBySubject();
}