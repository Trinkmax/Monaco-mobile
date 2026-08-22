import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

final locationServiceProvider = Provider<LocationService>(
  (_) => LocationService(),
);

/// Posición actual del usuario. `null` si no hay permiso, servicio o señal.
///
/// Es best-effort y nunca falla: el que lo consume lo trata como
/// `AsyncValue` y dibuja sin distancias mientras carga o si da `null`.
final userLocationProvider = FutureProvider<Position?>((ref) async {
  final service = ref.read(locationServiceProvider);
  return service.getCurrentPosition();
});
