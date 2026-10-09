import 'package:material_ui/material_ui.dart';

import '../../widgets/hourly_qr_card.dart';

import '../../core/formatters.dart';

import '../../services/workflow_service.dart';

import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';
import '../../widgets/workflow_button.dart';
import 'activity_screen.dart';
import 'catalogue_admin_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _version = 0;
  int _pages = 1;
  void _refresh() => setState(() => _version++);
  Future<Map<String, dynamic>> _load() async {
    final orders = <dynamic>[];
    final redemptions = <dynamic>[];
    bool more = false;
    for (var i = 0; i < _pages; i++) {
      final data = await WorkflowService().admin(offset: i * 20);
      orders.addAll(data['orders'] as List);
      redemptions.addAll(data['redemptions'] as List);
      more =
          (data['orders'] as List).length == 20 ||
          (data['redemptions'] as List).length == 20;
      if (!more) break;
    }
    return {'orders': orders, 'redemptions': redemptions, 'has_more': more};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản trị phòng tập')),
    body: DataView<Map<String, dynamic>>(
      key: ValueKey(_version),
      load: _load,
      builder: (context, data) => [
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CatalogueAdminScreen()),
          ),
          icon: const Icon(Icons.edit_note),
          label: const Text('Quản lý phần quà, gói tập & PT'),
        ),
        const SizedBox(height: 24),
        const SectionTitle('QR tại quầy'),
        const Text(
          'QR được lưu tại phòng tập và tự đổi vào đầu mỗi giờ. Hội viên được nhận điểm một lần cho mỗi QR.',
        ),
        const SizedBox(height: 20),
        const HourlyQrCard(),
        const SizedBox(height: 24),
        const SectionTitle('Đơn gói tập chờ duyệt'),
        if ((data['orders'] as List).isEmpty)
          const AppCard(child: Text('Không có đơn chờ duyệt.')),
        ...(data['orders'] as List<dynamic>).map(
          (o) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${o['member_name']} · ${o['membership_name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${formatPrice(o['price_vnd_at_order'] as int)} · ${o['duration_days_at_order']} ngày',
                  ),
                  Text(activityDate(o['created_at'])),
                  const SizedBox(height: 12),
                  WorkflowButton(
                    text: 'Duyệt đơn',
                    confirmation: 'Xác nhận đã nhận thanh toán và kích hoạt gói tập cho hội viên?',
                    action: () => WorkflowService().send(
                      '/admin/membership-orders/${o['id']}/review',
                      {'status': 'APPROVED'},
                    ),
                    onSuccess: _refresh,
                  ),
                  const SizedBox(height: 8),
                  WorkflowButton(
                    text: 'Từ chối đơn',
                    confirmation: 'Từ chối đơn đăng ký này?',
                    action: () => WorkflowService().send(
                      '/admin/membership-orders/${o['id']}/review',
                      {'status': 'REJECTED'},
                    ),
                    onSuccess: _refresh,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Quà chờ giao'),
        if ((data['redemptions'] as List).isEmpty)
          const AppCard(child: Text('Không có phần quà chờ giao.')),
        ...(data['redemptions'] as List<dynamic>).map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${r['member_name']} · ${r['reward_name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText('Mã nhận quà: ${r['id']}'),
                  Text('${r['points_spent']} GP'),
                  const SizedBox(height: 12),
                  WorkflowButton(
                    text: 'Xác nhận đã giao quà',
                    confirmation:
                        'Đã giao phần quà cho đúng hội viên và mã nhận quà?',
                    action: () => WorkflowService().send(
                      '/admin/redemptions/${r['id']}/fulfill',
                      {},
                    ),
                    onSuccess: _refresh,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (data['has_more'] == true)
          TextButton(
            onPressed: () {
              _pages++;
              _refresh();
            },
            child: const Text('Xem thêm đơn và quà'),
          ),
      ],
    ),
  );
}
