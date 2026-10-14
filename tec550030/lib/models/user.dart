class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? activeMembershipId;
  final String? homeGymId;
  final DateTime? membershipExpiresAt;
  final DateTime? createdAt;
  final bool? membershipActive;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.role = 'MEMBER',
    this.avatarUrl,
    this.activeMembershipId,
    this.homeGymId,
    this.membershipExpiresAt,
    this.createdAt,
    this.membershipActive,
  });

  bool get hasActiveMembership =>
      membershipActive ??
          (activeMembershipId != null &&
              membershipExpiresAt != null &&
              membershipExpiresAt!.isAfter(DateTime.now()));

    bool get canCheckIn => hasActiveMembership && homeGymId != null;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'MEMBER',
      avatarUrl: json['avatar_url'] as String?,
      activeMembershipId: json['active_membership_id'],
      homeGymId: json['home_gym_id'] as String?,
      membershipExpiresAt: DateTime.tryParse(
        json['membership_expires_at'] ?? '',
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? ''),
      membershipActive: json['membership_active'] as bool?,
    );
  }
}
