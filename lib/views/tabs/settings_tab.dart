import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../viewmodels/study_view_model.dart';
import '../../services/api_key_service.dart';
import '../../services/supabase_sync_service.dart';
import '../../viewmodels/sync_provider.dart';
import '../../database/database.dart';
import '../../main.dart';
import '../../viewmodels/ui_state.dart';

const List<String> _presetColors = [
  '#4CAF50', '#2196F3', '#FF5722', '#9C27B0',
  '#FF9800', '#00BCD4', '#E91E63', '#607D8B',
];

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryViewModelProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
        children: [
          // ── 과목 관리 섹션 ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: Row(
              children: [
                Text('과목 관리',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddCategoryDialog(context, ref),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('카테고리 추가'),
                ),
              ],
            ),
          ),

          categoriesAsync.when(
            data: (categoryList) {
              if (categoryList.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '카테고리를 추가해서 과목을 분류해보세요.\n예) 학교공부, 자격증, 취미 등',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return Column(
                children: categoryList.map((item) {
                  final category = item['category'] as SubjectCategory;
                  final subjects = item['subjects'] as List<Subject>;
                  return _CategorySection(
                    category: category,
                    subjects: subjects,
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('오류: $e'),
          ),


          const Divider(height: 32),

          // ── 테마 설정 섹션 ────────────────────────────────────
          _ThemeSettingTile(),

          const Divider(height: 32),

          // ── 기기 관리 섹션 ────────────────────────────
          _DeviceIdTile(),

          const Divider(height: 32),

          // ── AI 설정 섹션 ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('AI 설정',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          _OpenRouterApiKeyTile(),
          _ApiKeyTile(),

          const Divider(height: 32),

          // ── 공부 모드 설정 섹션 ──────────────────────────
          _StudyModeSettingTile(),

          const Divider(height: 32),

          // ── Supabase 설정 섹션 ──────────────────────────
          _SupabaseSettingTile(),

          const SizedBox(height: 40),
        ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카테고리 추가'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: '카테고리 이름',
            hintText: '예) 학교공부, 자격증, 취미',
            isDense: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              await ref
                  .read(categoryViewModelProvider.notifier)
                  .addCategory(nameCtrl.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}

// ── 카테고리 섹션 위젯 ────────────────────────────────────
class _CategorySection extends ConsumerStatefulWidget {
  final SubjectCategory category;
  final List<Subject> subjects;

  const _CategorySection({
    required this.category,
    required this.subjects,
  });

  @override
  ConsumerState<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends ConsumerState<_CategorySection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── 카테고리 헤더 ──────────────────────────────
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.folder_open : Icons.folder,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.category.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Text(
                    '${widget.subjects.length}개',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  // 카테고리 메뉴
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      if (value == 'rename') {
                        _showRenameDialog(context);
                      } else if (value == 'delete') {
                        _showDeleteDialog(context);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Text('이름 변경')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('삭제', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  Icon(_isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more),
                ],
              ),
            ),
          ),

          // ── 과목 목록 ──────────────────────────────────
          if (_isExpanded) ...[
            const Divider(height: 1),
            ...widget.subjects.map((s) => _SubjectTile(
              subject: s,
              categoryId: widget.category.id,
            )),
            // 과목 추가 버튼
            InkWell(
              onTap: () => _showAddSubjectDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(Icons.add,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '과목 추가',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddSubjectDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String selectedColor = _presetColors.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${widget.category.name}에 과목 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '과목명',
                  isDense: true,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('색상 선택', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((hex) {
                  final color = _colorFromHex(hex);
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selectedColor == hex
                            ? Border.all(width: 3, color: Colors.black45)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                await ref
                    .read(categoryViewModelProvider.notifier)
                    .addSubjectToCategory(
                  categoryId: widget.category.id,
                  name: nameCtrl.text,
                  colorHex: selectedColor,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: widget.category.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카테고리 이름 변경'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(isDense: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              await ref
                  .read(categoryViewModelProvider.notifier)
                  .renameCategory(widget.category, nameCtrl.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text(
          '"${widget.category.name}" 카테고리를 삭제할까요?\n소속 과목들은 미분류로 이동됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(categoryViewModelProvider.notifier)
                  .deleteCategory(widget.category.id);
              if (context.mounted) Navigator.pop(context);
            },
            child:
            const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── 과목 타일 ─────────────────────────────────────────────
class _SubjectTile extends ConsumerWidget {
  final Subject subject;
  final String categoryId;

  const _SubjectTile({required this.subject, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorFromHex(subject.colorHex);
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 24, right: 8),
      leading: CircleAvatar(backgroundColor: color, radius: 12),
      title: Text(subject.name, style: const TextStyle(fontSize: 14)),
      onTap: () => _showEditSubjectDialog(context, ref),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline,
            color: Colors.redAccent, size: 18),
        onPressed: () => _showDeleteSubjectDialog(context, ref),
      ),
    );
  }

  Future<void> _showEditSubjectDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController(text: subject.name);
    String selectedColor = subject.colorHex;
    // 현재 과목 색깔이 프리셋에 없으면 프리셋 첫 번째로 fallback
    if (!_presetColors.contains(selectedColor)) {
      selectedColor = _presetColors.first;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('과목 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '과목명',
                  isDense: true,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('색상 선택', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((hex) {
                  final color = _colorFromHex(hex);
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selectedColor == hex
                            ? Border.all(width: 3, color: Colors.black45)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                if (newName.isEmpty) return;
                final updated = subject.copyWith(
                  name: newName,
                  colorHex: selectedColor,
                );
                await ref
                    .read(subjectViewModelProvider.notifier)
                    .updateSubject(updated);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteSubjectDialog(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('과목 삭제'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('"${subject.name}" 과목을 삭제할까요?'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚠️ 관련 체크리스트와 공부 기록도 함께 삭제됩니다.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                ref
                    .read(subjectViewModelProvider.notifier)
                    .deleteSubject(subject.id);
                Navigator.pop(context);
              },
              child: const Text('삭제',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

}

Color _colorFromHex(String hex) {
  try {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return Colors.indigo;
  }
}

// ── OpenRouter API 키 타일 ────────────────────────────────
class _OpenRouterApiKeyTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_OpenRouterApiKeyTile> createState() =>
      _OpenRouterApiKeyTileState();
}

class _OpenRouterApiKeyTileState
    extends ConsumerState<_OpenRouterApiKeyTile> {
  void _showEditDialog() {
    final currentKey = ref.read(openRouterApiKeyProvider).valueOrNull;
    final currentModel =
        ref.read(openRouterModelProvider).valueOrNull ?? defaultOpenRouterModel;
    final keyCtrl = TextEditingController(text: currentKey ?? '');
    final modelCtrl = TextEditingController(text: currentModel);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('OpenRouter 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'openrouter.ai 에서 발급받은 API 키를 입력하세요.\n이 키로 AI 계획 생성이 처리돼요.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-or-v1-...',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(
                  labelText: '모델명',
                  hintText: 'google/gemini-2.5-flash-preview',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            if (currentKey != null)
              TextButton(
                onPressed: () async {
                  await ref
                      .read(openRouterApiKeyProvider.notifier)
                      .delete();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('API 키가 삭제됐어요')),
                  );
                },
                child: const Text('삭제',
                    style: TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: () async {
                final key = keyCtrl.text.trim();
                if (key.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('API 키를 입력해주세요')),
                  );
                  return;
                }
                final model = modelCtrl.text.trim();
                try {
                  await ref
                      .read(openRouterApiKeyProvider.notifier)
                      .save(key);
                  await ref
                      .read(openRouterModelProvider.notifier)
                      .save(model.isNotEmpty ? model : defaultOpenRouterModel);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('저장 실패: $e'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('설정이 저장됐어요'),
                      backgroundColor: Colors.green),
                );
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  String _maskKey(String key) {
    if (key.length <= 12) return key;
    return '${key.substring(0, 10)}...${key.substring(key.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final apiKeyAsync = ref.watch(openRouterApiKeyProvider);
    final modelAsync = ref.watch(openRouterModelProvider);

    return apiKeyAsync.when(
      data: (key) {
        final isSet = key != null && key.isNotEmpty;
        final model = modelAsync.valueOrNull ?? defaultOpenRouterModel;

        return ListTile(
          leading: Icon(Icons.vpn_key,
              color: isSet ? Colors.green : Colors.grey),
          title: const Text('OpenRouter 설정'),
          subtitle: Text(
            isSet ? '${_maskKey(key)}\n$model' : '미설정 — 탭하여 설정',
            style: TextStyle(
              color: isSet ? Colors.green : Colors.orange,
              fontSize: 12,
            ),
          ),
          isThreeLine: isSet,
          trailing: Icon(
            isSet ? Icons.check_circle : Icons.warning_amber,
            color: isSet ? Colors.green : Colors.orange,
            size: 20,
          ),
          onTap: () => _showEditDialog(),
        );
      },
      loading: () => const ListTile(
        leading: Icon(Icons.vpn_key),
        title: Text('OpenRouter 설정'),
        subtitle: Text('불러오는 중...'),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.vpn_key, color: Colors.red),
        title: const Text('OpenRouter 설정'),
        subtitle: const Text('탭하여 설정'),
        onTap: () => _showEditDialog(),
      ),
    );
  }
}

// ── Hermes Agent 서버 설정 타일 ───────────────────────────
class _ApiKeyTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends ConsumerState<_ApiKeyTile> {
  void _showEditDialog() {
    final currentUrl = ref.read(serverUrlProvider).valueOrNull ?? 'http://localhost:8642';
    final urlCtrl = TextEditingController(text: currentUrl);
    bool testing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Hermes Agent 서버 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '서버 URL을 입력하세요.\nAPI 키와 모델은 서버에서 관리돼요.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: '서버 URL',
                  hintText: 'https://your-server.ngrok-free.dev',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: testing
                      ? null
                      : () async {
                          setDialogState(() => testing = true);
                          final url = urlCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');
                          try {
                            final uri = Uri.parse('$url/health');
                            final resp = await http.get(uri)
                                .timeout(const Duration(seconds: 5));
                            if (!context.mounted) return;
                            final ok = resp.statusCode == 200;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(ok ? '서버 연결 성공' : '서버 응답: ${resp.statusCode}'),
                              backgroundColor: ok ? Colors.green : Colors.red,
                            ));
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('연결 실패: $e'),
                              backgroundColor: Colors.red,
                            ));
                          } finally {
                            setDialogState(() => testing = false);
                          }
                        },
                  icon: testing
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_find, size: 18),
                  label: Text(testing ? '테스트 중...' : '연결 테스트'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = urlCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');
                if (url.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('서버 URL을 입력해주세요')),
                  );
                  return;
                }
                await ref.read(serverUrlProvider.notifier).save(url);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('설정이 저장됐어요'), backgroundColor: Colors.green),
                );
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serverUrlAsync = ref.watch(serverUrlProvider);

    return serverUrlAsync.when(
      data: (url) {
        final urlSet = url.isNotEmpty && url != 'http://localhost:8642';

        return ListTile(
          leading: Icon(Icons.dns, color: urlSet ? Colors.green : Colors.grey),
          title: const Text('Hermes Agent 서버'),
          subtitle: Text(
            urlSet ? url : '미설정 — 탭하여 설정',
            style: TextStyle(
              color: urlSet ? Colors.green : Colors.orange,
              fontSize: 12,
            ),
          ),
          trailing: Icon(
            urlSet ? Icons.check_circle : Icons.warning_amber,
            color: urlSet ? Colors.green : Colors.orange,
            size: 20,
          ),
          onTap: () => _showEditDialog(),
        );
      },
      loading: () => const ListTile(
        leading: Icon(Icons.dns),
        title: Text('Hermes Agent 서버'),
        subtitle: Text('불러오는 중...'),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.dns, color: Colors.red),
        title: const Text('Hermes Agent 서버'),
        subtitle: const Text('탭하여 설정'),
        onTap: () => _showEditDialog(),
      ),
    );
  }
}

class _DeviceIdTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DeviceIdTile> createState() => _DeviceIdTileState();
}

class _DeviceIdTileState extends ConsumerState<_DeviceIdTile> {
  String? _deviceId;
  String? _nfcId;
  bool _nfcLoading = true;
  bool get _nfcActive => _nfcId != null && _nfcId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
    nfcRefreshNotifier.addListener(_onSyncRefresh);
  }

  @override
  void dispose() {
    nfcRefreshNotifier.removeListener(_onSyncRefresh);
    super.dispose();
  }

  void _onSyncRefresh() => _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('device_number');
    setState(() {
      _deviceId = id;
      _nfcLoading = true;
    });
    if (id != null && id.isNotEmpty) {
      try {
        final nfc = await SupabaseSyncService(database).fetchNfcId(id);
        if (mounted) setState(() { _nfcId = nfc; _nfcLoading = false; });
      } catch (_) {
        if (mounted) setState(() => _nfcLoading = false);
      }
    } else {
      setState(() => _nfcLoading = false);
    }
  }

  void _showEditDialog() {
    final ctrl = TextEditingController(text: _deviceId ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기기 번호 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '이 스마트폰을 식별하는 3자리 번호예요.\n000 ~ 999 사이로 입력해주세요.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 3,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 12,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '000',
                hintStyle: TextStyle(color: Colors.grey.shade300),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          if (_deviceId != null && _deviceId!.isNotEmpty)
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('device_number');
                if (!context.mounted) return;
                Navigator.pop(context);
                _load();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('기기 번호가 삭제됐어요')),
                );
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () async {
              final num = int.tryParse(ctrl.text);
              if (num == null || num < 0 || num > 999) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('000 ~ 999 사이로 입력해주세요')),
                );
                return;
              }
              final formatted = num.toString().padLeft(3, '0');
              final prefs = await SharedPreferences.getInstance();
              final oldNumber = prefs.getString('device_number');

              // 먼저 로컬에 저장 (Supabase에서 user_id로 사용하기 위해)
              await prefs.setString('device_number', formatted);

              // Supabase에서 중복 체크
              try {
                final svc = SupabaseSyncService(database);
                final ok = await svc.registerDeviceNumber(formatted, oldNumber: oldNumber);
                if (!ok) {
                  // 중복이면 이전 값으로 복원
                  if (oldNumber != null) {
                    await prefs.setString('device_number', oldNumber);
                  } else {
                    await prefs.remove('device_number');
                  }
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$formatted번은 이미 다른 기기에서 사용 중이에요'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('등록 실패: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (!context.mounted) return;
              Navigator.pop(context);
              _load();
              // 기기 번호 변경 → 전체 데이터를 새 user_id로 업로드
              ref.read(initialSyncProvider.notifier).forcePushAll();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('기기 번호 $formatted번이 저장됐어요'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSet = _deviceId != null && _deviceId!.isNotEmpty;

    return ExpansionTile(
      leading: const Icon(Icons.phone_android),
      title: Text('기기 관리',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Text(
        isSet ? '기기 번호: $_deviceId' : '미설정',
        style: const TextStyle(fontSize: 12),
      ),
      children: [
        // ── 기기 번호 ──
        ListTile(
          leading: Icon(
            Icons.tag,
            color: isSet
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
          title: const Text('기기 번호'),
          subtitle: Text(
            isSet ? '${_deviceId}번' : '탭하여 입력',
            style: TextStyle(
              color: isSet
                  ? Theme.of(context).colorScheme.primary
                  : Colors.orange,
              fontSize: 12,
            ),
          ),
          trailing: Icon(
            isSet ? Icons.check_circle : Icons.warning_amber,
            color: isSet ? Colors.green : Colors.orange,
            size: 20,
          ),
          onTap: _showEditDialog,
        ),
        // ── NFC 상태 ──
        ListTile(
          leading: Icon(
            Icons.nfc,
            color: _nfcActive ? Colors.green : Colors.grey,
          ),
          title: const Text('NFC 상태'),
          subtitle: _nfcLoading
              ? const Text('확인 중...',
                  style: TextStyle(fontSize: 12, color: Colors.grey))
              : Text(
                  _nfcActive ? '활성화 — ${_nfcId!.length > 16 ? '${_nfcId!.substring(0, 16)}...' : _nfcId}' : '비활성화',
                  style: TextStyle(
                    fontSize: 12,
                    color: _nfcActive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          trailing: _nfcLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  _nfcActive ? Icons.check_circle : Icons.cancel,
                  color: _nfcActive ? Colors.green : Colors.red,
                  size: 20,
                ),
        ),
      ],
    );
  }
}

class _ThemeSettingTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);

    final labels = {
      ThemeMode.system: '시스템 설정 따름',
      ThemeMode.light: '라이트 모드',
      ThemeMode.dark: '다크 모드',
    };

    return ExpansionTile(
      leading: const Icon(Icons.palette_outlined),
      title: Text('테마',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Text(labels[themeMode] ?? '',
          style: const TextStyle(fontSize: 12)),
      children: [
        RadioListTile<ThemeMode>(
          title: const Text('시스템 설정 따름'),
          secondary: const Icon(Icons.brightness_auto),
          value: ThemeMode.system,
          groupValue: themeMode,
          onChanged: (v) =>
              ref.read(appThemeModeProvider.notifier).setTheme(v!),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('라이트 모드'),
          secondary: const Icon(Icons.light_mode),
          value: ThemeMode.light,
          groupValue: themeMode,
          onChanged: (v) =>
              ref.read(appThemeModeProvider.notifier).setTheme(v!),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('다크 모드'),
          secondary: const Icon(Icons.dark_mode),
          value: ThemeMode.dark,
          groupValue: themeMode,
          onChanged: (v) =>
              ref.read(appThemeModeProvider.notifier).setTheme(v!),
        ),
      ],
    );
  }
}

// ── 공부 모드 설정 ────────────────────────────────────────
class _StudyModeSettingTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.school_outlined),
      title: Text('공부 모드',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      subtitle: const Text('폰 뒤집기 공부 모드 설정',
          style: TextStyle(fontSize: 12)),
      children: [
        ListTile(
          title: const Text('Grace Period'),
          subtitle: const Text('폰을 들었을 때 대기 시간 (기본: 30초)'),
          trailing: const Text('30초'),
        ),
      ],
    );
  }
}

// ── Supabase 설정 ─────────────────────────────────────────
class _SupabaseSettingTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.cloud_outlined),
      title: Text('Supabase',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      subtitle: const Text('데이터 동기화',
          style: TextStyle(fontSize: 12)),
      children: [
        ListTile(
          title: const Text('데이터 Push'),
          subtitle: const Text('로컬 데이터를 Supabase로 강제 업로드'),
          trailing: ElevatedButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('업로드 중...')),
              );
              final result = await SupabaseSyncService(database).pushAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(result.success
                          ? '${result.count}개 항목 업로드 완료'
                          : '업로드 실패: ${result.error}')),
                );
              }
            },
            child: const Text('Push'),
          ),
        ),
        ListTile(
          title: const Text('데이터 Pull'),
          subtitle: const Text('Supabase에서 로컬로 데이터 다운로드'),
          trailing: ElevatedButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('다운로드 중...')),
              );
              final result = await SupabaseSyncService(database).pullAll();
              if (context.mounted) {
                if (result.success) {
                  final container = ProviderScope.containerOf(context, listen: false);
                  container.invalidate(categoryViewModelProvider);
                  container.invalidate(subjectViewModelProvider);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(result.success
                          ? '${result.count}개 항목 다운로드 완료'
                          : '다운로드 실패: ${result.error}')),
                );
              }
            },
            child: const Text('Pull'),
          ),
        ),
      ],
    );
  }
}