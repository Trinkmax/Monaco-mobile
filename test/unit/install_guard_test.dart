import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/core/auth/install_guard.dart';

/// Marca de instalación en memoria: hace de `SharedPreferences`, que es el
/// almacén que SÍ se borra al desinstalar la app.
class _MarcaFake implements MarcaInstalacion {
  _MarcaFake({this.presente = false, this.rompe = false});

  bool presente;
  final bool rompe;
  int escrituras = 0;

  @override
  Future<bool> existe() async {
    if (rompe) throw StateError('prefs rotas');
    return presente;
  }

  @override
  Future<void> escribir() async {
    escrituras++;
    presente = true;
  }
}

/// El guard de reinstalación decide con dos datos y no tiene medias tintas:
/// si no hay marca y la caja fuerte tiene rastro, es una instalación anterior
/// (en iOS el Keychain sobrevive a borrar la app) y se limpia TODO antes de
/// que Supabase lea la sesión.
void main() {
  group('InstallGuard.reconciliar', () {
    test('instalación conocida: no toca nada', () async {
      final marca = _MarcaFake(presente: true);
      var borrados = 0;
      var lecturas = 0;

      final r = await InstallGuard.reconciliar(
        marca: marca,
        hayRastro: () async {
          lecturas++;
          return true;
        },
        borrarTodo: () async => borrados++,
      );

      expect(r, ResultadoInstallGuard.instalacionConocida);
      expect(borrados, 0);
      expect(marca.escrituras, 0);
      // Ni siquiera mira la caja fuerte: con la marca puesta no hay nada que
      // decidir.
      expect(lecturas, 0);
    });

    test('primer arranque limpio: escribe la marca y no borra nada', () async {
      final marca = _MarcaFake();
      var borrados = 0;

      final r = await InstallGuard.reconciliar(
        marca: marca,
        hayRastro: () async => false,
        borrarTodo: () async => borrados++,
      );

      expect(r, ResultadoInstallGuard.primerArranque);
      expect(borrados, 0, reason: 'no hay nada que borrar');
      expect(marca.escrituras, 1);
      expect(marca.presente, isTrue);
    });

    test('reinstalación (hay rastro y no hay marca): borra y marca', () async {
      final marca = _MarcaFake();
      var borrados = 0;

      final r = await InstallGuard.reconciliar(
        marca: marca,
        hayRastro: () async => true,
        borrarTodo: () async => borrados++,
      );

      expect(r, ResultadoInstallGuard.restosBorrados);
      expect(borrados, 1);
      expect(marca.escrituras, 1);
    });

    test('el segundo arranque después de limpiar ya es conocido', () async {
      final marca = _MarcaFake();
      var borrados = 0;
      Future<bool> rastro() async => borrados == 0;

      await InstallGuard.reconciliar(
        marca: marca,
        hayRastro: rastro,
        borrarTodo: () async => borrados++,
      );
      final segundo = await InstallGuard.reconciliar(
        marca: marca,
        hayRastro: rastro,
        borrarTodo: () async => borrados++,
      );

      expect(segundo, ResultadoInstallGuard.instalacionConocida);
      expect(borrados, 1, reason: 'no se borra dos veces');
    });

    test('falla ABIERTO: si algo tira, no se borra la sesión', () async {
      var borrados = 0;

      final r = await InstallGuard.reconciliar(
        marca: _MarcaFake(rompe: true),
        hayRastro: () async => true,
        borrarTodo: () async => borrados++,
      );

      expect(r, ResultadoInstallGuard.omitido);
      expect(borrados, 0,
          reason: 'borrar una sesión por un error de lectura es peor que la '
              'fuga que esto arregla');
    });

    test('si el borrado falla, la marca NO queda escrita', () async {
      // Si se escribiera igual, el próximo arranque diría "instalación
      // conocida" y los restos de la anterior quedarían vivos para siempre.
      final marca = _MarcaFake();

      final r = await InstallGuard.reconciliar(
        marca: marca,
        hayRastro: () async => true,
        borrarTodo: () async => throw StateError('keychain roto'),
      );

      expect(r, ResultadoInstallGuard.omitido);
      expect(marca.escrituras, 0);
    });
  });
}
