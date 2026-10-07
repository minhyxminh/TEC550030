class Occupancy {
  final int count;

  Occupancy({required this.count});

  factory Occupancy.fromJson(Map<String, dynamic> json) {
    return Occupancy(count: json['count'] ?? 0);
  }
}

class HourlyOccupancy {
  final int hour;
  final int count;

  HourlyOccupancy({required this.hour, required this.count});

  factory HourlyOccupancy.fromJson(Map<String, dynamic> json) {
    return HourlyOccupancy(hour: json['hour'] ?? 0, count: json['count'] ?? 0);
  }
}
