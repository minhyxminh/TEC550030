import '../core/api/api_client.dart';

class PaymentService {
  const PaymentService();

  Future<Map<String, dynamic>> createMembershipPayment(
    String membershipId,
    String idempotencyKey,
  ) async {
    return ApiClient.postJson('/payments/membership-orders', {
      'membership_id': membershipId,
      'idempotency_key': idempotencyKey,
    });
  }

  Future<Map<String, dynamic>> getMembershipPayment(String orderId) async {
    return Map<String, dynamic>.from(
      await ApiClient.getJson('/payments/membership-orders/$orderId') as Map,
    );
  }
}
