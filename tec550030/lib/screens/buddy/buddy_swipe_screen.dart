import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/buddy_profile.dart';
import '../../services/branch_service.dart';
import '../../services/buddy_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../chat/conversation_screen.dart';
import 'buddy_group_create_screen.dart';
import 'buddy_onboarding_screen.dart';

class BuddySwipeScreen extends StatefulWidget {
  final BuddyProfile profile;
  final BuddyService buddyService;
  final BranchService branchService;

  const BuddySwipeScreen({
    super.key,
    required this.profile,
    this.buddyService = const BuddyService(),
    this.branchService = const BranchService(),
  });

  @override
  State<BuddySwipeScreen> createState() => _BuddySwipeScreenState();
}

class _BuddySwipeScreenState extends State<BuddySwipeScreen> {
  late BuddyProfile _ownProfile;
  List<BuddyProfile> _remainingCandidates = const [];
  bool _loading = true;
  bool _submitting = false;
  bool _showBack = false;
  String? _error;
  double _dragX = 0;

  String? _filterGymId;
  String? _filterGoal;
  String? _filterWorkout;
  String? _filterTime;

  static const double _swipeThreshold = 90;

  @override
  void initState() {
    super.initState();
    _ownProfile = widget.profile;
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final candidates = await widget.buddyService.getFeed(limit: 20);
      if (!mounted) return;
      setState(() {
        _remainingCandidates = candidates;
        _loading = false;
        _showBack = false;
        _dragX = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _hasActiveFilters =>
      _filterGymId != null ||
      _filterGoal != null ||
      _filterWorkout != null ||
      _filterTime != null;

  List<BuddyProfile> get _filteredCandidates => _remainingCandidates.where((p) {
        if (_filterGymId != null && p.homeGymId != _filterGymId) return false;
        if (_filterGoal != null && p.fitnessGoal != _filterGoal) return false;
        if (_filterWorkout != null &&
            !p.favoriteWorkouts.contains(_filterWorkout)) {
          return false;
        }
        if (_filterTime != null &&
            !p.preferredWorkoutTimes.contains(_filterTime)) {
          return false;
        }
        return true;
      }).toList(growable: false);

  BuddyProfile? get _current {
    final filtered = _filteredCandidates;
    return filtered.isEmpty ? null : filtered.first;
  }

  void _clearFilters() {
    setState(() {
      _filterGymId = null;
      _filterGoal = null;
      _filterWorkout = null;
      _filterTime = null;
      _showBack = false;
      _dragX = 0;
    });
  }

  Future<void> _showFilters() async {
    String? gymId = _filterGymId;
    String? goal = _filterGoal;
    String? workout = _filterWorkout;
    String? time = _filterTime;

    final gymLabels = <String, String>{};
    for (final p in _remainingCandidates) {
      if (p.homeGymId != null) {
        gymLabels[p.homeGymId!] = [
          if (p.gymName != null && p.gymName!.isNotEmpty) p.gymName!,
          if (p.district != null && p.district!.isNotEmpty) p.district!,
        ].join(' · ');
      }
    }

    final goals = _remainingCandidates
        .map((p) => p.fitnessGoal)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final workouts = _remainingCandidates
        .expand((p) => p.favoriteWorkouts)
        .toSet()
        .toList()
      ..sort();
    final times = _remainingCandidates
        .expand((p) => p.preferredWorkoutTimes)
        .toSet()
        .toList()
      ..sort();

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Widget choiceRow({
            required String title,
            required List<MapEntry<String, String>> options,
            required String? selected,
            required ValueChanged<String?> onSelected,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.heading2),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả'),
                      selected: selected == null,
                      onSelected: (_) => onSelected(null),
                    ),
                    ...options.map(
                      (option) => ChoiceChip(
                        label: Text(option.value),
                        selected: selected == option.key,
                        onSelected: (_) => onSelected(option.key),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Bộ lọc bạn tập', style: AppTextStyles.heading1),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(() {
                          gymId = null;
                          goal = null;
                          workout = null;
                          time = null;
                        }),
                        child: const Text('Xóa lọc'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  choiceRow(
                    title: 'Chi nhánh',
                    options: gymLabels.entries
                        .map(
                          (e) => MapEntry(
                            e.key,
                            e.value.isEmpty ? 'Chi nhánh GymFlow' : e.value,
                          ),
                        )
                        .toList(),
                    selected: gymId,
                    onSelected: (value) => setSheetState(() => gymId = value),
                  ),
                  const SizedBox(height: 22),
                  choiceRow(
                    title: 'Mục tiêu',
                    options: goals
                        .map((value) => MapEntry(value, _goalLabel(value)))
                        .toList(),
                    selected: goal,
                    onSelected: (value) => setSheetState(() => goal = value),
                  ),
                  const SizedBox(height: 22),
                  choiceRow(
                    title: 'Bài tập',
                    options: workouts
                        .map((value) => MapEntry(value, value))
                        .toList(),
                    selected: workout,
                    onSelected: (value) =>
                        setSheetState(() => workout = value),
                  ),
                  const SizedBox(height: 22),
                  choiceRow(
                    title: 'Khung giờ',
                    options: times
                        .map((value) => MapEntry(value, _timeLabel(value)))
                        .toList(),
                    selected: time,
                    onSelected: (value) => setSheetState(() => time = value),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (apply == true && mounted) {
      setState(() {
        _filterGymId = gymId;
        _filterGoal = goal;
        _filterWorkout = workout;
        _filterTime = time;
        _showBack = false;
        _dragX = 0;
      });
    }
  }

  Future<void> _editProfile() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BuddyOnboardingScreen(
          existingProfile: _ownProfile,
          buddyService: widget.buddyService,
          branchService: widget.branchService,
          homeGymId: _ownProfile.homeGymId,
        ),
      ),
    );

    if (changed == true && mounted) {
      try {
        final refreshed = await widget.buddyService.getProfile();
        if (refreshed != null && mounted) {
          setState(() => _ownProfile = refreshed);
        }
      } catch (_) {
        // The saved profile is already persisted; failure to refresh should not
        // block the swipe screen.
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_submitting) return;
    setState(() => _dragX += details.delta.dx);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_submitting) return;
    if (_dragX >= _swipeThreshold) {
      _submitSwipe('LIKE');
    } else if (_dragX <= -_swipeThreshold) {
      _submitSwipe('PASS');
    } else {
      setState(() => _dragX = 0);
    }
  }

  Future<void> _submitSwipe(String action) async {
    final candidate = _current;
    if (candidate == null || _submitting) return;

    setState(() => _submitting = true);

    try {
      final result = await widget.buddyService.swipe(candidate.userId, action);
      if (!mounted) return;

      final matched = result['matched'] == true;
      setState(() {
        _remainingCandidates = _remainingCandidates
            .where((p) => p.userId != candidate.userId)
            .toList(growable: false);
        _submitting = false;
        _showBack = false;
        _dragX = 0;
      });

      if (matched) {
        await _showMatchDialog(candidate, result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _dragX = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu lựa chọn: $e')),
      );
    }
  }

  Future<void> _showMatchDialog(
    BuddyProfile candidate,
    Map<String, dynamic> result,
  ) async {
    final conversationId = result['conversation_id'] as String?;
    final openChat = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.handshake_outlined, color: AppColors.success),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Gym Match!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor:
                  AppColors.primaryOrange.withValues(alpha: 0.10),
              child: const Icon(
                Icons.people_alt_outlined,
                size: 36,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Bạn và ${candidate.name} cùng muốn kết nối.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Gửi lời chào và lên lịch buổi tập đầu tiên nhé.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tiếp tục xem'),
          ),
          FilledButton.icon(
            onPressed: conversationId == null || conversationId.isEmpty
                ? null
                : () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Nhắn tin'),
          ),
        ],
      ),
    );

    if (openChat == true &&
        mounted &&
        conversationId != null &&
        conversationId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            conversationId: conversationId,
            userId: _ownProfile.userId,
            title: candidate.name,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết nối bạn tập'),
        actions: [
          IconButton(
            tooltip: 'Tạo nhóm bạn tập',
            onPressed: _submitting
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BuddyGroupCreateScreen(
                        profile: _ownProfile,
                        buddyService: widget.buddyService,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.groups_outlined),
          ),
          IconButton(
            tooltip: 'Bộ lọc',
            onPressed: _submitting ? null : _showFilters,
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              child: const Icon(Icons.filter_list_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Chỉnh sửa sở thích',
            onPressed: _submitting ? null : _editProfile,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

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
                  'Không thể tải danh sách bạn tập',
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
                  onPressed: _loadFeed,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final candidate = _current;
    if (candidate == null) {
      final filteredEmpty =
          _hasActiveFilters && _remainingCandidates.isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    filteredEmpty
                        ? Icons.filter_alt_off_outlined
                        : Icons.people_outline,
                    size: 36,
                    color: AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  filteredEmpty
                      ? 'Không có hồ sơ phù hợp bộ lọc'
                      : 'Hết hồ sơ phù hợp lúc này',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  filteredEmpty
                      ? 'Thử nới bộ lọc để xem thêm bạn tập.'
                      : 'Bạn có thể quay lại sau khi có thêm hội viên phù hợp.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: filteredEmpty ? _clearFilters : _loadFeed,
                  icon: Icon(
                    filteredEmpty ? Icons.filter_alt_off : Icons.refresh,
                  ),
                  label: Text(filteredEmpty ? 'Xóa bộ lọc' : 'Tải lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Column(
        children: [
          Text(
            _hasActiveFilters
                ? 'Đang lọc · ${_filteredCandidates.length} hồ sơ còn lại'
                : 'Chạm vào thẻ để xem thêm · Vuốt để chọn',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final rotation = (_dragX / math.max(constraints.maxWidth, 1)) * 0.08;
                    return Transform.translate(
                      offset: Offset(_dragX, 0),
                      child: Transform.rotate(
                        angle: rotation,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _submitting
                              ? null
                              : () => setState(() => _showBack = !_showBack),
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _BuddyFlipCard(
                                key: ValueKey(candidate.userId),
                                profile: candidate,
                                showBack: _showBack,
                              ),
                              if (_dragX.abs() > 16)
                                Positioned(
                                  top: 24,
                                  left: _dragX > 0 ? 24 : null,
                                  right: _dragX < 0 ? 24 : null,
                                  child: _SwipeStamp(
                                    text: _dragX > 0 ? 'KẾT NỐI' : 'BỎ QUA',
                                    icon: _dragX > 0
                                        ? Icons.handshake_outlined
                                        : Icons.close_rounded,
                                    positive: _dragX > 0,
                                  ),
                                ),
                              if (_submitting)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionButton(
                tooltip: 'Bỏ qua',
                icon: Icons.close_rounded,
                foreground: AppColors.error,
                onPressed: _submitting ? null : () => _submitSwipe('PASS'),
              ),
              const SizedBox(width: 28),
              _ActionButton(
                tooltip: 'Kết nối',
                icon: Icons.handshake_outlined,
                foreground: AppColors.success,
                onPressed: _submitting ? null : () => _submitSwipe('LIKE'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BuddyFlipCard extends StatelessWidget {
  final BuddyProfile profile;
  final bool showBack;

  const _BuddyFlipCard({
    super.key,
    required this.profile,
    required this.showBack,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: showBack ? math.pi : 0),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOut,
      builder: (context, angle, _) {
        final isBack = angle > math.pi / 2;
        final content = isBack
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(math.pi),
                child: _BuddyBack(profile: profile),
              )
            : _BuddyFront(profile: profile);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: content,
        );
      },
    );
  }
}

class _BuddyFront extends StatelessWidget {
  final BuddyProfile profile;

  const _BuddyFront({required this.profile});

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (profile.age != null) '${profile.age}',
      if (profile.gender != null && profile.gender!.isNotEmpty) profile.gender!,
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Expanded(
              flex: 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(
                    url: profile.avatarUrl ?? '',
                    icon: Icons.person_outline_rounded,
                  ),
                  if (profile.lookingForPartner)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Đang tìm bạn tập',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            profile.name,
                            style: AppTextStyles.heading1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(details.join(' · '), style: AppTextStyles.body),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.primaryOrange,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _branchLabel(profile),
                            style: AppTextStyles.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Chạm để xem mục tiêu, lịch tập và phong cách tập',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuddyBack extends StatelessWidget {
  final BuddyProfile profile;

  const _BuddyBack({required this.profile});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(profile.name, style: AppTextStyles.heading1),
                ),
                const Icon(
                  Icons.flip_rounded,
                  color: AppColors.primaryOrange,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_branchLabel(profile), style: AppTextStyles.caption),
            const Divider(height: 28),
            if (profile.fitnessGoal != null)
              _DetailRow(
                icon: Icons.flag_outlined,
                label: 'Mục tiêu',
                value: _goalLabel(profile.fitnessGoal!),
              ),
            if (profile.experienceLevel != null)
              _DetailRow(
                icon: Icons.trending_up_rounded,
                label: 'Trình độ',
                value: _levelLabel(profile.experienceLevel!),
              ),
            if (profile.favoriteWorkouts.isNotEmpty)
              _DetailRow(
                icon: Icons.fitness_center_rounded,
                label: 'Thích tập',
                value: profile.favoriteWorkouts.join(', '),
              ),
            if (profile.preferredWorkoutTimes.isNotEmpty)
              _DetailRow(
                icon: Icons.schedule_outlined,
                label: 'Khung giờ',
                value: profile.preferredWorkoutTimes
                    .map(_timeLabel)
                    .join(', '),
              ),
            if (profile.workoutStyle.isNotEmpty)
              _DetailRow(
                icon: Icons.psychology_alt_outlined,
                label: 'Phong cách',
                value: profile.workoutStyle.join(', '),
              ),
            if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              const Text('Giới thiệu', style: AppTextStyles.heading2),
              const SizedBox(height: 6),
              Text(profile.bio!, style: AppTextStyles.body),
            ],
            if (profile.lookingForPartner) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đang tìm bạn tập',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (profile.partnerDate != null) profile.partnerDate!,
                        if (profile.partnerStartTime != null &&
                            profile.partnerEndTime != null)
                          '${profile.partnerStartTime}–${profile.partnerEndTime}',
                        if (profile.partnerWorkout != null)
                          profile.partnerWorkout!,
                      ].join(' · '),
                      style: AppTextStyles.body,
                    ),
                    if (profile.partnerGymName != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        profile.partnerGymName!,
                        style: AppTextStyles.caption,
                      ),
                    ],
                    if (profile.partnerNote != null &&
                        profile.partnerNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(profile.partnerNote!, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'Chạm lại để quay về mặt trước',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryOrange),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(child: Text(value, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color foreground;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.foreground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 62,
        height: 62,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: foreground,
            backgroundColor: Colors.white,
            padding: EdgeInsets.zero,
            side: BorderSide(color: foreground.withValues(alpha: 0.35)),
            shape: const CircleBorder(),
          ),
          child: Icon(icon, size: 30),
        ),
      ),
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool positive;

  const _SwipeStamp({
    required this.text,
    required this.icon,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.success : AppColors.error;
    return Transform.rotate(
      angle: positive ? -0.08 : 0.08,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _branchLabel(BuddyProfile profile) {
  final parts = <String>[
    if (profile.gymName != null && profile.gymName!.isNotEmpty)
      profile.gymName!,
    if (profile.district != null && profile.district!.isNotEmpty)
      profile.district!,
  ];
  return parts.isEmpty ? 'Chi nhánh GymFlow' : parts.join(' · ');
}

String _goalLabel(String value) => switch (value) {
      'MUSCLE_GAIN' => 'Tăng cơ',
      'FAT_LOSS' => 'Giảm mỡ',
      'MAINTAIN' => 'Giữ dáng',
      'STRENGTH' => 'Tăng sức mạnh',
      'HEALTH' => 'Cải thiện sức khỏe',
      _ => value,
    };

String _levelLabel(String value) => switch (value) {
      'BEGINNER' => 'Mới bắt đầu',
      'INTERMEDIATE' => 'Trung cấp',
      'ADVANCED' => 'Nâng cao',
      _ => value,
    };

String _timeLabel(String value) => switch (value) {
      'MORNING' => 'Sáng',
      'NOON' => 'Trưa',
      'AFTERNOON' => 'Chiều',
      'EVENING' => 'Tối',
      _ => value,
    };
