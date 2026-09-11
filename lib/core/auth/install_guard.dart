import 'package:flutter/foundation.dart';
// `shared_preferences` es dependencia DIRECTA en `pubspec.yaml` (llegaba
// transitiva por `supabase_flutter`, que la usa de storage por defecto, pero
// acá hay código nuestro que la importa).
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_local_storage.dart';
import 'secure_storage.dart';

/// Un almacén que **se borra con la desinstalación** (NSUserDefaults en iOS,
/// SharedPreferences en Android). Es la única propiedad que importa acá y es
/// exactamente la que el Keychain NO tiene.
abstract class MarcaInstalacion {
  Future<bool> existe();
  Future<void> escribir();
}

/// Implementación real sobre `SharedPreferences`.
class MarcaInstalacionPrefs implements MarcaInstalacion {
  const MarcaInstalacionPrefs();

  @override
  Future<bool> existe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(InstallGuard.marcaKey) ?? false;
  }

  @override
  Future<void> escribir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(InstallGuard.marcaKey, true);
  }
}

/// Qué hizo el guard, para el log y para los tests.
enum ResultadoInstallGuard {
  /// La marca ya estaba: instalación conocida, no se tocó nada.
  instalacionConocida,

  /// Primer arranque limpio: sólo se escribió la marca.
  primerArranque,

  /// No había marca pero la caja fuerte tenía datos de una instalación
  /// anterior: se borró todo y se escribió la marca.
  restosBorrados,

  /// Algo falló leyendo o escribiendo: no se tocó nada (falla abierto).
  omitido,
}

/// **El Keychain de iOS sobrevive a la desinstalación.** La sesión de Supabase,
/// el `device_secret`, el PIN y la biometría se guardan con
/// `kSecClassGenericPassword`, que iOS conserva cuando se borra la app. Sin
/// esto, un teléfono que se vende o se presta después de desinstalar Monaco
/// vuelve a abrir LOGUEADO en la cuenta anterior al reinstalar —con sus turnos,
/// sus puntos y sus datos— y el candado de PIN del dueño anterior reaparece
/// para el nuevo, sin forma de abrirlo.
///
/// El patrón es el estándar: una marca en un almacén que sí se borra al
/// desinstalar ([MarcaInstalacion]). Si al arrancar NO está la marca pero la
/// caja fuerte tiene rastro de uso, es una reinstalación: se borra TODO el
/// almacenamiento seguro antes de que nadie lo lea, y recién después se
/// escribe la marca.
///
/// Consecuencias que hay que tener presentes:
/// - **Corre ANTES de `Supabase.initialize`**, que es quien lee la sesión.
/// - El primer arranque de una instalación limpia sólo escribe la marca; el
///   login silencioso normal (cerrar sesión y volver a entrar sin código) no
///   se toca, porque la marca ya está.
/// - La PRIMERA apertura después de actualizar desde una versión sin marca
///   también cae en "restos": los equipos que ya tenían la app instalada
///   vuelven a pasar por el OTP una vez. Al 10/sep/2026 la app no está
///   publicada (sólo builds de desarrollo), así que ese costo es aceptable y
///   se paga una sola vez.
/// - **Falla abierto**: si `SharedPreferences` o la caja fuerte tiran, no se
///   borra nada. Borrar una sesión por un error de lectura sería peor que la
///   fuga que esto arregla.
class InstallGuard {
  InstallGuard._();

  static const marcaKey = 'instalacion_ok';

  /// Reconcilia la marca de instalación con lo que hay en la caja fuerte.
  ///
  /// Recibe todo inyectado para poder probarse sin plugins; `main.dart` usa
  /// [ejecutar], que arma la versión real.
  static Future<ResultadoInstallGuard> reconciliar({
    required MarcaInstalacion marca,
    required Future<bool> Function() hayRastro,
    required Future<void> Function() borrarTodo,
  }) async {
    try {
      if (await marca.existe()) return ResultadoInstallGuard.instalacionConocida;

      final restos = await hayRastro();
      if (restos) {
        await borrarTodo();
      }
      await marca.escribir();
      return restos
          ? ResultadoInstallGuard.restosBorrados
          : ResultadoInstallGuard.primerArranque;
    } catch (e, st) {
      debugPrint('[install] guard omitido: $e\n$st');
      return ResultadoInstallGuard.omitido;
    }
  }

  /// Versión real: marca en `SharedPreferences`, rastro y borrado sobre los dos
  /// storages seguros de la app (sesión de Supabase + datos del cliente).
  static Future<ResultadoInstallGuard> ejecutar() => reconciliar(
        marca: const MarcaInstalacionPrefs(),
        hayRastro: () async =>
            await SecureLocalStorage.tieneSesionGuardada() ||
            await SecureStorageService.tieneRastroDeUsoPrevio(),
        borrarTodo: () async {
          await SecureLocalStorage.borrarSesionGuardada();
          await SecureStorageService.clearAll();
        },
      );
}
