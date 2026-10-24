import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/buddy_profile.dart';
import '../../models/gym_branch.dart';
import '../../services/branch_service.dart';
import '../../services/buddy_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/ambient.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/decor.dart';
import '../../widgets/mascot.dart';

class BuddyOnboardingScreen extends StatefulWidget {
  final BuddyProfile? existingProfile;
  final BuddyService buddyService;
  final BranchService branchService;
  final String? homeGymId;

  const BuddyOnboardingScreen({
    super.key,
    this.existingProfile,
    this.buddyService = const BuddyService(),
    this.branchService = const BranchService(),
    this.homeGymId,
  });

  bool get isEditing =>
      existingProfile != null && existingProfile!.onboardingCompleted;

  @override
  State<BuddyOnboardingScreen> createState() => _BuddyOnboardingScreenState();
}

class _BuddyOnboardingScreenState extends State<BuddyOnboardingScreen> {
  // Goal
  String? _fitnessGoal;

  // Favorite workouts (multi)
  final Set<String> _favoriteWorkouts = {};

  // Level
  String? _experienceLevel;

  // Preferred workout times (multi)
  final Set<String> _preferredWorkoutTimes = {};

  // Workout style (multi)
  final Set<String> _workoutStyle = {};

  // Age & Gender
  final _ageController = TextEditingController();
  String? _gender;
  bool _showAge = true;
  bool _showGender = true;

  // Bio
  final _bioController = TextEditingController();

  // Looking for partner
  bool _lookingForPartner = false;
  DateTime? _partnerDate;
  TimeOfDay? _partnerStartTime;
  TimeOfDay? _partnerEndTime;
  String? _partnerWorkout;
  String? _partnerGymId;
  final _partnerNoteController = TextEditingController();

  // Enabled toggle
  bool _enabled = true;

  // Branches
  List<GymBranch> _branches = [];
  bool _loadingBranches = false;

  // Submit state
  bool _saving = false;
  String? _error;

  static const List<Map<String, String>> _goals = [
    {'value': 'MUSCLE_GAIN', 'label': 'Tăng cơ'},
    {'value': 'FAT_LOSS', 'label': 'Giảm mỡ'},
    {'value': 'MAINTAIN', 'label': 'Giữ dáng'},
    {'value': 'STRENGTH', 'label': 'Tăng sức mạnh'},
    {'value': 'HEALTH', 'label': 'Cải thiện sức khỏe'},
  ];

  static const List<String> _workouts = [
    'Leg Day',
    'Back',
    'Lat',
    'Chest',
    'Shoulder',
    'Arms',
    'Glutes',
    'Core / Abs',
    'Cardio',
    'Full Body',
  ];

  static const List<Map<String, String>> _levels = [
    {'value': 'BEGINNER', 'label': 'Mới bắt đầu'},
    {'value': 'INTERMEDIATE', 'label': 'Trung cấp'},
    {'value': 'ADVANCED', 'label': 'Nâng cao'},
  ];

  static const List<Map<String, String>> _times = [
    {'value': 'MORNING', 'label': 'Sáng'},
    {'value': 'NOON', 'label': 'Trưa'},
    {'value': 'AFTERNOON', 'label': 'Chiều'},
    {'value': 'EVENING', 'label': 'Tối'},
  ];

  static const List<String> _styles = [
    'Tập nghiêm túc',
    'Ít nói',
    'Dễ làm quen',
    'Thích trò chuyện',
    'Thích có spotter',
    'Thích tập theo plan',
    'Thích thử bài mới',
    'Thích tập nhóm',
  ];

  static const List<String> _genders = ['Nữ', 'Nam', 'Khác', 'Không muốn nói'];

  @override
  void initState() {
    super.initState();
    _initFromExisting();
    _loadBranches();
  }

  void _initFromExisting() {
    final p = widget.existingProfile;
    if (p == null) {
      _partnerGymId = widget.homeGymId;
      return;
    }

    _fitnessGoal = p.fitnessGoal;
    _favoriteWorkouts.addAll(p.favoriteWorkouts);
    _experienceLevel = p.experienceLevel;
    _preferredWorkoutTimes.addAll(p.preferredWorkoutTimes);
    _workoutStyle.addAll(p.workoutStyle);

    if (p.age != null) {
      _ageController.text = p.age.toString();
    }
    _gender = p.gender;
    _showAge = p.showAge;
    _showGender = p.showGender;

    if (p.bio != null) {
      _bioController.text = p.bio!;
    }

    _lookingForPartner = p.lookingForPartner;
    if (p.partnerDate != null) {
      _partnerDate = DateTime.tryParse(p.partnerDate!);
    }
    if (p.partnerStartTime != null) {
      final parts = p.partnerStartTime!.split(':');
      if (parts.length >= 2) {
        _partnerStartTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    if (p.partnerEndTime != null) {
      final parts = p.partnerEndTime!.split(':');
      if (parts.length >= 2) {
        _partnerEndTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    _partnerWorkout = p.partnerWorkout;
    _partnerGymId = p.partnerGymId ?? widget.homeGymId;
    if (p.partnerNote != null) {
      _partnerNoteController.text = p.partnerNote!;
    }

    _enabled = p.enabled;
  }

  Future<void> _loadBranches() async {
    setState(() => _loadingBranches = true);
    try {
      final branches = await widget.branchService.getBranches();
      if (mounted) {
        setState(() {
          _branches = branches;
          final preferredGymId = _partnerGymId ?? widget.homeGymId;
          final preferredGymExists =
              preferredGymId != null &&
              branches.any((branch) => branch.id == preferredGymId);
          _partnerGymId = preferredGymExists
              ? preferredGymId
              : (branches.isNotEmpty ? branches.first.id : null);
          _loadingBranches = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBranches = false);
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _bioController.dispose();
    _partnerNoteController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _partnerDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _partnerDate = picked);
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _partnerStartTime ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) {
      setState(() => _partnerStartTime = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _partnerEndTime ?? const TimeOfDay(hour: 19, minute: 30),
    );
    if (picked != null) {
      setState(() => _partnerEndTime = picked);
    }
  }

  void _validateAndSave() async {
    if (_saving) return;

    // Required fields check
    if (_fitnessGoal == null) {
      _showError('Vui lòng chọn mục tiêu tập luyện.');
      return;
    }

    if (_favoriteWorkouts.isEmpty) {
      _showError('Vui lòng chọn ít nhất 1 bài tập / nhóm cơ yêu thích.');
      return;
    }

    if (_experienceLevel == null) {
      _showError('Vui lòng chọn trình độ tập luyện.');
      return;
    }

    if (_preferredWorkoutTimes.isEmpty) {
      _showError('Vui lòng chọn ít nhất 1 khung giờ thường tập.');
      return;
    }

    int? parsedAge;
    if (_ageController.text.trim().isNotEmpty) {
      parsedAge = int.tryParse(_ageController.text.trim());
      if (parsedAge == null || parsedAge < 16 || parsedAge > 100) {
        _showError('Độ tuổi hợp lệ từ 16 đến 100.');
        return;
      }
    }

    if (_lookingForPartner) {
      if (_partnerDate == null) {
        _showError('Vui lòng chọn ngày muốn tập.');
        return;
      }
      if (_partnerStartTime == null || _partnerEndTime == null) {
        _showError('Vui lòng chọn đầy đủ giờ bắt đầu và giờ kết thúc.');
        return;
      }

      final startMin = _partnerStartTime!.hour * 60 + _partnerStartTime!.minute;
      final endMin = _partnerEndTime!.hour * 60 + _partnerEndTime!.minute;
      if (endMin <= startMin) {
        _showError('Giờ kết thúc phải sau giờ bắt đầu.');
        return;
      }

      if (_partnerWorkout == null) {
        _showError('Vui lòng chọn buổi tập đang tìm bạn.');
        return;
      }
      if (_partnerGymId == null) {
        _showError('Vui lòng chọn chi nhánh tập.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final payload = <String, dynamic>{
        'enabled': _enabled,
        'age': parsedAge,
        'gender': _gender,
        'show_age': _showAge,
        'show_gender': _showGender,
        'fitness_goal': _fitnessGoal,
        'experience_level': _experienceLevel,
        'favorite_workouts': _favoriteWorkouts.toList(),
        'preferred_workout_times': _preferredWorkoutTimes.toList(),
        'workout_style': _workoutStyle.toList(),
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'onboarding_completed': true,
        'looking_for_partner': _lookingForPartner,
        if (_lookingForPartner) ...{
          'partner_date': _partnerDate != null
              ? _formatDate(_partnerDate!)
              : null,
          'partner_start_time': _partnerStartTime != null
              ? _formatTime(_partnerStartTime!)
              : null,
          'partner_end_time': _partnerEndTime != null
              ? _formatTime(_partnerEndTime!)
              : null,
          'partner_workout': _partnerWorkout,
          'partner_gym_id': _partnerGymId,
          'partner_note': _partnerNoteController.text.trim().isEmpty
              ? null
              : _partnerNoteController.text.trim(),
        } else ...{
          'partner_date': null,
          'partner_start_time': null,
          'partner_end_time': null,
          'partner_workout': null,
          'partner_gym_id': null,
          'partner_note': null,
        },
      };

      await widget.buddyService.saveProfile(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Đã lưu thay đổi!'
                : 'Thiết lập Gym Buddy thành công!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
        _showError(_error!);
      }
    }
  }

  void _showError(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  int get _requiredDone => [
    _fitnessGoal != null,
    _favoriteWorkouts.isNotEmpty,
    _experienceLevel != null,
    _preferredWorkoutTimes.isNotEmpty,
  ].where((done) => done).length;

  Widget _hero() => HighlightCard(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF9B80FF), Color(0xFF7457F0)],
    ),
    glow: AppColors.purple,
    seed: 8,
    padding: const EdgeInsets.fromLTRB(20, 18, 8, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 62,
                  height: 34,
                  child: Stack(
                    children: [
                      _bubble(0, AppColors.primaryOrange, Icons.person_rounded),
                      _bubble(26, Colors.white, Icons.add_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kết nối bạn tập',
                  style: AppTextStyles.heading1.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chia sẻ sở thích để GymFlow gợi ý những người bạn tập phù hợp nhất.',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Mascot(width: 104, auraColor: Colors.white),
      ],
    ),
  );

  Widget _bubble(double left, Color color, IconData icon) => Positioned(
    left: left,
    top: 0,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF8B6CFF), width: 2.5),
      ),
      child: Icon(
        icon,
        size: 18,
        color: color == Colors.white ? AppColors.purple : AppColors.ink,
      ),
    ),
  );

  /// A numbered section card.
  Widget _section({
    required int number,
    required Color color,
    required String title,
    String? subtitle,
    bool required = false,
    Widget? trailing,
    required Widget child,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NumberTile(number, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: title),
                          if (required)
                            const TextSpan(
                              text: ' *',
                              style: TextStyle(color: AppColors.primaryOrange),
                            ),
                        ],
                      ),
                      style: AppTextStyles.heading2,
                    ),
                    if (subtitle != null)
                      Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );

  static const _chipShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  TextStyle _chipText(bool selected) => AppTextStyles.title.copyWith(
    fontSize: 13.5,
    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
    color: AppColors.ink,
  );

  BorderSide _chipSide(bool selected) =>
      BorderSide(color: selected ? AppColors.ink : AppColors.sand, width: 1.5);

  Widget _choice(String label, bool selected, ValueChanged<bool> onSelected) =>
      ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: AppColors.primaryOrange,
        side: _chipSide(selected),
        shape: _chipShape,
        labelStyle: _chipText(selected),
        onSelected: onSelected,
      );

  Widget _filter(String label, bool selected, ValueChanged<bool> onSelected) =>
      FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: AppColors.primaryOrange,
        side: _chipSide(selected),
        shape: _chipShape,
        labelStyle: _chipText(selected),
        onSelected: onSelected,
      );

  /// Tall card-like chip with an icon above the label.
  Widget _tile({
    required Widget icon,
    required String label,
    required bool selected,
    required double width,
    required ValueChanged<bool> onSelected,
    bool multi = false,
  }) {
    final content = SizedBox(
      width: width,
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: _chipText(selected)),
          ),
        ],
      ),
    );
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );
    final side = BorderSide(
      color: selected ? AppColors.primaryOrange : AppColors.sand,
      width: selected ? 2 : 1.5,
    );
    return multi
        ? FilterChip(
            label: content,
            selected: selected,
            showCheckmark: false,
            padding: EdgeInsets.zero,
            labelPadding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: Colors.white,
            selectedColor: AppColors.peach,
            side: side,
            shape: shape,
            onSelected: onSelected,
          )
        : ChoiceChip(
            label: content,
            selected: selected,
            showCheckmark: false,
            padding: EdgeInsets.zero,
            labelPadding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: Colors.white,
            selectedColor: AppColors.peach,
            side: side,
            shape: shape,
            onSelected: onSelected,
          );
  }

  Widget _levelBars(int level) => SizedBox(
    width: 24,
    height: 18,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 6,
            height: 6.0 + i * 6,
            decoration: BoxDecoration(
              color: i <= level
                  ? AppColors.primaryOrange
                  : const Color(0xFFD9D2F2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );

  static const _timeIcons = {
    'MORNING': (Icons.wb_twilight_rounded, Color(0xFFF2994A)),
    'NOON': (Icons.wb_sunny_outlined, Color(0xFFE0A100)),
    'AFTERNOON': (Icons.wb_twilight_rounded, AppColors.strongOrange),
    'EVENING': (Icons.nightlight_round, AppColors.purple),
  };

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        title: Text(title, style: AppTextStyles.title.copyWith(fontSize: 14)),
        value: value,
        contentPadding: EdgeInsets.zero,
        onChanged: onChanged,
      );

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBackdrop(
        topBlob: AppColors.peach,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              PageHeader(
                back: true,
                title: widget.isEditing
                    ? 'Chỉnh sửa sở thích'
                    : 'Thiết lập Gym Buddy',
                subtitle: '$_requiredDone/4 mục bắt buộc đã xong',
              ),
              _hero(),
              const SizedBox(height: 16),

              _section(
                number: 1,
                color: AppColors.primaryOrange,
                title: 'Mục tiêu của bạn',
                subtitle: 'Chọn mục tiêu chính trong giai đoạn này',
                required: true,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _goals.map((g) {
                    return _choice(
                      g['label']!,
                      _fitnessGoal == g['value'],
                      (selected) => setState(
                        () => _fitnessGoal = selected ? g['value'] : null,
                      ),
                    );
                  }).toList(),
                ),
              ),

              _section(
                number: 2,
                color: AppColors.purple,
                title: 'Bạn thích tập gì?',
                subtitle:
                    'Chọn các nhóm cơ hoặc buổi tập yêu thích (tối thiểu 1)',
                required: true,
                trailing: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: StatusPill(
                    '${_favoriteWorkouts.length} đã chọn',
                    color: AppColors.purple,
                    background: AppColors.lavender,
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _workouts.map((w) {
                    return _filter(
                      w,
                      _favoriteWorkouts.contains(w),
                      (selected) => setState(() {
                        if (selected) {
                          _favoriteWorkouts.add(w);
                        } else {
                          _favoriteWorkouts.remove(w);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ),

              _section(
                number: 3,
                color: AppColors.success,
                title: 'Trình độ tập luyện',
                subtitle: 'Giúp bạn tìm người tập cùng tốc độ và mức tạ',
                required: true,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final width = (c.maxWidth - 2 * 8) / 3 - 6;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _levels.length; i++)
                          _tile(
                            icon: _levelBars(i),
                            label: _levels[i]['label']!,
                            selected: _experienceLevel == _levels[i]['value'],
                            width: width,
                            onSelected: (selected) => setState(
                              () => _experienceLevel = selected
                                  ? _levels[i]['value']
                                  : null,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              _section(
                number: 4,
                color: const Color(0xFFF5B400),
                title: 'Thường tập lúc nào?',
                subtitle: 'Chọn các buổi trong ngày bạn thường đến phòng gym (tối thiểu 1)',
                required: true,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final width = (c.maxWidth - 3 * 8) / 4 - 6;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _times.map((t) {
                        final (icon, tint) = _timeIcons[t['value']]!;
                        return _tile(
                          icon: Icon(icon, color: tint, size: 24),
                          label: t['label']!,
                          selected: _preferredWorkoutTimes.contains(t['value']),
                          width: width,
                          multi: true,
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _preferredWorkoutTimes.add(t['value']!);
                            } else {
                              _preferredWorkoutTimes.remove(t['value']!);
                            }
                          }),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),

              _section(
                number: 5,
                color: const Color(0xFFFF5E8A),
                title: 'Phong cách tập luyện',
                subtitle: 'Tính cách khi vào buổi tập của bạn',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _styles.map((s) {
                    return _filter(
                      s,
                      _workoutStyle.contains(s),
                      (selected) => setState(() {
                        if (selected) {
                          _workoutStyle.add(s);
                        } else {
                          _workoutStyle.remove(s);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ),

              _section(
                number: 6,
                color: AppColors.info,
                title: 'Thông tin hiển thị',
                subtitle: 'Tuổi và giới tính hiển thị trên thẻ Buddy Card',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _fieldLabel('Tuổi (không bắt buộc)'),
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Ví dụ: 25'),
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel('Giới tính'),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.field,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final width = (c.maxWidth - 3 * 4) / 4 - 4;
                          return Wrap(
                            spacing: 4,
                            children: _genders.map((g) {
                              final selected = _gender == g;
                              return ChoiceChip(
                                label: SizedBox(
                                  width: width,
                                  height: 38,
                                  child: Center(
                                    child: Text(
                                      g,
                                      textAlign: TextAlign.center,
                                      style: _chipText(
                                        selected,
                                      ).copyWith(fontSize: 11.5, height: 1.15),
                                    ),
                                  ),
                                ),
                                selected: selected,
                                showCheckmark: false,
                                padding: EdgeInsets.zero,
                                labelPadding: EdgeInsets.zero,
                                backgroundColor: Colors.transparent,
                                selectedColor: Colors.white,
                                side: BorderSide.none,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(11),
                                  ),
                                ),
                                onSelected: (selected) {
                                  setState(() => _gender = selected ? g : null);
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 20),
                    _switch(
                      'Hiển thị tuổi trên Buddy Card',
                      _showAge,
                      (val) => setState(() => _showAge = val),
                    ),
                    _switch(
                      'Hiển thị giới tính trên Buddy Card',
                      _showGender,
                      (val) => setState(() => _showGender = val),
                    ),
                  ],
                ),
              ),

              _section(
                number: 7,
                color: AppColors.ink,
                title: 'Giới thiệu ngắn',
                subtitle:
                    'Một vài câu về thói quen hoặc mong muốn khi tìm bạn tập',
                child: TextField(
                  controller: _bioController,
                  maxLength: 200,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Thích tập nghiêm túc, đang tìm bạn tập Leg Day buổi tối...',
                  ),
                ),
              ),

              // Looking for partner
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        secondary: const IconTile(
                          Icons.group_add_rounded,
                          color: AppColors.success,
                          background: AppColors.mint,
                        ),
                        title: const Text(
                          'Đang tìm bạn tập',
                          style: AppTextStyles.heading2,
                        ),
                        subtitle: const Text(
                          'Hiển thị khi bạn muốn tìm người tập cùng trong thời gian cụ thể.',
                          style: AppTextStyles.caption,
                        ),
                        value: _lookingForPartner,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) =>
                            setState(() => _lookingForPartner = val),
                      ),
                      if (_lookingForPartner) ...[
                        const Divider(height: 24),
                        DashedBox(
                          onTap: _selectDate,
                          child: ListTile(
                            leading: const Icon(
                              Icons.calendar_month_rounded,
                              color: AppColors.primaryOrange,
                            ),
                            title: Text(
                              _partnerDate == null
                                  ? 'Chọn ngày muốn tập'
                                  : 'Ngày: ${_formatDate(_partnerDate!)}',
                              style: AppTextStyles.body,
                            ),
                            trailing: TextButton(
                              onPressed: _selectDate,
                              child: const Text('Chọn ngày'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.access_time),
                                label: Text(
                                  _partnerStartTime == null
                                      ? 'Bắt đầu'
                                      : _formatTime(_partnerStartTime!),
                                ),
                                onPressed: _selectStartTime,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.access_time_filled),
                                label: Text(
                                  _partnerEndTime == null
                                      ? 'Kết thúc'
                                      : _formatTime(_partnerEndTime!),
                                ),
                                onPressed: _selectEndTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('Buổi tập cụ thể:'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _workouts.map((w) {
                            return _choice(
                              w,
                              _partnerWorkout == w,
                              (selected) => setState(
                                () => _partnerWorkout = selected ? w : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('Chi nhánh tập:'),
                        if (_loadingBranches)
                          const LinearProgressIndicator()
                        else
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _partnerGymId,
                            items: _branches.map((b) {
                              return DropdownMenuItem(
                                value: b.id,
                                child: Text(
                                  '${b.name} (${b.district})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _partnerGymId = val),
                          ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _partnerNoteController,
                          maxLength: 160,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú cho buổi tập (tuỳ chọn)',
                            hintText: 'Cùng đẩy ngực tạ đơn hoặc hỗ trợ spotter nhé...',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SwitchListTile(
                  title: Text(
                    'Cho phép xuất hiện trong Kết nối bạn tập',
                    style: AppTextStyles.title.copyWith(fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Khi tắt, bạn sẽ tạm thời không xuất hiện trên thẻ tìm bạn tập của hội viên khác.',
                    style: AppTextStyles.caption,
                  ),
                  value: _enabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _enabled = val),
                ),
              ),
              const SizedBox(height: 24),

              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              AppButton(
                text: widget.isEditing ? 'Lưu thay đổi' : 'Hoàn tất',
                isLoading: _saving,
                onPressed: _validateAndSave,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
