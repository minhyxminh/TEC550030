class PointTransaction {
  final String id;
  final int points;
  final String reason;
  final DateTime createdAt;

  PointTransaction({
    required this.id,
    required this.points,
    required this.reason,
    required this.createdAt,
  });

  factory PointTransaction.fromJson(Map<String, dynamic> json) {
    return PointTransaction(
      id: json['id'] ?? '',
      points: json['points'] ?? 0,
      reason: json['reason'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
