class Membership {
  final String id, name, description;
  final int priceVnd, durationDays, pointsPerCheckin, pointsOnActivation;
  const Membership({
    required this.id,
    required this.name,
    required this.description,
    required this.priceVnd,
    required this.durationDays,
    required this.pointsPerCheckin,
    required this.pointsOnActivation,
  });
  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    priceVnd: json['price_vnd'] as int,
    durationDays: json['duration_days'] as int,
    pointsPerCheckin: json['points_per_checkin'] as int,
    pointsOnActivation:
        json['points_on_activation'] as int? ??
        switch ((json['name'] as String).toLowerCase()) {
          'basic' => 100,
          'premium' => 200,
          'vip' => 300,
          _ => 50,
        },
  );
}
