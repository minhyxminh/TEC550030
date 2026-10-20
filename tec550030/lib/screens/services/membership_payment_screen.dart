import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/membership.dart';
import '../../services/payment_service.dart';
import '../../services/workflow_service.dart';
import '../../widgets/app_card.dart';

class MembershipPaymentScreen extends StatefulWidget {
  final Membership membership;
  final PaymentService paymentService;

  const MembershipPaymentScreen({
    super.key,
    required this.membership,
    this.paymentService = const PaymentService(),
  });

  @override
  State<MembershipPaymentScreen> createState() =>
      _MembershipPaymentScreenState();
}

class _MembershipPaymentScreenState extends State<MembershipPaymentScreen> {
  late final String _requestKey;
  Map<String, dynamic>? _order;
  Timer? _pollTimer;
  bool _loading = true;
  bool _checking = false;
  bool _revisionRaised = false;
  String? _error;

  bool get _paid =>
      _order?['payment_status'] == 'PAID' || _order?['status'] == 'APPROVED';

  @override
  void initState() {
    super.initState();
    _requestKey = WorkflowService.requestKey();
    _createOrder();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createOrder() async {
    try {
      final order = await widget.paymentService.createMembershipPayment(
        widget.membership.id,
        _requestKey,
      );
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
        _error = null;
      });
      _afterOrderUpdate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _afterOrderUpdate() {
    if (_paid) {
      _pollTimer?.cancel();
      if (!_revisionRaised) {
        _revisionRaised = true;
        WorkflowService.revision.value++;
      }
      return;
    }
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshStatus(silent: true),
    );
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    final orderId = _order?['id'] as String?;
    if (orderId == null || orderId.isEmpty || _checking || _paid) return;

    if (mounted && !silent) setState(() => _checking = true);
    try {
      final updated = await widget.paymentService.getMembershipPayment(orderId);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _error = null;
        _checking = false;
      });
      _afterOrderUpdate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = e.toString();
        _checking = false;
      });
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép $label.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán gói tập')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _order == null
                ? _buildLoadError()
                : _paid
                    ? _buildSuccess()
                    : _buildPayment(),
      ),
    );
  }

  Widget _buildLoadError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 42,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Không thể tạo đơn thanh toán',
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? '',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _createOrder,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildPayment() {
    final order = _order!;
    final amount = (order['payment_amount_vnd'] as num?)?.toInt() ?? 0;
    final code = order['payment_code'] as String? ?? '';
    final qrUrl = order['qr_url'] as String?;
    final paymentReady = order['payment_ready'] == true;
    final bank = order['bank'] is Map
        ? Map<String, dynamic>.from(order['bank'] as Map)
        : null;

    return RefreshIndicator(
      onRefresh: () => _refreshStatus(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.membership.name, style: AppTextStyles.heading1),
                const SizedBox(height: 8),
                Text(
                  'Giá gói: ${formatPrice(widget.membership.priceVnd)}',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 6),
                Text(
                  'Thanh toán demo thực tế: ${formatPrice(amount)}',
                  style: AppTextStyles.heading2.copyWith(
                    color: AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sau khi ngân hàng xác nhận tiền vào, gói được kích hoạt tự động và bạn nhận +${widget.membership.pointsOnActivation} GP.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!paymentReady)
            AppCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.settings_outlined,
                    size: 38,
                    color: AppColors.primaryOrange,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Chưa cấu hình tài khoản nhận tiền',
                    style: AppTextStyles.heading2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Backend đã tạo đơn nhưng cần cấu hình ngân hàng và SePay trước khi có thể quét QR thật.',
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            AppCard(
              child: Column(
                children: [
                  const Text(
                    'Quét QR để chuyển khoản',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: 14),
                  if (qrUrl != null)
                    Center(
                      child: SizedBox(
                        width: 280,
                        height: 320,
                        child: Image.network(
                          qrUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text(
                              'Không tải được QR. Bạn vẫn có thể chuyển khoản theo thông tin bên dưới.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Text(
                    'Chỉ xác nhận chuyển tiền khi thông tin trong app ngân hàng đúng.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin chuyển khoản',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: 14),
                  _PaymentRow(
                    label: 'Ngân hàng',
                    value: bank?['bank_id'] as String? ?? '',
                  ),
                  _PaymentRow(
                    label: 'Chủ tài khoản',
                    value: bank?['account_name'] as String? ?? '',
                  ),
                  _PaymentRow(
                    label: 'Số tài khoản',
                    value: bank?['account_no'] as String? ?? '',
                    onCopy: () => _copy(
                      bank?['account_no'] as String? ?? '',
                      'số tài khoản',
                    ),
                  ),
                  _PaymentRow(
                    label: 'Số tiền',
                    value: formatPrice(amount),
                  ),
                  _PaymentRow(
                    label: 'Nội dung',
                    value: code,
                    onCopy: () => _copy(code, 'nội dung chuyển khoản'),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: paymentReady && !_checking
                ? () => _refreshStatus()
                : null,
            icon: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(
              _checking ? 'Đang kiểm tra...' : 'Kiểm tra thanh toán',
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Hệ thống cũng tự kiểm tra mỗi 3 giây. Không cần gửi ảnh biên lai.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final order = _order!;
    final startsAt = DateTime.tryParse(order['starts_at'] as String? ?? '');
    final endsAt = DateTime.tryParse(order['ends_at'] as String? ?? '');

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 56),
        AppCard(
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 46,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Thanh toán thành công',
                style: AppTextStyles.heading1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.membership.name} đã được kích hoạt.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '+${widget.membership.pointsOnActivation} GymPoint',
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.success,
                ),
              ),
              if (startsAt != null && endsAt != null) ...[
                const SizedBox(height: 14),
                Text(
                  '${formatDate(startsAt)} → ${formatDate(endsAt)}',
                  style: AppTextStyles.caption,
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Hoàn tất'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _PaymentRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 105,
              child: Text(label, style: AppTextStyles.caption),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onCopy != null)
              IconButton(
                tooltip: 'Sao chép',
                onPressed: value.isEmpty ? null : onCopy,
                icon: const Icon(Icons.copy_rounded, size: 19),
              ),
          ],
        ),
      );
}
