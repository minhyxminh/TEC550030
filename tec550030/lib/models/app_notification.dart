enum NotificationKind {
  message,
  match,
  membership,
  reward,
  booking,
  admin,
  checkin,
}

/// One entry in the in-app notification centre.
class AppNotification {
  final String id;
  final NotificationKind kind;
  final String title, body;
  final DateTime createdAt;
  final bool read;

  /// Conversation to open for message notifications.
  final String? conversationId;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.conversationId,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    read: read ?? this.read,
    conversationId: conversationId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'body': body,
    'created_at': createdAt.toIso8601String(),
    'read': read,
    if (conversationId != null) 'conversation_id': conversationId,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        kind: NotificationKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => NotificationKind.admin,
        ),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        read: json['read'] as bool? ?? false,
        conversationId: json['conversation_id'] as String?,
      );
}
