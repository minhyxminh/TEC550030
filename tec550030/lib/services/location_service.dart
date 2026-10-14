import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final bool denied;
  final bool permanentlyDenied;
  final bool serviceDisabled;

  const LocationResult({
    this.latitude,
    this.longitude,
    this.denied = false,
    this.permanentlyDenied = false,
    this.serviceDisabled = false,
  });

  bool get hasPosition => latitude != null && longitude != null;
}

class LocationService {
  final Future<LocationResult> Function()? locationProvider;
  const LocationService({this.locationProvider});

  Future<LocationResult> getCurrentLocation() async {
    final override = locationProvider;
    if (override != null) return override();

    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult(serviceDisabled: true);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult(denied: true);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(permanentlyDenied: true);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on LocationServiceDisabledException {
      return const LocationResult(serviceDisabled: true);
    } on PermissionDeniedException {
      return const LocationResult(denied: true);
    }
  }

  double distanceKm(double latitude1, double longitude1, double latitude2,
      double longitude2) =>
      Geolocator.distanceBetween(latitude1, longitude1, latitude2, longitude2) /
      1000;

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}