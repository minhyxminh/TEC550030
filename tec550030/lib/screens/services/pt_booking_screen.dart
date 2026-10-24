import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/trainer.dart';
import '../../services/workflow_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/data_view.dart';
import '../../widgets/decor.dart';
import '../../widgets/workflow_button.dart';
import 'services_screen.dart';

const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

DateTime _vn(DateTime t) => t.toUtc().add(const Duration(hours: 7));

class PtBookingScreen extends StatefulWidget {
  final String trainerId;
  final String trainerName;
  final String trainerImageUrl;
  const PtBookingScreen({
    super.key,
    required this.trainerId,
    required this.trainerName,
    this.trainerImageUrl = '',
  });
  @override
  State<PtBookingScreen> createState() => _PtBookingScreenState();
}

class _PtBookingScreenState extends State<PtBookingScreen> {
  // Slots are returned as UTC; labels always use the gym's Vietnam timezone.
  DateTime _day = _vn(DateTime.now());
  int _generation = 0;
  String? _slot;

  DateTime get _today {
    final now = _vn(DateTime.now());
    return DateTime(now.year, now.month, now.day);
  }

  void _select(DateTime day) => setState(() {
    _day = day;
    _slot = null;
    _generation++;
  });

  Future<void> _pick() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 30)),
    );
    if (day != null && mounted) _select(day);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
    child: Row(
      children: [
        const BackSquare(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Đặt lịch', style: AppTextStyles.heading1),
              Row(
                children: [
                  TrainerAvatar(
                    trainer: Trainer(
                      id: widget.trainerId,
                      name: widget.trainerName,
                      specialty: '',
                      description: '',
                      imageUrl: widget.trainerImageUrl,
                      experienceYears: 0,
                    ),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.trainerName,
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Tooltip(
          message: 'Giờ Việt Nam',
          child: Icon(Icons.schedule_rounded, color: AppColors.ink, size: 26),
        ),
      ],
    ),
  );

  Widget _days() => AppCard(
    padding: const EdgeInsets.fromLTRB(16, 16, 0, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tháng ${_day.month}, ${_day.year}',
                  style: AppTextStyles.title.copyWith(fontSize: 16),
                ),
              ),
              Material(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pick,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Chọn ngày khác',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(right: 16, bottom: 6),
            itemCount: 31,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final day = _today.add(Duration(days: i));
              final selected = _sameDay(day, _day);
              return GestureDetector(
                onTap: () => _select(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 50,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryOrange : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryOrange
                          : AppColors.sand,
                      width: 1.5,
                    ),
                    boxShadow: selected ? AppShadows.block : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekdays[day.weekday - 1],
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: AppTextStyles.heading2.copyWith(fontSize: 20),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.public_rounded,
              size: 15,
              color: AppColors.secondaryText,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Giờ Việt Nam · mỗi buổi 60 phút',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _period(
    String letter,
    String title,
    String range,
    Color tint,
    Color background,
    List<Widget> chips,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                letter,
                style: AppTextStyles.title.copyWith(fontSize: 12, color: tint),
              ),
            ),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.title),
            const SizedBox(width: 6),
            Text(range, style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 10, children: chips),
      ],
    ),
  );

  Widget _chip(Map row, double width) {
    final time = _vn(DateTime.parse(row['slot']));
    final value = row['slot'] as String;
    final available = row['available'] == true;
    final selected = _slot == value;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: selected ? AppShadows.orangeBlock : null,
      ),
      child: ChoiceChip(
        showCheckmark: false,
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        selectedColor: AppColors.ink,
        disabledColor: AppColors.field,
        side: BorderSide(
          color: selected ? AppColors.ink : AppColors.sand,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        label: SizedBox(
          width: width,
          height: 44,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${DateFormat('HH:mm').format(time)}${available ? '' : ' · Đã đặt'}',
                style: AppTextStyles.title.copyWith(
                  fontSize: 15,
                  color: selected
                      ? Colors.white
                      : available
                      ? AppColors.ink
                      : AppColors.secondaryText,
                ),
              ),
            ),
          ),
        ),
        selected: selected,
        onSelected: available ? (_) => setState(() => _slot = value) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slot = _slot == null ? null : _vn(DateTime.parse(_slot!));
    return Scaffold(
      body: PageBackdrop(
        topBlob: AppColors.peach,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _days(),
              ),
              Expanded(
                child: DataView<List<dynamic>>(
                  key: ValueKey(_generation),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  load: () => WorkflowService().slots(
                    widget.trainerId,
                    DateFormat('yyyy-MM-dd').format(_day),
                  ),
                  builder: (context, slots) {
                    final rows = slots.cast<Map>();
                    int hour(Map r) => _vn(DateTime.parse(r['slot'])).hour;
                    return [
                      if (rows.isEmpty)
                        const AppCard(
                          child: Text(
                            'Không còn khung giờ trong ngày này. Hãy chọn ngày khác.',
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, c) {
                          final width = (c.maxWidth - 3 * 8) / 4 - 3;
                          List<Widget> chips(bool Function(int) inPeriod) => [
                            for (final r in rows)
                              if (inPeriod(hour(r))) _chip(r, width),
                          ];
                          final morning = chips((h) => h < 12);
                          final afternoon = chips((h) => h >= 12 && h < 18);
                          final evening = chips((h) => h >= 18);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (morning.isNotEmpty)
                                _period(
                                  'S',
                                  'Buổi sáng',
                                  '06:00 – 11:00',
                                  const Color(0xFFB7791F),
                                  AppColors.butter,
                                  morning,
                                ),
                              if (afternoon.isNotEmpty)
                                _period(
                                  'C',
                                  'Buổi chiều',
                                  '12:00 – 17:00',
                                  AppColors.deepOrange,
                                  AppColors.peach,
                                  afternoon,
                                ),
                              if (evening.isNotEmpty)
                                _period(
                                  'T',
                                  'Buổi tối',
                                  '18:00 – 21:00',
                                  AppColors.purple,
                                  AppColors.lavender,
                                  evening,
                                ),
                            ],
                          );
                        },
                      ),
                    ];
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: slot == null
          ? null
          : BottomActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lịch đã chọn', style: AppTextStyles.caption),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_weekdays[slot.weekday - 1]}, ${DateFormat('dd/MM').format(slot)} · '
                            '${DateFormat('HH:mm').format(slot)} – '
                            '${DateFormat('HH:mm').format(slot.add(const Duration(hours: 1)))}',
                            style: AppTextStyles.title.copyWith(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 156,
                    child: RequestButton(
                      key: ValueKey(_slot),
                      path: '/pt-bookings',
                      body: {'trainer_id': widget.trainerId, 'slot': _slot},
                      text: 'Đặt buổi tập',
                      confirmation:
                          'Đặt 60 phút với ${widget.trainerName} lúc ${DateFormat('dd/MM/yyyy HH:mm').format(slot)} (giờ Việt Nam)?',
                      success: 'Đã đặt lịch. Xem trong Hoạt động của tôi.',
                      onSuccess: () => setState(() => _slot = null),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
