import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/buddy_match.dart';
import '../../models/buddy_profile.dart';
import '../../services/buddy_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../chat/conversation_screen.dart';
import 'buddy_group_create_screen.dart';

class BuddyMatchesScreen extends StatefulWidget {
  final BuddyProfile profile;
  final BuddyService buddyService;

  const BuddyMatchesScreen({
    super.key,
    required this.profile,
    this.buddyService = const BuddyService(),
  });

  @override
  State<BuddyMatchesScreen> createState() => _BuddyMatchesScreenState();
}

class _BuddyMatchesScreenState extends State<BuddyMatchesScreen> {
  List<BuddyMatch> _matches = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

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

  Future<void> _openChat(BuddyMatch match) async {
    final conversationId = match.conversationId;
    if (conversationId == null || conversationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có phòng chat cho kết nối này.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          conversationId: conversationId,
          userId: widget.profile.userId,
          title: match.otherUserName,
        ),
      ),
    );
  }

  Future<void> _openGroupCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuddyGroupCreateScreen(
          profile: widget.profile,
          buddyService: widget.buddyService,
        ),
      ),
    );
    if (mounted) await _loadMatches();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn tập đã kết nối'),
        actions: [
          IconButton(
            tooltip: 'Tạo nhóm bạn tập',
            onPressed: _openGroupCreate,
            icon: const Icon(Icons.groups_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
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
                  'Không thể tải Gym Buddy',
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

    if (_matches.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMatches,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 120),
            AppCard(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.handshake_outlined,
                      size: 36,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có Gym Buddy đã kết nối',
                    style: AppTextStyles.heading2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Khi hai bạn cùng chọn Kết nối, người đó sẽ xuất hiện ở đây để bạn có thể nhắn tin lại bất cứ lúc nào.',
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMatches,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Những người đã match với bạn. Chạm vào một người để mở lại chat 1–1.',
              style: AppTextStyles.caption,
            ),
          ),
          ..._matches.map(
            (match) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  onTap: () => _openChat(match),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: ClipOval(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: AppImage(
                        url: match.otherAvatarUrl ?? '',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                  ),
                  title: Text(
                    match.otherUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Gym Buddy · Đã kết nối'),
                  trailing: IconButton(
                    tooltip: 'Nhắn tin',
                    onPressed: () => _openChat(match),
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
