class Membership {
  final String id, name, description;
  final int priceVnd, durationDays, pointsPerCheckin;
  const Membership({
    required this.id,
    required this.name,
    required this.description,
    required this.priceVnd,
    required this.durationDays,
    required this.pointsPerCheckin,
  });
  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    priceVnd: json['price_vnd'] as int,
    durationDays: json['duration_days'] as int,
    pointsPerCheckin: json['points_per_checkin'] as int,
  );
}
