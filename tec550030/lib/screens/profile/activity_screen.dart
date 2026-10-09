import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../services/workflow_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/workflow_button.dart';

String activityStatus(dynamic value) => switch (value) {
  'PENDING' => 'Chờ xử lý',
  'APPROVED' => 'Đã duyệt',
  'REJECTED' => 'Từ chối',
  'FULFILLED' => 'Đã nhận quà',
  'CONFIRMED' => 'Đã đặt',
  'CANCELLED' => 'Đã hủy',
  _ => '$value',
};
String activityDate(dynamic value) {
  final date = DateTime.tryParse('$value');
  return date == null ? '' : formatDateTime(date);
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _items = <String, List<dynamic>>{
    'sessions': [],
    'redemptions': [],
    'orders': [],
    'bookings': [],
  };
  int _offset = 0;
  bool _busy = false;
  bool _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await WorkflowService().history(offset: reset ? 0 : _offset);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _offset = 0;
          for (final rows in _items.values) {
            rows.clear();
          }
        }
        _more = false;
        for (final key in _items.keys) {
          final rows = data[key] as List<dynamic>;
          _more = _more || rows.length == 20;
          final ids = _items[key]!.map((e) => e['id']).toSet();
          _items[key]!.addAll(rows.where((e) => !ids.contains(e['id'])));
        }
        _offset += 20;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Hoạt động của tôi'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Buổi tập'),
            Tab(text: 'Đổi quà'),
            Tab(text: 'Đơn gói tập'),
            Tab(text: 'Lịch PT'),
          ],
        ),
      ),
      body: TabBarView(
        children: _items.keys
            .map(
              (key) => RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (_error != null) ...[
                      Text(_error!),
                      TextButton(
                        onPressed: () => _load(reset: true),
                        child: const Text('Thử lại'),
                      ),
                    ],
                    if (_items[key]!.isEmpty && !_busy)
                      const AppCard(child: Text('Chưa có hoạt động.')),
                    ..._items[key]!.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${row['reward_name'] ?? row['membership_name'] ?? row['trainer_name'] ?? 'Phòng tập ${row['gym_id']}'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              StatusPill(
                                key == 'sessions'
                                    ? (row['check_out_at'] == null
                                          ? 'Đang tập'
                                          : 'Đã kết thúc')
                                    : activityStatus(row['status']),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                activityDate(
                                  row['slot'] ??
                                      row['check_in_at'] ??
                                      row['created_at'],
                                ),
                              ),
                              if (key == 'sessions' &&
                                  row['check_out_at'] != null)
                                Text(
                                  'Ra về: ${activityDate(row['check_out_at'])}',
                                ),
                              if (key == 'redemptions')
                                Text(
                                  '${formatNumber(row['points_spent'] as int)} GP · Mã nhận quà: ${row['id']}',
                                ),
                              if (key == 'orders') ...[
                                Text(
                                  '${formatPrice(row['price_vnd_at_order'] as int)} · ${row['duration_days_at_order']} ngày',
                                ),
                                if (row['ends_at'] != null)
                                  Text(
                                    'Hiệu lực: ${activityDate(row['starts_at'])} – ${activityDate(row['ends_at'])}',
                                  ),
                                if (row['status'] == 'PENDING')
                                  const Text(
                                    'Liên hệ quầy để thanh toán. Gói chỉ có hiệu lực khi quản trị viên duyệt.',
                                  ),
                              ],
                              if (key == 'bookings' &&
                                  row['status'] == 'CONFIRMED' &&
                                  DateTime.parse(row['slot'])
                                      .isAfter(DateTime.now())) ...[
                                const SizedBox(height: 12),
                                WorkflowButton(
                                  text: 'Hủy lịch',
                                  confirmation: 'Hủy buổi tập này?',
                                  action: () => WorkflowService().send(
                                    '/pt-bookings/${row['id']}/cancel',
                                    {},
                                  ),
                                  onSuccess: () => _load(reset: true),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_busy) const Center(child: CircularProgressIndicator()),
                    if (_more && !_busy)
                      TextButton(
                        onPressed: _load,
                        child: const Text('Tải thêm hoạt động'),
                      ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    ),
  );
}
