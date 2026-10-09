import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/workflow_service.dart';
import '../../widgets/data_view.dart';
import '../../widgets/app_card.dart';
import '../../widgets/workflow_button.dart';

class PtBookingScreen extends StatefulWidget {
  final String trainerId;
  final String trainerName;
  const PtBookingScreen({
    super.key,
    required this.trainerId,
    required this.trainerName,
  });
  @override
  State<PtBookingScreen> createState() => _PtBookingScreenState();
}

class _PtBookingScreenState extends State<PtBookingScreen> {
  // Slots are returned as UTC; labels always use the gym's Vietnam timezone.
  DateTime _day = DateTime.now().toUtc().add(const Duration(hours: 7));
  int _generation = 0;
  String? _slot;
  Future<void> _pick() async {
    final today = DateTime.now().toUtc().add(const Duration(hours: 7));
    final day = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day + 30),
    );
    if (day != null && mounted) {
      setState(() {
        _day = day;
        _slot = null;
        _generation++;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Đặt lịch · ${widget.trainerName}')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.calendar_month),
            label: Text(
              'Ngày ${DateFormat('dd/MM/yyyy').format(_day)} · giờ Việt Nam',
            ),
          ),
        ),
        Expanded(
          child: DataView<List<dynamic>>(
            key: ValueKey(_generation),
            load: () => WorkflowService().slots(
              widget.trainerId,
              DateFormat('yyyy-MM-dd').format(_day),
            ),
            builder: (context, slots) => [
              if (slots.isEmpty)
                const AppCard(
                  child: Text(
                    'Không còn khung giờ trong ngày này. Hãy chọn ngày khác.',
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.map((row) {
                  final time = DateTime.parse(row['slot'])
                      .toUtc()
                      .add(const Duration(hours: 7));
                  final value = row['slot'] as String;
                  return ChoiceChip(
                    label: Text(
                      '${DateFormat('HH:mm').format(time)}${row['available'] == true ? '' : ' · Đã đặt'}',
                    ),
                    selected: _slot == value,
                    onSelected: row['available'] == true
                        ? (_) => setState(() => _slot = value)
                        : null,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              if (_slot != null)
                RequestButton(
                  key: ValueKey(_slot),
                  path: '/pt-bookings',
                  body: {'trainer_id': widget.trainerId, 'slot': _slot},
                  text: 'Đặt buổi tập',
                  confirmation:
                      'Đặt 60 phút với ${widget.trainerName} lúc ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(_slot!).toUtc().add(const Duration(hours: 7)))} (giờ Việt Nam)?',
                  success: 'Đã đặt lịch. Xem trong Hoạt động của tôi.',
                  onSuccess: () => setState(() => _slot = null),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
