import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tec550030/core/api/api_client.dart';

http.Client mockApi(FutureOr<http.Response> Function(http.Request) handler) =>
    MockClient((request) async {
      final prefix = Uri.parse(ApiClient.baseUrl).path;
      final path = request.url.path.startsWith(prefix)
          ? request.url.path.substring(prefix.length)
          : request.url.path;
      final normalized =
          http.Request(request.method, request.url.replace(path: path))
            ..headers.addAll(request.headers)
            ..bodyBytes = request.bodyBytes;
      return handler(normalized);
    });

const membershipId = '10000000-0000-4000-8000-000000000001';
const rewardId = '20000000-0000-4000-8000-000000000001';
const trainerId = '30000000-0000-4000-8000-000000000001';
const profile = {
  'id': 'a0000000-0000-4000-8000-000000000001',
  'name': 'Lê Minh Anh',
  'email': 'anh@example.com',
  'active_membership_id': membershipId,
  'membership_expires_at': '2099-11-08T12:00:00Z',
  'created_at': '2026-10-08T12:00:00Z',
};
const membership = {
  'id': membershipId,
  'name': 'Basic',
  'description': 'Gói tập cơ bản dành cho hội viên.',
  'price_vnd': 300000,
  'duration_days': 30,
  'points_per_checkin': 10,
};
const trainer = {
  'id': trainerId,
  'name': 'PT Minh',
  'specialty': 'Strength training',
  'description': 'Đồng hành trong các buổi tập sức mạnh.',
  'experience_years': 3,
  'image_url': '',
};
const rewards = [
  {
    'id': rewardId,
    'name': 'Nước khoáng',
    'description': 'Một chai nước sau buổi tập.',
    'points': 20,
    'stock': 50,
    'image_url': '',
  },
  {
    'id': '20000000-0000-4000-8000-000000000002',
    'name': 'Thanh protein',
    'description': 'Bữa phụ sau buổi tập.',
    'points': 50,
    'stock': 0,
    'image_url': '',
  },
  {
    'id': '20000000-0000-4000-8000-000000000003',
    'name': 'Khăn tập',
    'description': 'Khăn tập GymFlow.',
    'points': 100,
    'stock': 20,
    'image_url': '',
  },
  {
    'id': '20000000-0000-4000-8000-000000000004',
    'name': 'Voucher đồ uống',
    'description': 'Voucher đồ uống.',
    'points': 150,
    'stock': 10,
    'image_url': '',
  },
];
const history = [
  {
    'id': 'earn-1',
    'points': 100,
    'reason': 'Check-in GymFlow',
    'type': 'EARN',
    'created_at': '2026-10-08T10:00:00Z',
  },
  {
    'id': 'debit-1',
    'points': -20,
    'reason': 'Đổi nước khoáng',
    'type': 'REDEEM',
    'created_at': '2026-10-08T11:00:00Z',
  },
];
http.Response jsonResponse(Object? data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response fixtureResponse(http.Request request) {
  switch (request.url.path) {
    case '/gym/session':
      return http.Response(
        'null',
        200,
        headers: {'content-type': 'application/json'},
      );
    case '/gym/1/occupancy':
      return jsonResponse({'count': 3});
    case '/gym/1/hourly':
      return jsonResponse([
        {'hour': 6, 'count': 2},
        {'hour': 7, 'count': 3},
      ]);
    case '/redemptions':
      return jsonResponse({'id': 'redeem-1', 'status': 'PENDING'});
    case '/membership-orders':
      return jsonResponse({'id': 'order-1', 'status': 'PENDING'});
    case '/activity':
      return jsonResponse({
        'sessions': [],
        'redemptions': [],
        'orders': [],
        'bookings': [],
      });
    case '/auth/login':
      return jsonResponse({
        'user': profile,
        'access_token': 'valid-token',
        'refresh_token': 'valid-refresh',
        'expires_in': 3600,
      });
    case '/auth/register':
      return jsonResponse({
        'user': profile,
        'access_token': null,
        'requires_email_confirmation': true,
        'message': 'Kiểm tra email để xác nhận tài khoản trước khi đăng nhập.',
      }, 201);
    case '/me':
      return jsonResponse(profile);
    case '/points/balance':
      return jsonResponse({'balance': 80});
    case '/points/history':
      return jsonResponse(history);
    case '/rewards':
      return jsonResponse(rewards);
    case '/memberships':
      return jsonResponse([membership]);
    case '/trainers':
      return jsonResponse([trainer]);
    default:
      if (request.url.path == '/rewards/$rewardId') {
        return jsonResponse({
          ...rewards.first,
          'description': 'Mô tả mới nhất từ API chi tiết.',
        });
      }
      if (request.url.path == '/memberships/$membershipId') {
        return jsonResponse(membership);
      }
      if (request.url.path == '/trainers/$trainerId') {
        return jsonResponse(trainer);
      }
      return jsonResponse({'message': 'Không tìm thấy.'}, 404);
  }
}
