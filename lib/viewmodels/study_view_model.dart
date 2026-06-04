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
  debugPrint('[_safeSync] $label 시작');
  try {
    await action(SupabaseSyncService(db));
    debugPrint('[_safeSync] $label 성공');
  } catch (e, st) {
    debugPrint('[_safeSync] $label 실패: $e');
    debugPrint('[_safeSync] $label stack: $st');
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

    // Supabase 삭제를 위해 모든 과목의 ID 먼저 수집 (로컬 삭제 전에!)
    final allChecklists = await database.getAllChecklistItems();
    final allSessions = await database.getAllSessions();
    final Set<String> checklistIds = {};
    final Set<String> sessionIds = {};
    for (final sub in subs) {
      for (final c in allChecklists.where((c) => c.subjectId == sub.id)) {
        checklistIds.add(c.id);
      }
      for (final s in allSessions.where((s) => s.subjectId == sub.id)) {
        sessionIds.add(s.id);
      }
    }

    for (final sub in subs) {
      await database.deleteSessionsBySubject(sub.id);
      await database.deleteChecklistItemsBySubject(sub.id);
      await database.deleteSubject(sub.id);

      await _safeSync('deleteCategory/subject',
              (svc) => svc.deleteSubject(sub.id), database);
    }

    // Supabase에서 체크리스트/세션 일괄 삭제
    await _safeSync('deleteCategory/checklists+sessions',
            (svc) => _deleteChecklistsAndSessionsBySubject(svc, checklistIds.toList(), sessionIds.toList()), database);

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

// Supabase에서 특정 과목의 체크리스트/세션 삭제 (미리 수집된 ID로 일괄 삭제)
Future<void> _deleteChecklistsAndSessionsBySubject(
    SupabaseSyncService svc, List<String> checklistIds, List<String> sessionIds) async {
  await svc.deleteChecklistItems(checklistIds);
  await svc.deleteSessions(sessionIds);
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
    // Supabase 삭제를 위해 ID 먼저 수집 (로컬 삭제 전에!)
    final allChecklists = await database.getAllChecklistItems();
    final allSessions = await database.getAllSessions();
    final checklistIds = allChecklists.where((c) => c.subjectId == id).map((c) => c.id).toList();
    final sessionIds = allSessions.where((s) => s.subjectId == id).map((s) => s.id).toList();

    await database.deleteSessionsBySubject(id);
    await database.deleteChecklistItemsBySubject(id);
    await database.deleteSubject(id);

    await _safeSync('deleteSubject/checklists+sessions',
            (svc) => _deleteChecklistsAndSessionsBySubject(svc, checklistIds, sessionIds), database);
    await _safeSync(
        'deleteSubject', (svc) => svc.deleteSubject(id), database);

    ref.invalidateSelf();
    ref.invalidate(categoryViewModelProvider);
    ref.invalidate(statsViewModelProvider);
  }
}

// ─────────────────────────────────────────────────────────────
// StudySessionViewModel
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

    await _safeSync('startSession', (svc) => svc.syncSession(StudySession(
      id: id,
      subjectId: subjectId,
      planId: planId,
      startTime: startTime,
      endTime: null,
      durationSeconds: 0,
      selfScore: 0,
      penaltyCount: 0,
      trayOpenCount: 0,
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

    await _safeSync(
        'endSession', (svc) => svc.syncSession(updated), database);

    ref.invalidateSelf();
  }

  Future<void> recordPenalty(String sessionId) async {
    final sessions = await database.getAllSessions();
    final session = sessions.firstWhere((s) => s.id == sessionId);
    final updated = session.copyWith(penaltyCount: session.penaltyCount + 1);
    await database.updateSession(updated);
    await _safeSync(
        'recordPenalty', (svc) => svc.syncSession(updated), database);
    ref.invalidateSelf();
  }

  /// 폰이 들어올려진 횟수 1 증가 (공부 중 z < -9.5 → z > 0 전이 시 호출)
  Future<void> recordTrayOpen(String sessionId) async {
    final sessions = await database.getAllSessions();
    final session = sessions.firstWhere((s) => s.id == sessionId);
    final updated = session.copyWith(trayOpenCount: session.trayOpenCount + 1);
    await database.updateSession(updated);
    await _safeSync(
        'recordTrayOpen', (svc) => svc.syncSession(updated), database);
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
// TodayChecklistViewModel
// ─────────────────────────────────────────────────────────────

@riverpod
class TodayChecklistViewModel extends _$TodayChecklistViewModel {
  @override
  Future<List<Map<String, dynamic>>> build(DateTime date) async {
    final dateStr = formatDateStr(date);
    final results = await database.getChecklistItemsWithSubject(dateStr).get();
    return results.map((row) => {
      'item': row.readTable(database.checklistItems),
      'subject': row.readTable(database.subjects),
    }).toList();
  }

  Future<void> addItem(String subjectId, String text) async {
    final dateStr = formatDateStr(date);
    final items = await database.getChecklistItemsByDate(dateStr);
    final id = _generateId();

    await database.insertChecklistItem(ChecklistItemsCompanion.insert(
      id: id,
      subjectId: subjectId,
      date: dateStr,
      content: text,
      sortOrder: drift.Value(items.length),
      createdAt: DateTime.now(),
    ));

    await _safeSync('addChecklistItem', (svc) => svc.syncChecklistItem(
      ChecklistItem(
        id: id,
        subjectId: subjectId,
        date: dateStr,
        content: text,
        isChecked: false,
        sortOrder: items.length,
        createdAt: DateTime.now(),
      ),
    ), database);

    ref.invalidateSelf();
  }

  Future<void> toggleItem(String itemId, bool isChecked) async {
    await database.toggleChecklistItem(itemId, isChecked);
    // Supabase 동기화
    final dateStr =
        formatDateStr(date);
    final items = await database.getChecklistItemsByDate(dateStr);
    final item = items.where((i) => i.id == itemId).firstOrNull;
    if (item != null) {
      await _safeSync('toggleChecklistItem',
          (svc) => svc.syncChecklistItem(item), database);
    }
    ref.invalidateSelf();
  }

  Future<void> deleteItem(String itemId) async {
    await database.deleteChecklistItem(itemId);
    await _safeSync(
        'deleteChecklistItem', (svc) => svc.deleteChecklistItem(itemId), database);
    ref.invalidateSelf();
  }

  Future<void> deleteAll() async {
    final dateStr = formatDateStr(date);
    final items = await database.getChecklistItemsByDate(dateStr);
    final ids = items.map((item) => item.id).toList();

    await database.deleteChecklistItemsByDate(dateStr);
    await _safeSync('deleteAllChecklistItems',
        (svc) => svc.deleteChecklistItems(ids), database);
    ref.invalidateSelf();
  }

  /// AI에서 벌크 추가
  Future<void> addItemsFromAI(List<Map<String, dynamic>> items) async {
    final dateStr = formatDateStr(date);
    final now = DateTime.now();
    final current = await database.getChecklistItemsByDate(dateStr);
    int sortOrder = current.length;

    for (final input in items) {
      final id = _generateId();

      await database.insertChecklistItem(ChecklistItemsCompanion.insert(
        id: id,
        subjectId: input['subjectId'] as String,
        date: dateStr,
        content: input['text'] as String,
        sortOrder: drift.Value(sortOrder),
        createdAt: now,
      ));

      await _safeSync(
          'addItemsFromAI', (svc) => svc.syncChecklistItem(
        ChecklistItem(
          id: id,
          subjectId: input['subjectId'] as String,
          date: dateStr,
          content: input['text'] as String,
          isChecked: false,
          sortOrder: sortOrder,
          createdAt: now,
        ),
      ), database);
      sortOrder++;
    }
    ref.invalidateSelf();
  }

  /// 과목 그룹 내에서 순서 변경
  Future<void> reorderInSubject(
      String subjectId, int oldIndex, int newIndex) async {
    final dateStr =
        formatDateStr(date);
    final allItems = await database.getChecklistItemsByDate(dateStr);

    // 해당 과목의 항목만 추출 (sortOrder 순)
    final groupItems =
        allItems.where((i) => i.subjectId == subjectId).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (oldIndex < 0 || oldIndex >= groupItems.length) return;
    if (newIndex < 0 || newIndex >= groupItems.length) return;

    // 이동
    final item = groupItems.removeAt(oldIndex);
    groupItems.insert(newIndex, item);

    // sortOrder 업데이트 + Supabase 동기화
    for (int i = 0; i < groupItems.length; i++) {
      if (groupItems[i].sortOrder != i) {
        final updated = groupItems[i].copyWith(sortOrder: i);
        await database.updateChecklistItem(updated);
        await _safeSync('reorderChecklistItem',
            (svc) => svc.syncChecklistItem(updated), database);
      }
    }

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

  Future<int> getTotalPenaltyCount() async {
    final sessions = await database.getAllSessions();
    return sessions.fold<int>(0, (sum, s) => sum + s.penaltyCount);
  }
}

/// 선택된 날짜의 통계 요약 (총 공부시간, penalty 합계, trayOpen 합계)
class StatsSummary {
  final int totalSeconds;
  final int penaltyCount;
  final int trayOpenCount;

  const StatsSummary({
    required this.totalSeconds,
    required this.penaltyCount,
    required this.trayOpenCount,
  });

  static const empty = StatsSummary(
    totalSeconds: 0,
    penaltyCount: 0,
    trayOpenCount: 0,
  );
}

@riverpod
class StatsSummaryViewModel extends _$StatsSummaryViewModel {
  @override
  Future<StatsSummary> build(DateTime date) async {
    final sessions = await database.getSessionsByDate(date);
    final totalSeconds = sessions.fold<int>(0, (s, e) => s + e.durationSeconds);
    final penaltyCount = sessions.fold<int>(0, (s, e) => s + e.penaltyCount);
    final trayOpenCount = sessions.fold<int>(0, (s, e) => s + e.trayOpenCount);
    return StatsSummary(
      totalSeconds: totalSeconds,
      penaltyCount: penaltyCount,
      trayOpenCount: trayOpenCount,
    );
  }
}
