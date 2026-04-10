import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

final locationServiceProvider = Provider<LocationService>((_) => LocationService());

/// Posición actual del usuario. Null si no hay permiso o servicio desactivado.
final userLocationProvider = FutureProvider<Position?>((ref) async {
  final service = ref.read(locationServiceProvider);
  return service.getCurrentPosition();
});
