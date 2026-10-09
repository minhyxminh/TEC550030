class PointTransaction {
  final String id;
  final int points;
  final String reason;
  final DateTime createdAt;
  final String type;

  PointTransaction({
    required this.id,
    required this.points,
    required this.reason,
    required this.createdAt,
    this.type = '',
  });

  factory PointTransaction.fromJson(Map<String, dynamic> json) {
    return PointTransaction(
      id: json['id'] ?? '',
      points: json['points'] ?? 0,
      reason: json['reason'] ?? '',
      type: json['type'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
