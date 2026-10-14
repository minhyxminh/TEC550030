class GymBranch {
  final String id;
  final String name;
  final String address;
  final String district;
  final double latitude;
  final double longitude;
  final String openingHours;
  final double? distanceKm;

  const GymBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.openingHours,
    this.distanceKm,
  });

  factory GymBranch.fromJson(Map<String, dynamic> json) => GymBranch(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    district: json['district'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    openingHours: json['opening_hours'] as String? ?? '',
  );

  GymBranch withDistance(double value) => GymBranch(
    id: id,
    name: name,
    address: address,
    district: district,
    latitude: latitude,
    longitude: longitude,
    openingHours: openingHours,
    distanceKm: value,
  );
}