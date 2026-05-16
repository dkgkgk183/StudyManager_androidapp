import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database.dart';
import 'package:drift/drift.dart' as drift;

const String _kDeviceId = 'device_number';

/// 기기 고유 번호(000~999)를 SharedPreferences에서 조회.
Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kDeviceId) ?? '';
}

// ─────────────────────────────────────────────────────────────

class SupabaseSyncService {
  final _supabase = Supabase.instance.client;
  final AppDatabase _db;

  SupabaseSyncService(this._db);

  // ── 기기 번호 등록 / 중복 체크 ────────────────────────────

  /// 기기 번호를 Supabase에 등록. 이전 번호는 폐기. 이미 사용 중이면 false.
  Future<bool> registerDeviceNumber(String number, {String? oldNumber}) async {
    // 이전 번호 삭제
    if (oldNumber != null && oldNumber.isNotEmpty) {
      await _supabase
          .from('device_registrations')
          .delete()
          .eq('device_number', oldNumber);
    }
    // 새 번호 중복 체크
    final existing = await _supabase
        .from('device_registrations')
        .select('device_number')
        .eq('device_number', number)
        .maybeSingle();
    if (existing != null) {
      return false;
    }
    await _supabase.from('device_registrations').upsert({
      'device_number': number,
    });
    return true;
  }

  // ── Supabase 헤더에 user_id 주입 ─────────────────────────
  // RLS 정책이 current_setting('app.user_id') 로 필터링하므로
  // 모든 요청에 앞서 SET LOCAL 실행.
  // NOTE: supabase-flutter의 rpc를 통해 세션 변수를 설정하거나,
  //       아래처럼 각 쿼리에 eq('user_id', deviceId)를 붙이는 방식으로 대체 가능.
  //       여기서는 eq 방식을 사용(더 간단하고 anon key와 궁합이 좋음).

  // ═══════════════════════════════════════════════════════════
  // PUSH (로컬 → Supabase)
  // ═══════════════════════════════════════════════════════════

  Future<void> syncCategory(SubjectCategory category) async {
    final uid = await getOrCreateDeviceId();
    await _supabase.from('categories').upsert({
      'id': category.id,
      'user_id': uid,
      'name': category.name,
      'sort_order': category.sortOrder,
    });
  }

  Future<void> syncSubject(Subject subject) async {
    final uid = await getOrCreateDeviceId();
    await _supabase.from('subjects').upsert({
      'id': subject.id,
      'user_id': uid,
      'category_id': subject.categoryId,
      'name': subject.name,
      'color_hex': subject.colorHex,
    });
  }

  Future<void> syncPlan(StudyPlan plan) async {
    final uid = await getOrCreateDeviceId();
    await _supabase.from('study_plans').upsert({
      'id': plan.id,
      'user_id': uid,
      'subject_id': plan.subjectId,
      'target_date': plan.targetDate.toIso8601String(),
      'goal_minutes': plan.goalMinutes,
      'memo': plan.memo,
      'is_completed': plan.isCompleted,
      'created_at': plan.createdAt.toIso8601String(),
    });
  }

  Future<void> syncSession(StudySession session) async {
    final uid = await getOrCreateDeviceId();
    await _supabase.from('study_sessions').upsert({
      'id': session.id,
      'user_id': uid,
      'subject_id': session.subjectId,
      'plan_id': session.planId,
      'start_time': session.startTime.toIso8601String(),
      'end_time': session.endTime?.toIso8601String(),
      'duration_seconds': session.durationSeconds,
      'tray_open_count': session.trayOpenCount,
      'self_score': session.selfScore,
    });
  }

  // ── Delete ────────────────────────────────────────────────

  Future<void> deleteCategory(String id) async {
    final uid = await getOrCreateDeviceId();
    await _supabase.from('categories').delete()
        .eq('id', id).eq('user_id', uid);
  }

  Future<void> deleteSubject(String id) async {
    final uid = await getOrCreateDeviceId();
    await _supabase.from('subjects').delete()
        .eq('id', id).eq('user_id', uid);
  }

  Future<void> deletePlan(String id) async {
    final uid = await getOrCreateDeviceId();
    await _supabase.from('study_plans').delete()
        .eq('id', id).eq('user_id', uid);
  }

  Future<void> deleteSession(String id) async {
    final uid = await getOrCreateDeviceId();
    await _supabase.from('study_sessions').delete()
        .eq('id', id).eq('user_id', uid);
  }

  Future<void> deletePlans(List<String> ids) async {
    if (ids.isEmpty) return;
    final uid = await getOrCreateDeviceId();
    await _supabase.from('study_plans').delete()
        .inFilter('id', ids).eq('user_id', uid);
  }

  Future<void> deleteSessions(List<String> ids) async {
    if (ids.isEmpty) return;
    final uid = await getOrCreateDeviceId();
    await _supabase.from('study_sessions').delete()
        .inFilter('id', ids).eq('user_id', uid);
  }

  // ═══════════════════════════════════════════════════════════
  // PULL (Supabase → 로컬)
  // 앱 최초 실행 또는 재설치 후 데이터 복원에 사용
  // ═══════════════════════════════════════════════════════════

  Future<SyncResult> pullAll() async {
    final uid = await getOrCreateDeviceId();
    int restored = 0;

    try {
      // 1. 카테고리
      final cats = await _supabase
          .from('categories')
          .select()
          .eq('user_id', uid)
          .order('sort_order');

      for (final row in cats) {
        await _db.insertCategory(SubjectCategoriesCompanion.insert(
          id: row['id'] as String,
          name: row['name'] as String,
          sortOrder: drift.Value(row['sort_order'] as int),
        ));
        restored++;
      }

      // 2. 과목
      final subs = await _supabase
          .from('subjects')
          .select()
          .eq('user_id', uid)
          .order('name');

      for (final row in subs) {
        await _db.insertSubject(SubjectsCompanion.insert(
          id: row['id'] as String,
          categoryId: drift.Value(row['category_id'] as String?),
          name: row['name'] as String,
          colorHex: drift.Value(row['color_hex'] as String),
        ));
        restored++;
      }

      // 3. 계획
      final plans = await _supabase
          .from('study_plans')
          .select()
          .eq('user_id', uid)
          .order('target_date');

      for (final row in plans) {
        await _db.insertPlan(StudyPlansCompanion.insert(
          id: row['id'] as String,
          subjectId: row['subject_id'] as String,
          targetDate: DateTime.parse(row['target_date'] as String),
          goalMinutes: row['goal_minutes'] as int,
          memo: drift.Value(row['memo'] as String? ?? ''),
          isCompleted: drift.Value(row['is_completed'] as bool? ?? false),
          createdAt: DateTime.parse(row['created_at'] as String),
        ));
        restored++;
      }

      // 4. 세션
      final sessions = await _supabase
          .from('study_sessions')
          .select()
          .eq('user_id', uid)
          .order('start_time', ascending: false);

      for (final row in sessions) {
        await _db.insertSession(StudySessionsCompanion.insert(
          id: row['id'] as String,
          subjectId: row['subject_id'] as String,
          planId: drift.Value(row['plan_id'] as String?),
          startTime: DateTime.parse(row['start_time'] as String),
          endTime: drift.Value(row['end_time'] != null
              ? DateTime.parse(row['end_time'] as String)
              : null),
          durationSeconds:
          drift.Value(row['duration_seconds'] as int? ?? 0),
          trayOpenCount:
          drift.Value(row['tray_open_count'] as int? ?? 0),
          selfScore: drift.Value(row['self_score'] as int? ?? 0),
        ));
        restored++;
      }

      return SyncResult.success(restored);
    } catch (e, st) {
      debugPrint('[SupabaseSync] pullAll 실패: $e\n$st');
      return SyncResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PUSH ALL (전체 로컬 → Supabase 업로드)
  // 데이터 마이그레이션 또는 새 기기 복사 시 사용
  // ═══════════════════════════════════════════════════════════

  Future<SyncResult> pushAll() async {
    int pushed = 0;
    try {
      final uid = await getOrCreateDeviceId();

      final cats = await _db.getAllCategories();
      for (final c in cats) {
        await syncCategory(c);
        pushed++;
      }

      final subs = await _db.getAllSubjects();
      for (final s in subs) {
        await syncSubject(s);
        pushed++;
      }

      final plans = await _db.getAllPlans();
      for (final p in plans) {
        await syncPlan(p);
        pushed++;
      }

      final sessions = await _db.getAllSessions();
      for (final s in sessions) {
        await syncSession(s);
        pushed++;
      }

      debugPrint('[SupabaseSync] pushAll 완료: $pushed 항목 (user=$uid)');
      return SyncResult.success(pushed);
    } catch (e, st) {
      debugPrint('[SupabaseSync] pushAll 실패: $e\n$st');
      return SyncResult.failure(e.toString());
    }
  }
}

// ─────────────────────────────────────────────────────────────
// 결과 래퍼
// ─────────────────────────────────────────────────────────────

class SyncResult {
  final bool success;
  final int count;
  final String? error;

  const SyncResult._({required this.success, required this.count, this.error});

  factory SyncResult.success(int count) =>
      SyncResult._(success: true, count: count);

  factory SyncResult.failure(String error) =>
      SyncResult._(success: false, count: 0, error: error);

  @override
  String toString() => success
      ? 'SyncResult(ok, $count items)'
      : 'SyncResult(fail: $error)';
}