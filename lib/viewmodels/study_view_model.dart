import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/database.dart';
import '../main.dart';

part 'study_view_model.g.dart';

String _generateId() =>
    '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode.abs()}';

// ── 카테고리 뷰모델 ───────────────────────────────────────
@riverpod
class CategoryViewModel extends _$CategoryViewModel {
  @override
  Future<List<Map<String, dynamic>>> build() =>
      database.getCategoriesWithSubjects();

  Future<void> addCategory(String name) async {
    final cats = await database.getAllCategories();
    await database.insertCategory(SubjectCategoriesCompanion.insert(
      id: _generateId(),
      name: name,
      sortOrder: drift.Value(cats.length),
    ));
    ref.invalidateSelf();
  }

  Future<void> renameCategory(SubjectCategory category, String newName) async {
    await database.updateCategory(category.copyWith(name: newName));
    ref.invalidateSelf();
  }

  Future<void> deleteCategory(String categoryId) async {
    // 카테고리 소속 과목들의 세션/계획 먼저 삭제
    final subs = await database.getSubjectsByCategory(categoryId);
    for (final sub in subs) {
      await database.deleteSessionsBySubject(sub.id);
      await database.deletePlansBySubject(sub.id);
      await database.deleteSubject(sub.id);
    }
    await database.deleteCategory(categoryId);
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
    await database.insertSubject(SubjectsCompanion.insert(
      id: _generateId(),
      categoryId: drift.Value(categoryId),
      name: name,
      colorHex: drift.Value(colorHex),
    ));
    ref.invalidateSelf();
    ref.invalidate(subjectViewModelProvider);
  }
}

// ── 과목 뷰모델 ───────────────────────────────────────────
@riverpod
class SubjectViewModel extends _$SubjectViewModel {
  @override
  Future<List<Subject>> build() => database.getAllSubjects();

  Future<void> addSubject(String name, String colorHex, {String? categoryId}) async {
    await database.insertSubject(SubjectsCompanion.insert(
      id: _generateId(),
      categoryId: drift.Value(categoryId),
      name: name,
      colorHex: drift.Value(colorHex),
    ));
    ref.invalidateSelf();
    ref.invalidate(categoryViewModelProvider);
  }

  Future<void> updateSubject(Subject subject) async {
    await database.updateSubject(subject);
    ref.invalidateSelf();
    ref.invalidate(categoryViewModelProvider);
  }

  Future<void> deleteSubject(String id) async {
    await database.deleteSessionsBySubject(id);
    await database.deletePlansBySubject(id);
    await database.deleteSubject(id);
    ref.invalidateSelf();
    ref.invalidate(categoryViewModelProvider);
    ref.invalidate(statsViewModelProvider);
  }
}

// ── 공부 계획 뷰모델 ──────────────────────────────────────
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

// ── 공부 세션 뷰모델 ──────────────────────────────────────
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

// ── 통계 뷰모델 ───────────────────────────────────────────
@riverpod
class StatsViewModel extends _$StatsViewModel {
  @override
  Future<List<Map<String, dynamic>>> build() =>
      database.getTotalSecondsBySubject();
}
