class Reward {
  final String id;
  final String name;
  final String description;
  final int points;
  final int stock;
  final String imageUrl;

  Reward({
    required this.id,
    required this.name,
    required this.description,
    required this.points,
    required this.stock,
    required this.imageUrl,
  });

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      points: json['points'] ?? 0,
      stock: json['stock'] ?? 0,
      imageUrl: json['image_url'] ?? '',
    );
  }
}
