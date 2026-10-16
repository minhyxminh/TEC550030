import '../core/api/api_client.dart';

class ChatService {
  Future<Map<String, dynamic>> open() => ApiClient.postJson('/chat/open', {});
  Future<List<Map<String, dynamic>>> inbox({int offset = 0}) async => _rows(
    await ApiClient.getJson('/chat/inbox?limit=50&offset=$offset'),
    'conversations',
  );
  Future<List<Map<String, dynamic>>> messages(
    String id, {
    int? before,
  }) async => _rows(
    await ApiClient.getJson(
      '/chat/$id/messages?limit=50${before == null ? '' : '&before=$before'}',
    ),
    'messages',
  );
  Future<Map<String, dynamic>> send(
    String id,
    String content,
    String clientId,
  ) => ApiClient.postJson('/chat/$id/messages', {
    'content': content,
    'client_id': clientId,
  });
  Future<void> read(String id, int through) async {
    await ApiClient.postJson('/chat/$id/read', {'through': through});
  }

  List<Map<String, dynamic>> _rows(dynamic data, String key) =>
      (data[key] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
}
