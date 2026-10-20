import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/buddy_match.dart';
import '../../models/buddy_profile.dart';
import '../../services/buddy_service.dart';
import '../../widgets/app_card.dart';
import '../chat/conversation_screen.dart';

class BuddyGroupCreateScreen extends StatefulWidget {
  final BuddyProfile profile;
  final BuddyService buddyService;

  const BuddyGroupCreateScreen({
    super.key,
    required this.profile,
    this.buddyService = const BuddyService(),
  });

  @override
  State<BuddyGroupCreateScreen> createState() => _BuddyGroupCreateScreenState();
}

class _BuddyGroupCreateScreenState extends State<BuddyGroupCreateScreen> {
  final _titleController = TextEditingController();
  final Set<String> _selectedIds = {};
  List<BuddyMatch> _matches = const [];
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final matches = await widget.buddyService.getMatches();
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createGroup() async {
    if (_creating) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('Vui lòng nhập tên nhóm.');
      return;
    }
    if (title.length > 80) {
      _showError('Tên nhóm tối đa 80 ký tự.');
      return;
    }
    if (_selectedIds.length < 2) {
      _showError('Chọn ít nhất 2 Gym Buddy để tạo nhóm.');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final result = await widget.buddyService.createGroup(
        title,
        _selectedIds.toList(growable: false),
      );
      if (!mounted) return;

      final conversationId = result['conversation_id'] as String?;
      if (conversationId == null || conversationId.isEmpty) {
        throw StateError('Không nhận được conversation_id.');
      }

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            conversationId: conversationId,
            userId: widget.profile.userId,
            title: title,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      _showError('Không thể tạo nhóm: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo nhóm bạn tập')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 42,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Không thể tải danh sách Gym Buddy',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loadMatches,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_matches.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.groups_outlined,
                  size: 46,
                  color: AppColors.primaryOrange,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Cần ít nhất 2 Gym Buddy đã match',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hãy kết nối thêm bạn tập trước khi tạo group chat.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: _titleController,
                maxLength: 80,
                enabled: !_creating,
                decoration: const InputDecoration(
                  labelText: 'Tên nhóm',
                  hintText: 'Ví dụ: Leg Day tối thứ 5',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chọn Gym Buddy',
                      style: AppTextStyles.heading2,
                    ),
                  ),
                  Text(
                    '${_selectedIds.length} đã chọn',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Chỉ những người đã match với bạn mới có thể được thêm vào nhóm.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 14),
              ..._matches.map(
                (match) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: CheckboxListTile(
                      value: _selectedIds.contains(match.otherUserId),
                      onChanged: _creating
                          ? null
                          : (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedIds.add(match.otherUserId);
                                } else {
                                  _selectedIds.remove(match.otherUserId);
                                }
                              });
                            },
                      secondary: CircleAvatar(
                        backgroundColor:
                            AppColors.primaryOrange.withValues(alpha: 0.10),
                        child: const Icon(
                          Icons.person_outline,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                      title: Text(match.otherUserName),
                      subtitle: const Text('Đã match'),
                      activeColor: AppColors.primaryOrange,
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _creating ? null : _createGroup,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.groups_rounded),
              label: Text(_creating ? 'Đang tạo...' : 'Tạo nhóm và mở chat'),
            ),
          ),
        ),
      ],
    );
  }
}
