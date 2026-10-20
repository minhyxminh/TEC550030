import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tec550030/core/theme/app_theme.dart';
import 'package:tec550030/models/membership.dart';
import 'package:tec550030/screens/services/membership_payment_screen.dart';
import 'package:tec550030/services/payment_service.dart';

class FakePaymentService extends PaymentService {
  final Map<String, dynamic> created;
  final Map<String, dynamic>? refreshed;

  const FakePaymentService({
    required this.created,
    this.refreshed,
  });

  @override
  Future<Map<String, dynamic>> createMembershipPayment(
    String membershipId,
    String idempotencyKey,
  ) async =>
      Map<String, dynamic>.from(created);

  @override
  Future<Map<String, dynamic>> getMembershipPayment(String orderId) async =>
      Map<String, dynamic>.from(refreshed ?? created);
}

const membership = Membership(
  id: '10000000-0000-4000-8000-000000000001',
  name: 'Basic',
  description: 'Basic plan',
  priceVnd: 300000,
  durationDays: 30,
  pointsPerCheckin: 5,
  pointsOnActivation: 100,
);

Future<void> pumpPayment(
  WidgetTester tester,
  PaymentService service,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: MembershipPaymentScreen(
        membership: membership,
        paymentService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows demo transfer amount while keeping catalogue price',
      (tester) async {
    await pumpPayment(
      tester,
      const FakePaymentService(
        created: {
          'id': 'order-1',
          'payment_amount_vnd': 5000,
          'payment_code': 'GFABCDEF123456',
          'payment_status': 'UNPAID',
          'status': 'PENDING',
          'payment_ready': false,
          'bank': null,
        },
      ),
    );

    expect(find.text('Giá gói: 300.000 ₫'), findsOneWidget);
    expect(find.text('Thanh toán demo thực tế: 5.000 ₫'), findsOneWidget);
    expect(find.text('Chưa cấu hình tài khoản nhận tiền'), findsOneWidget);
  });

  testWidgets('paid order shows automatic activation and GymPoint reward',
      (tester) async {
    await pumpPayment(
      tester,
      const FakePaymentService(
        created: {
          'id': 'order-1',
          'payment_amount_vnd': 5000,
          'payment_code': 'GFABCDEF123456',
          'payment_status': 'PAID',
          'status': 'APPROVED',
          'payment_ready': true,
          'starts_at': '2026-10-20T09:00:00Z',
          'ends_at': '2026-11-19T09:00:00Z',
        },
      ),
    );

    expect(find.text('Thanh toán thành công'), findsOneWidget);
    expect(find.text('Basic đã được kích hoạt.'), findsOneWidget);
    expect(find.text('+100 GymPoint'), findsOneWidget);
    expect(find.text('Hoàn tất'), findsOneWidget);
  });
}
