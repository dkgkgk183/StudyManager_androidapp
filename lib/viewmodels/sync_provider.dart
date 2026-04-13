import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../main.dart';
import '../services/supabase_sync_service.dart';
import 'study_view_model.dart';

part 'sync_provider.g.dart';

const String _kFirstRunKey = 'supabase_pull_done';

// ─────────────────────────────────────────────────────────────
// InitialSyncNotifier
// 앱 최초 실행(또는 재설치) 시 Supabase → 로컬 pull 수행
// 이미 pull 한 적 있으면 skip
// ─────────────────────────────────────────────────────────────

@riverpod
class InitialSync extends _$InitialSync {
  @override
  Future<SyncResult?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyDone = prefs.getBool(_kFirstRunKey) ?? false;

    // 로컬 DB에 데이터가 없을 때만 pull
    final localSubjects = await database.getAllSubjects();
    if (alreadyDone || localSubjects.isNotEmpty) {
      return null; // 이미 데이터 있음 → skip
    }

    final result = await SupabaseSyncService(database).pullAll();

    if (result.success) {
      await prefs.setBool(_kFirstRunKey, true);
      // pull 후 모든 provider 갱신
      ref.invalidate(categoryViewModelProvider);
      ref.invalidate(subjectViewModelProvider);
      ref.invalidate(statsViewModelProvider);
    }

    return result;
  }

  /// 수동 pull (설정 화면 "데이터 복원" 버튼 등에서 호출)
  Future<SyncResult> forcePull() async {
    state = const AsyncLoading();
    final result = await SupabaseSyncService(database).pullAll();
    if (result.success) {
      ref.invalidate(categoryViewModelProvider);
      ref.invalidate(subjectViewModelProvider);
      ref.invalidate(statsViewModelProvider);
    }
    state = AsyncData(result);
    return result;
  }

  /// 수동 push 전체 (설정 화면 "백업" 버튼 등에서 호출)
  Future<SyncResult> forcePushAll() async {
    state = const AsyncLoading();
    final result = await SupabaseSyncService(database).pushAll();
    state = AsyncData(result);
    return result;
  }
}

// ─────────────────────────────────────────────────────────────
// SyncStatusBanner
// AppBar 아래에 붙여서 sync 상태를 표시하는 위젯 (선택 사항)
// ─────────────────────────────────────────────────────────────

class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(initialSyncProvider);

    return syncAsync.when(
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Supabase에서 데이터 복원 중...', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      data: (result) {
        if (result == null) return const SizedBox.shrink();
        if (result.success && result.count > 0) {
          // 복원 성공 알림은 1회만 표시
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${result.count}개 항목을 Supabase에서 복원했어요 ✅'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ));
          });
        }
        return const SizedBox.shrink();
      },
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}