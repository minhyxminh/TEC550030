import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api/api_client.dart';
import '../core/formatters.dart';
import '../services/workflow_service.dart';
import 'app_card.dart';
import 'workflow_button.dart';

class HourlyQrCard extends StatefulWidget {
  const HourlyQrCard({super.key});
  @override
  State<HourlyQrCard> createState() => _HourlyQrCardState();
}

class _HourlyQrCardState extends State<HourlyQrCard>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _qr;
  String? _error;
  bool _loading = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (_loading || !mounted) return;
    _loading = true;
    _timer?.cancel();
    try {
      final data =
          await ApiClient.getJson('/admin/qr-current') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _qr = data;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _loading = false;
      if (mounted) {
        final expiry = DateTime.tryParse(_qr?['expires_at'] ?? '');
        final until = expiry?.difference(DateTime.now());
        // Refresh exactly at expiry, or every 30 seconds to notice revocation.
        final delay =
            until != null &&
                until > Duration.zero &&
                until < const Duration(seconds: 30)
            ? until + const Duration(milliseconds: 100)
            : const Duration(seconds: 30);
        _timer = Timer(delay, _load);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = _qr;
    final expiry = DateTime.tryParse(qr?['expires_at'] ?? '');
    final active =
        qr != null &&
        qr['revoked_at'] == null &&
        expiry != null &&
        expiry.isAfter(DateTime.now());
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (qr == null && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _load, child: const Text('Tải lại QR')),
          ],
          if (active) ...[
            Center(
              child: QrImageView(
                data: qr['token'],
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              qr['token'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'QR phòng ${qr['gym_id']} · Đổi mã lúc ${formatDateTime(expiry)}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            WorkflowButton(
              text: 'Thu hồi QR',
              confirmation: 'Mã hiện tại sẽ ngừng sử dụng. Mã mới tự tạo vào đầu giờ tiếp theo.',
              action: () => WorkflowService().send(
                '/admin/qr-tokens/${qr['id']}/revoke',
                {},
              ),
              onSuccess: _load,
            ),
          ] else if (qr != null) ...[
            const Icon(Icons.qr_code_2, size: 72),
            const SizedBox(height: 12),
            Text(
              qr['revoked_at'] != null
                  ? 'Mã đã thu hồi. Mã mới sẽ tự tạo vào đầu giờ tiếp theo.'
                  : 'Đang cập nhật mã cho giờ mới…',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
