import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/buddy_profile.dart';
import '../../models/gym_branch.dart';
import '../../services/branch_service.dart';
import '../../services/buddy_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

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

  bool get isEditing => existingProfile != null && existingProfile!.onboardingCompleted;

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
          final preferredGymExists = preferredGymId != null &&
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
        'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        'onboarding_completed': true,
        'looking_for_partner': _lookingForPartner,
        if (_lookingForPartner) ...{
          'partner_date': _partnerDate != null ? _formatDate(_partnerDate!) : null,
          'partner_start_time': _partnerStartTime != null ? _formatTime(_partnerStartTime!) : null,
          'partner_end_time': _partnerEndTime != null ? _formatTime(_partnerEndTime!) : null,
          'partner_workout': _partnerWorkout,
          'partner_gym_id': _partnerGymId,
          'partner_note': _partnerNoteController.text.trim().isEmpty ? null : _partnerNoteController.text.trim(),
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
          content: Text(widget.isEditing ? 'Đã lưu thay đổi!' : 'Thiết lập Gym Buddy thành công!'),
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
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Chỉnh sửa sở thích' : 'Thiết lập Gym Buddy'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header card
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      color: AppColors.primaryOrange,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kết nối bạn tập', style: AppTextStyles.heading2),
                        SizedBox(height: 4),
                        Text(
                          'Chia sẻ sở thích để GymFlow gợi ý những người bạn tập phù hợp nhất.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 1. Goal
            _SectionHeader(
              title: '1. Mục tiêu của bạn *',
              subtitle: 'Chọn mục tiêu chính trong giai đoạn này',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _goals.map((g) {
                final isSelected = _fitnessGoal == g['value'];
                return ChoiceChip(
                  label: Text(g['label']!),
                  selected: isSelected,
                  selectedColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.strongOrange : AppColors.darkText,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (selected) {
                    setState(() => _fitnessGoal = selected ? g['value'] : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 2. Favorite workouts
            _SectionHeader(
              title: '2. Bạn thích tập gì? *',
              subtitle: 'Chọn các nhóm cơ hoặc buổi tập yêu thích (tối thiểu 1)',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _workouts.map((w) {
                final isSelected = _favoriteWorkouts.contains(w);
                return FilterChip(
                  label: Text(w),
                  selected: isSelected,
                  selectedColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.strongOrange : AppColors.darkText,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _favoriteWorkouts.add(w);
                      } else {
                        _favoriteWorkouts.remove(w);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 3. Level
            _SectionHeader(
              title: '3. Trình độ tập luyện *',
              subtitle: 'Giúp bạn tìm người tập cùng tốc độ và mức tạ',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _levels.map((l) {
                final isSelected = _experienceLevel == l['value'];
                return ChoiceChip(
                  label: Text(l['label']!),
                  selected: isSelected,
                  selectedColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.strongOrange : AppColors.darkText,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (selected) {
                    setState(() => _experienceLevel = selected ? l['value'] : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 4. Preferred times
            _SectionHeader(
              title: '4. Thường tập lúc nào? *',
              subtitle: 'Chọn các buổi trong ngày bạn thường đến phòng gym (tối thiểu 1)',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _times.map((t) {
                final isSelected = _preferredWorkoutTimes.contains(t['value']);
                return FilterChip(
                  label: Text(t['label']!),
                  selected: isSelected,
                  selectedColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.strongOrange : AppColors.darkText,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _preferredWorkoutTimes.add(t['value']!);
                      } else {
                        _preferredWorkoutTimes.remove(t['value']!);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 5. Workout style
            _SectionHeader(
              title: '5. Phong cách tập luyện',
              subtitle: 'Tính cách khi vào buổi tập của bạn',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _styles.map((s) {
                final isSelected = _workoutStyle.contains(s);
                return FilterChip(
                  label: Text(s),
                  selected: isSelected,
                  selectedColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.strongOrange : AppColors.darkText,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _workoutStyle.add(s);
                      } else {
                        _workoutStyle.remove(s);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 6. Age & Gender
            _SectionHeader(
              title: '6. Thông tin hiển thị',
              subtitle: 'Tuổi và giới tính hiển thị trên thẻ Buddy Card',
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tuổi (không bắt buộc)',
                      hintText: 'Nhập tuổi từ 16–100',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Giới tính:', style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _genders.map((g) {
                      final isSelected = _gender == g;
                      return ChoiceChip(
                        label: Text(g),
                        selected: isSelected,
                        selectedColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.strongOrange : AppColors.darkText,
                        ),
                        onSelected: (selected) {
                          setState(() => _gender = selected ? g : null);
                        },
                      );
                    }).toList(),
                  ),
                  const Divider(height: 28),
                  SwitchListTile(
                    title: const Text('Hiển thị tuổi trên Buddy Card'),
                    value: _showAge,
                    activeThumbColor: AppColors.primaryOrange,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _showAge = val),
                  ),
                  SwitchListTile(
                    title: const Text('Hiển thị giới tính trên Buddy Card'),
                    value: _showGender,
                    activeThumbColor: AppColors.primaryOrange,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _showGender = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 7. Bio
            _SectionHeader(
              title: '7. Giới thiệu ngắn',
              subtitle: 'Một vài câu về thói quen hoặc mong muốn khi tìm bạn tập',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bioController,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Thích tập nghiêm túc, đang tìm bạn tập Leg Day buổi tối...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // 8. Looking for partner
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Đang tìm bạn tập', style: AppTextStyles.heading2),
                    subtitle: const Text(
                      'Hiển thị khi bạn muốn tìm người tập cùng trong thời gian cụ thể.',
                      style: AppTextStyles.caption,
                    ),
                    value: _lookingForPartner,
                    activeThumbColor: AppColors.primaryOrange,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _lookingForPartner = val),
                  ),
                  if (_lookingForPartner) ...[
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, color: AppColors.primaryOrange),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(_partnerStartTime == null
                                ? 'Bắt đầu'
                                : _formatTime(_partnerStartTime!)),
                            onPressed: _selectStartTime,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time_filled),
                            label: Text(_partnerEndTime == null
                                ? 'Kết thúc'
                                : _formatTime(_partnerEndTime!)),
                            onPressed: _selectEndTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Buổi tập cụ thể:', style: AppTextStyles.caption),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _workouts.map((w) {
                        final isSelected = _partnerWorkout == w;
                        return ChoiceChip(
                          label: Text(w),
                          selected: isSelected,
                          selectedColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                          onSelected: (selected) {
                            setState(() => _partnerWorkout = selected ? w : null);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Chi nhánh tập:', style: AppTextStyles.caption),
                    const SizedBox(height: 6),
                    if (_loadingBranches)
                      const LinearProgressIndicator()
                    else
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _partnerGymId,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: _branches.map((b) {
                          return DropdownMenuItem(
                            value: b.id,
                            child: Text(
                              '${b.name} (${b.district})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _partnerGymId = val),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _partnerNoteController,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú cho buổi tập (tuỳ chọn)',
                        hintText: 'Cùng đẩy ngực tạ đơn hoặc hỗ trợ spotter nhé...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 9. Enable / Disable toggle
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SwitchListTile(
                title: const Text('Cho phép xuất hiện trong Kết nối bạn tập'),
                subtitle: const Text(
                  'Khi tắt, bạn sẽ tạm thời không xuất hiện trên thẻ tìm bạn tập của hội viên khác.',
                  style: AppTextStyles.caption,
                ),
                value: _enabled,
                activeThumbColor: AppColors.primaryOrange,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _enabled = val),
              ),
            ),
            const SizedBox(height: 28),

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

            // Save CTA
            AppButton(
              text: widget.isEditing ? 'Lưu thay đổi' : 'Hoàn tất',
              isLoading: _saving,
              onPressed: _validateAndSave,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.heading2),
        const SizedBox(height: 2),
        Text(subtitle, style: AppTextStyles.caption),
      ],
    );
  }
}
