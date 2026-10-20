class BuddyMatch {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherAvatarUrl;
  final String? otherAvatarPath;
  final String? conversationId;
  final DateTime? createdAt;

  const BuddyMatch({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherAvatarUrl,
    this.otherAvatarPath,
    this.conversationId,
    this.createdAt,
  });

  factory BuddyMatch.fromJson(Map<String, dynamic> json) {
    return BuddyMatch(
      id: json['id'] as String? ?? '',
      otherUserId: json['other_user_id'] as String? ?? '',
      otherUserName: json['other_user_name'] as String? ?? '',
      otherAvatarUrl: json['other_avatar_url'] as String?,
      otherAvatarPath: json['other_avatar_path'] as String?,
      conversationId: json['conversation_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'other_user_id': otherUserId,
    'other_user_name': otherUserName,
    if (otherAvatarUrl != null) 'other_avatar_url': otherAvatarUrl,
    if (otherAvatarPath != null) 'other_avatar_path': otherAvatarPath,
    if (conversationId != null) 'conversation_id': conversationId,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}

