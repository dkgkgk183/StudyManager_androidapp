import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/database.dart';
import '../main.dart';
import '../services/api_key_service.dart';
import '../services/briefing_service.dart';
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
    // 로컬 세션 + Supabase에서 라즈베리파이 세션 pull 후 ID 기준 병합.
    // 동일 ID면 원격(RPi) 우선 — 트레이 센서 갱신분이 더 최신.
    // RPi 전용 세션(로컬에 없는)은 subjectId로 로컬 과목 조회.
    final localRows = await database.getSessionsWithSubject(date).get();
    final remoteSessions =
        await SupabaseSyncService(database).fetchTodaySessions(date);

    final merged = <String, Map<String, dynamic>>{};
    for (final row in localRows) {
      final session = row.readTable(database.studySessions);
      final subject = row.readTable(database.subjects);
      merged[session.id] = {'session': session, 'subject': subject};
    }

    // RPi 전용 세션들의 subject를 한 번에 조회 (N+1 방지)
    final missingSubjectIds = remoteSessions
        .where((rs) => !merged.containsKey(rs.id))
        .map((rs) => rs.subjectId)
        .toSet();
    final subjectsById = <String, Subject>{};
    for (final id in missingSubjectIds) {
      final s = await database.getSubjectById(id);
      if (s != null) subjectsById[id] = s;
    }

    for (final rs in remoteSessions) {
      if (merged.containsKey(rs.id)) {
        // 같은 ID의 로컬 세션이 있으면 session 필드만 갱신 (subject 유지)
        merged[rs.id]!['session'] = rs;
      } else {
        // RPi 전용 세션 — subject 조회, 없으면 placeholder
        final subject = subjectsById[rs.subjectId] ??
            Subject(
              id: rs.subjectId,
              categoryId: null,
              name: '알 수 없는 과목',
              colorHex: '#9E9E9E',
            );
        merged[rs.id] = {'session': rs, 'subject': subject};
      }
    }

    final list = merged.values.toList()
      ..sort((a, b) => (a['session'] as StudySession)
          .startTime
          .compareTo((b['session'] as StudySession).startTime));
    return list;
  }

  /// 세션/체크리스트/요약을 강제 리빌드한 뒤 브리핑을 재생성·저장한다.
  /// 통계 탭에 들어오기 전에 백그라운드에서 미리 돌려놓기 위한 트리거.
  /// (세션 카운트 등 브리핑 입력에 영향이 있는 변경에서만 호출한다.)
  void _kickOffBriefingRegeneration(DateTime date) {
    unawaited(() async {
      try {
        final summary =
            await ref.read(statsSummaryViewModelProvider(date).future);
        final sessions = ref
                .read(studySessionViewModelProvider(date))
                .valueOrNull ??
            const <Map<String, dynamic>>[];
        final checklist = ref
                .read(todayChecklistViewModelProvider(date))
                .valueOrNull ??
            const <Map<String, dynamic>>[];
        final apiKey = ref.read(openRouterApiKeyProvider).valueOrNull;
        await ref.read(briefingServiceProvider).regenerateAndSave(
              date: date,
              summary: summary,
              sessions: sessions,
              checklist: checklist,
              apiKey: apiKey,
            );
      } catch (e) {
        debugPrint('[_kickOffBriefingRegeneration] 실패: $e');
      }
    }());
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
    _kickOffBriefingRegeneration(date);
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
    _kickOffBriefingRegeneration(date);
  }

  Future<void> recordPenalty(String sessionId) async {
    final sessions = await database.getAllSessions();
    final session = sessions.firstWhere((s) => s.id == sessionId);
    final updated = session.copyWith(penaltyCount: session.penaltyCount + 1);
    await database.updateSession(updated);
    await _safeSync(
        'recordPenalty', (svc) => svc.syncSession(updated), database);
    ref.invalidateSelf();
    _kickOffBriefingRegeneration(date);
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
    _kickOffBriefingRegeneration(date);
  }

  Future<void> setScore(String sessionId, int score) async {
    final sessions = await database.getAllSessions();
    final session = sessions.firstWhere((s) => s.id == sessionId);
    final updated = session.copyWith(selfScore: score);
    await database.updateSession(updated);
    await _safeSync(
        'setScore', (svc) => svc.syncSession(updated), database);
    ref.invalidateSelf();
    // selfScore는 브리핑 입력에 포함되지 않으므로 재생성 불필요
  }

  Future<void> deleteSession(String id) async {
    await database.deleteSession(id);
    await _safeSync(
        'deleteSession', (svc) => svc.deleteSession(id), database);
    ref.invalidateSelf();
    _kickOffBriefingRegeneration(date);
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

  /// 체크리스트/세션/요약을 강제 리빌드한 뒤 브리핑을 재생성·저장한다.
  void _kickOffBriefingRegeneration() {
    unawaited(() async {
      try {
        final summary =
            await ref.read(statsSummaryViewModelProvider(date).future);
        final sessions = ref
                .read(studySessionViewModelProvider(date))
                .valueOrNull ??
            const <Map<String, dynamic>>[];
        final checklist = ref
                .read(todayChecklistViewModelProvider(date))
                .valueOrNull ??
            const <Map<String, dynamic>>[];
        final apiKey = ref.read(openRouterApiKeyProvider).valueOrNull;
        await ref.read(briefingServiceProvider).regenerateAndSave(
              date: date,
              summary: summary,
              sessions: sessions,
              checklist: checklist,
              apiKey: apiKey,
            );
      } catch (e) {
        debugPrint('[_kickOffBriefingRegeneration/checklist] 실패: $e');
      }
    }());
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
    _kickOffBriefingRegeneration();
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
    _kickOffBriefingRegeneration();
  }

  Future<void> updateItemContent(String itemId, String newContent) async {
    final dateStr = formatDateStr(date);
    final items = await database.getChecklistItemsByDate(dateStr);
    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx < 0) {
      debugPrint('[updateItemContent] item not found: $itemId');
      return;
    }
    final updated = items[idx].copyWith(content: newContent);
    await database.updateChecklistItem(updated);
    await _safeSync(
        'updateChecklistItem', (svc) => svc.syncChecklistItem(updated), database);
    ref.invalidateSelf();
    // 내용만 바뀌는 경우 브리핑 입력(완료율 등)에는 영향 없음
  }

  Future<void> deleteItem(String itemId) async {
    await database.deleteChecklistItem(itemId);
    await _safeSync(
        'deleteChecklistItem', (svc) => svc.deleteChecklistItem(itemId), database);
    ref.invalidateSelf();
    _kickOffBriefingRegeneration();
  }

  Future<void> deleteAll() async {
    final dateStr = formatDateStr(date);
    final items = await database.getChecklistItemsByDate(dateStr);
    final ids = items.map((item) => item.id).toList();

    await database.deleteChecklistItemsByDate(dateStr);
    await _safeSync('deleteAllChecklistItems',
        (svc) => svc.deleteChecklistItems(ids), database);
    ref.invalidateSelf();
    _kickOffBriefingRegeneration();
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
    _kickOffBriefingRegeneration();
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
    // 순서만 바뀌는 경우 브리핑 입력에는 영향 없음
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

/// 선택된 날짜의 통계 요약 (총 공부시간, 세션 개수, penalty 합계, trayOpen 합계)
class StatsSummary {
  final int totalSeconds;
  final int totalSecondsLocal;
  final int totalSecondsRpi;
  final int sessionCount;
  final int sessionCountLocal;
  final int sessionCountRpi;
  final int penaltyCount;
  final int penaltyCountLocal;
  final int penaltyCountRpi;
  final int trayOpenCount;
  final int trayOpenCountLocal;
  final int trayOpenCountRpi;

  const StatsSummary({
    required this.totalSeconds,
    required this.totalSecondsLocal,
    required this.totalSecondsRpi,
    required this.sessionCount,
    required this.sessionCountLocal,
    required this.sessionCountRpi,
    required this.penaltyCount,
    required this.penaltyCountLocal,
    required this.penaltyCountRpi,
    required this.trayOpenCount,
    required this.trayOpenCountLocal,
    required this.trayOpenCountRpi,
  });

  static const empty = StatsSummary(
    totalSeconds: 0,
    totalSecondsLocal: 0,
    totalSecondsRpi: 0,
    sessionCount: 0,
    sessionCountLocal: 0,
    sessionCountRpi: 0,
    penaltyCount: 0,
    penaltyCountLocal: 0,
    penaltyCountRpi: 0,
    trayOpenCount: 0,
    trayOpenCountLocal: 0,
    trayOpenCountRpi: 0,
  );

  /// ID 길이가 10자면 라즈베리파이(트레이 센서)에서 온 세션으로 간주.
  static bool isRpiSession(String id) => id.length == 10;

  /// 집중도 점수 계산 (0~100).
  ///
  /// 가중치:
  ///   - 패널티 1회당 -15 (가장 높음)
  ///   - 초과 폰 들고나림 1회당 -5 (중간)
  ///     · 세션당 1회는 기본 (시작/종료 시 확인)
  ///     · 세션 수를 초과한 만큼만 집중도 하락으로 간주
  ///   - 공부 시간 보너스 +0~+20 (30분=+20, 선형)
  ///   - 세션 보너스 +0~+5 (1세션당 +1)
  static int computeFocusScore({
    required int sessionCount,
    required int phoneLiftCount,
    required int penaltyCount,
    required int totalSeconds,
  }) {
    if (sessionCount == 0) return 0;

    final excessLifts =
        phoneLiftCount > sessionCount ? phoneLiftCount - sessionCount : 0;

    const penaltyWeight = 15.0;
    const liftWeight = 5.0;
    const timeBonusCap = 20.0;
    const sessionBonusCap = 5.0;
    const secondsPerBonusUnit = 180.0; // 30분 → +20

    final penaltyCost = penaltyCount * penaltyWeight;
    final liftCost = excessLifts * liftWeight;
    final timeBonus = (totalSeconds / secondsPerBonusUnit) < timeBonusCap
        ? totalSeconds / secondsPerBonusUnit
        : timeBonusCap;
    final sessionBonus = sessionCount < sessionBonusCap
        ? sessionCount.toDouble()
        : sessionBonusCap;

    final raw = 100 - penaltyCost - liftCost + timeBonus + sessionBonus;
    if (raw < 0) return 0;
    if (raw > 100) return 100;
    return raw.round();
  }
}

@riverpod
class StatsSummaryViewModel extends _$StatsSummaryViewModel {
  @override
  Future<StatsSummary> build(DateTime date) async {
    // 로컬 세션 + Supabase에서 오늘자 pull (라즈베리파이 tray_open_count 반영)
    // 동일 ID면 원격을 우선 (트레이 센서 갱신분이 더 최신).
    final localFut = database.getSessionsByDate(date);
    final remoteFut =
        SupabaseSyncService(database).fetchTodaySessions(date);
    final results = await Future.wait([localFut, remoteFut]);
    final localSessions = results[0];
    final remoteSessions = results[1];

    final byId = <String, StudySession>{};
    for (final s in localSessions) {
      byId[s.id] = s;
    }
    for (final s in remoteSessions) {
      byId[s.id] = s;
    }
    final sessions = byId.values.toList();

    int trayLocal = 0;
    int trayRpi = 0;
    int sessionLocal = 0;
    int sessionRpi = 0;
    int penaltyLocal = 0;
    int penaltyRpi = 0;
    for (final s in sessions) {
      if (StatsSummary.isRpiSession(s.id)) {
        trayRpi += s.trayOpenCount;
        sessionRpi++;
        penaltyRpi += s.penaltyCount;
      } else {
        trayLocal += s.trayOpenCount;
        sessionLocal++;
        penaltyLocal += s.penaltyCount;
      }
    }
    int secondsLocal = 0;
    int secondsRpi = 0;
    for (final s in sessions) {
      if (StatsSummary.isRpiSession(s.id)) {
        secondsRpi += s.durationSeconds;
      } else {
        secondsLocal += s.durationSeconds;
      }
    }
    final totalSeconds = secondsLocal + secondsRpi;
    return StatsSummary(
      totalSeconds: totalSeconds,
      totalSecondsLocal: secondsLocal,
      totalSecondsRpi: secondsRpi,
      sessionCount: sessions.length,
      sessionCountLocal: sessionLocal,
      sessionCountRpi: sessionRpi,
      penaltyCount: penaltyLocal + penaltyRpi,
      penaltyCountLocal: penaltyLocal,
      penaltyCountRpi: penaltyRpi,
      trayOpenCount: trayLocal + trayRpi,
      trayOpenCountLocal: trayLocal,
      trayOpenCountRpi: trayRpi,
    );
  }
}
