class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? activeMembershipId;
  final DateTime? membershipExpiresAt;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.role = 'MEMBER',
    this.avatarUrl,
    this.activeMembershipId,
    this.membershipExpiresAt,
    this.createdAt,
  });

  bool get hasActiveMembership =>
      activeMembershipId != null &&
      membershipExpiresAt != null &&
      membershipExpiresAt!.isAfter(DateTime.now());

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'MEMBER',
      avatarUrl: json['avatar_url'] as String?,
      activeMembershipId: json['active_membership_id'],
      membershipExpiresAt: DateTime.tryParse(
        json['membership_expires_at'] ?? '',
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? ''),
    );
  }
}
