import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/seguimiento_controller.dart';
import 'package:mantenimiento_dtsi/models/usuario.dart';
import 'package:mantenimiento_dtsi/services/almacen_seguimiento.dart';

import '../utils/hive_temporal.dart';
import '../utils/repositorio_falso.dart';

void main() {
  late Future<void> Function() limpiar;
  late AlmacenSeguimiento almacen;
  late RepositorioFalso repoAuth;
  late AuthController auth;
  late SeguimientoController seguimiento;

  setUp(() async {
    limpiar = await iniciarHiveTemporal();
    almacen = AlmacenSeguimiento();
    repoAuth = RepositorioFalso();
    auth = AuthController(repoAuth, navegar: (_) {});
    seguimiento = Get.put(SeguimientoController(almacen, auth));
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
    await seguimiento.alternar(4);
    expect(seguimiento.estaSiguiendo(4), isTrue);
    expect(await almacen.leer(usuarioPrueba.id), {4});

    await seguimiento.alternar(4);
    expect(seguimiento.estaSiguiendo(4), isFalse);
    expect(await almacen.leer(usuarioPrueba.id), isEmpty);
  });

  test('al iniciar sesión carga los equipos seguidos guardados', () async {
    await almacen.guardar(usuarioPrueba.id, {2, 5});
    await entrar();
    await esperar();
    expect(seguimiento.ids, {2, 5});
  });

  test('al cerrar sesión se vacía la memoria pero no el disco', () async {
    await entrar();
    await seguimiento.alternar(3);

    await auth.cerrarSesion();
    expect(seguimiento.ids, isEmpty);
    expect(await almacen.leer(usuarioPrueba.id), {3});

    await entrar();
    await esperar();
    expect(seguimiento.ids, {3});
  });

  test(
    'la caducidad por 401 también vacía la memoria y conserva el disco',
    () async {
      await entrar();
      await seguimiento.alternar(3);

      auth.alCaducarSesion();
      expect(seguimiento.ids, isEmpty);
      expect(await almacen.leer(usuarioPrueba.id), {3});
    },
  );

  test('dos personas no comparten seguimiento', () async {
    await entrar();
    await seguimiento.alternar(1);
    await auth.cerrarSesion();

    // Otra persona entra en el mismo dispositivo.
    auth.usuario.value = const Usuario(
      id: 2,
      email: 'luis@utb.edu.ec',
      nombreCompleto: 'Luis Mora',
    );
    auth.estado.value = EstadoAuth.conSesion;
    await esperar();
    expect(seguimiento.ids, isEmpty);
    await seguimiento.alternar(9);
    expect(await almacen.leer(2), {9});
    expect(await almacen.leer(usuarioPrueba.id), {1});
  });

  test('sin sesión alternar no hace nada', () async {
    await seguimiento.alternar(1);
    expect(seguimiento.ids, isEmpty);
  });
}
