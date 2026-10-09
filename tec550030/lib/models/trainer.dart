class Trainer {
  final String id, name, specialty, description, imageUrl;
  final int experienceYears;
  const Trainer({
    required this.id,
    required this.name,
    required this.specialty,
    required this.description,
    required this.imageUrl,
    required this.experienceYears,
  });
  factory Trainer.fromJson(Map<String, dynamic> json) => Trainer(
    id: json['id'] as String,
    name: json['name'] as String,
    specialty: json['specialty'] as String? ?? '',
    description: json['description'] as String? ?? '',
    imageUrl: json['image_url'] as String? ?? '',
    experienceYears: json['experience_years'] as int? ?? 0,
  );
}
