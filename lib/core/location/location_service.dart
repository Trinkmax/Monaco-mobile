import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Ubicación **best-effort**: se usa sólo para ordenar sucursales por cercanía
/// y mostrar "a 1,2 km". Nunca bloquea una pantalla y nunca tira: si no hay
/// permiso, servicio o señal, devuelve `null` y la app sigue sin distancias.
class LocationService {
  /// Pide permiso si hace falta y devuelve la posición actual (o `null`).
  ///
  /// Primero intenta la última posición conocida (instantánea) y después la
  /// actual con un tope de tiempo corto, para que la lista de sucursales no
  /// espere al GPS.
  Future<Position?> getCurrentPosition({
    Duration timeLimit = const Duration(seconds: 8),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      Position? last;
      try {
        last = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: timeLimit,
          ),
        );
      } catch (e) {
        debugPrint('[location] getCurrentPosition: $e (uso última conocida)');
        return last;
      }
    } catch (e) {
      debugPrint('[location] sin ubicación: $e');
      return null;
    }
  }

  /// Distancia en kilómetros entre dos coordenadas.
  double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  /// "850 m" / "1,2 km" / "14 km".
  static String formatDistance(double km) {
    if (km < 1) {
      final m = (km * 1000 / 10).round() * 10;
      return '$m m';
    }
    if (km < 10) return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    return '${km.round()} km';
  }
}
