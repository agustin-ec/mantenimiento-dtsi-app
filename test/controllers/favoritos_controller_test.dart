import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/favoritos_controller.dart';
import 'package:mantenimiento_dtsi/models/usuario.dart';
import 'package:mantenimiento_dtsi/services/almacen_favoritos.dart';

import '../utils/hive_temporal.dart';
import '../utils/repositorio_falso.dart';

void main() {
  late Future<void> Function() limpiar;
  late AlmacenFavoritos almacen;
  late RepositorioFalso repoAuth;
  late AuthController auth;
  late FavoritosController favoritos;

  setUp(() async {
    limpiar = await iniciarHiveTemporal();
    almacen = AlmacenFavoritos();
    repoAuth = RepositorioFalso();
    auth = AuthController(repoAuth, navegar: (_) {});
    favoritos = Get.put(FavoritosController(almacen, auth));
  });

  tearDown(() async {
    Get.reset();
    await limpiar();
  });

  Future<void> entrar() => auth.iniciarSesion('ana@utb.edu.ec', 'clave1234');

  /// Deja que termine la lectura asíncrona que dispara el inicio de sesión.
  Future<void> esperar() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test('alternar marca, desmarca y guarda en disco', () async {
    await entrar();
    await favoritos.alternar(4);
    expect(favoritos.esFavorito(4), isTrue);
    expect(await almacen.leer(usuarioPrueba.id), {4});

    await favoritos.alternar(4);
    expect(favoritos.esFavorito(4), isFalse);
    expect(await almacen.leer(usuarioPrueba.id), isEmpty);
  });

  test('al iniciar sesión carga los favoritos guardados', () async {
    await almacen.guardar(usuarioPrueba.id, {2, 5});
    await entrar();
    await esperar();
    expect(favoritos.ids, {2, 5});
  });

  test('al cerrar sesión se vacía la memoria pero no el disco', () async {
    await entrar();
    await favoritos.alternar(3);

    await auth.cerrarSesion();
    expect(favoritos.ids, isEmpty);
    expect(await almacen.leer(usuarioPrueba.id), {3});

    await entrar();
    await esperar();
    expect(favoritos.ids, {3});
  });

  test(
    'la caducidad por 401 también vacía la memoria y conserva el disco',
    () async {
      await entrar();
      await favoritos.alternar(3);

      auth.alCaducarSesion();
      expect(favoritos.ids, isEmpty);
      expect(await almacen.leer(usuarioPrueba.id), {3});
    },
  );

  test('dos personas no comparten favoritos', () async {
    await entrar();
    await favoritos.alternar(1);
    await auth.cerrarSesion();

    // Otra persona entra en el mismo dispositivo.
    auth.usuario.value = const Usuario(
      id: 2,
      email: 'luis@utb.edu.ec',
      nombreCompleto: 'Luis Mora',
    );
    auth.estado.value = EstadoAuth.conSesion;
    await esperar();
    expect(favoritos.ids, isEmpty);
    await favoritos.alternar(9);
    expect(await almacen.leer(2), {9});
    expect(await almacen.leer(usuarioPrueba.id), {1});
  });

  test('sin sesión alternar no hace nada', () async {
    await favoritos.alternar(1);
    expect(favoritos.ids, isEmpty);
  });
}
