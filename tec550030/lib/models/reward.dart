import 'catalogue_media.dart';

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
    final id = json['id'] as String? ?? '';
    final copy = rewardCopy(id);
    return Reward(
      id: id,
      name: copy?.$1 ?? cleanName(json['name'] as String? ?? ''),
      description: copy?.$2 ?? json['description'] ?? '',
      points: json['points'] ?? 0,
      stock: json['stock'] ?? 0,
      imageUrl: rewardImage(id, json['image_url'] as String? ?? ''),
    );
  }
}
