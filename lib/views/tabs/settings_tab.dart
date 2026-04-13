import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/study_view_model.dart';
import '../../services/api_key_service.dart';
import '../../database/database.dart';
import '../../viewmodels/sync_provider.dart';

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
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
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

          // ── 기기 연동 섹션 ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('라즈베리파이 연동',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.wifi),
            title: const Text('기기 IP 주소'),
            subtitle: const Text('미설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('기기 연동 설정 구현 예정')),
              );
            },
          ),

          const Divider(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('클라우드 동기화',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          _SyncTile(),

          const SizedBox(height: 40),

          const Divider(height: 32),

          // ── Gemini API 키 섹션 ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Gemini API',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          _ApiKeyTile(),

          const SizedBox(height: 40),
        ],
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
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline,
            color: Colors.redAccent, size: 18),
        onPressed: () => showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('과목 삭제'),
            content: Text('"${subject.name}" 과목을 삭제할까요?'),
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
          ),
        ),
      ),
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

// ── API 키 입력 타일 ──────────────────────────────────────
// settings_tab.dart 맨 아래에 붙여넣기
class _ApiKeyTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends ConsumerState<_ApiKeyTile> {
  void _showEditDialog(String? currentKey) {
    final ctrl = TextEditingController(text: currentKey ?? '');
    bool obscure = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Gemini API 키 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Google AI Studio에서 발급받은 API 키를 입력하세요.\n키는 기기에만 저장되며 외부로 전송되지 않아요.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '...',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            if (currentKey != null && currentKey.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final success = await ref.read(apiKeyProvider.notifier).delete();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(success ? 'API 키가 삭제됐어요' : '삭제에 실패했어요'),
                    backgroundColor: success ? Colors.red : Colors.orange,
                  ));
                },
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: () async {
                final key = ctrl.text.trim();
                if (key.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API 키를 입력해주세요')),
                  );
                  return;
                }
                final success = await ref.read(apiKeyProvider.notifier).save(key);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success ? 'API 키가 저장됐어요 ✅' : '저장에 실패했어요. 다시 시도해주세요'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ));
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
    final apiKeyAsync = ref.watch(apiKeyProvider);

    return apiKeyAsync.when(
      data: (key) {
        final isSet = key != null && key.isNotEmpty;
        final maskedKey = isSet && key.length >= 8
            ? '${key.substring(0, 4)}${'*' * (key.length - 8)}${key.substring(key.length - 4)}'
            : key;

        return ListTile(
          leading: Icon(Icons.key, color: isSet ? Colors.green : Colors.grey),
          title: const Text('API 키'),
          subtitle: Text(
            isSet ? maskedKey! : '미설정 — 탭하여 입력',
            style: TextStyle(
              color: isSet ? Colors.green : Colors.orange,
              fontSize: 12,
            ),
          ),
          trailing: Icon(
            isSet ? Icons.check_circle : Icons.warning_amber,
            color: isSet ? Colors.green : Colors.orange,
            size: 20,
          ),
          onTap: () => _showEditDialog(key),
        );
      },
      loading: () => const ListTile(
        leading: Icon(Icons.key),
        title: Text('API 키'),
        subtitle: Text('불러오는 중...'),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.key, color: Colors.red),
        title: const Text('API 키'),
        subtitle: const Text('탭하여 입력'),
        onTap: () => _showEditDialog(null),
      ),
    );
  }
}

class _SyncTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(initialSyncProvider);
    final isLoading = syncAsync.isLoading;

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_upload_outlined),
          title: const Text('Supabase 백업'),
          subtitle: const Text('현재 기기의 모든 데이터를 클라우드에 업로드'),
          trailing: isLoading
              ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: isLoading ? null : () async {
            final result = await ref
                .read(initialSyncProvider.notifier)
                .forcePushAll();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result.success
                  ? '${result.count}개 항목 백업 완료 ✅'
                  : '백업 실패: ${result.error}'),
              backgroundColor:
              result.success ? Colors.green : Colors.red,
            ));
          },
        ),
        ListTile(
          leading: const Icon(Icons.cloud_download_outlined),
          title: const Text('Supabase 복원'),
          subtitle: const Text('클라우드 데이터를 현재 기기로 가져오기'),
          trailing: isLoading
              ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: isLoading ? null : () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('데이터 복원'),
                content: const Text(
                    'Supabase의 데이터를 이 기기로 가져옵니다.\n'
                        '중복 항목은 자동으로 병합됩니다.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('복원')),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            final result = await ref
                .read(initialSyncProvider.notifier)
                .forcePull();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result.success
                  ? '${result.count}개 항목 복원 완료 ✅'
                  : '복원 실패: ${result.error}'),
              backgroundColor:
              result.success ? Colors.green : Colors.red,
            ));
          },
        ),
      ],
    );
  }
}