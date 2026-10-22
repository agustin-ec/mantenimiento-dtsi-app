import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/models/equipo.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_equipos_falso.dart';
import '../utils/repositorio_falso.dart';

void main() {
  late RepositorioEquiposFalso repo;
  late EquiposController controlador;

  Future<void> esperar() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    repo = RepositorioEquiposFalso()..equipos = [equipoPrueba(1)];
    final auth = AuthController(RepositorioFalso(), navegar: (_) {});
    controlador = Get.put(EquiposController(repo, auth));
    await controlador.cargar();
    repo.llamadas.clear();
  });

  tearDown(Get.reset);

  test('marcarDesactualizados recarga en segundo plano', () async {
    repo.equipos = [equipoPrueba(1, estado: EstadoEquipo.enMantenimiento)];

    controlador.marcarDesactualizados();
    await esperar();

    expect(repo.llamadas, ['listarEquipos']);
    expect(controlador.equipos.single.estado, EstadoEquipo.enMantenimiento);
    expect(controlador.estado.value, EstadoEquipos.exito);
    expect(controlador.mensaje.value, isNull);
  });

  test(
    'si la recarga falla no hay mensaje ni cambio, y se reintenta',
    () async {
      repo.error = const ApiException(ApiException.mensajeSinConexion);
      repo.equipos = [equipoPrueba(1, estado: EstadoEquipo.enMantenimiento)];

      controlador.marcarDesactualizados();
      await esperar();

      expect(controlador.mensaje.value, isNull);
      expect(controlador.estado.value, EstadoEquipos.exito);
      expect(controlador.equipos.single.estado, EstadoEquipo.disponible);

      repo.error = null;
      controlador.actualizarSiHaceFalta();
      await esperar();

      expect(controlador.equipos.single.estado, EstadoEquipo.enMantenimiento);
      // Ya está al día: no vuelve a pedir nada.
      repo.llamadas.clear();
      controlador.actualizarSiHaceFalta();
      await esperar();
      expect(repo.llamadas, isEmpty);
    },
  );

  test('los datos que solo vienen de la caché se descartan', () async {
    repo.desdeCache = DateTime.utc(2026, 9, 1);
    repo.equipos = [equipoPrueba(1, estado: EstadoEquipo.enMantenimiento)];

    controlador.marcarDesactualizados();
    await esperar();

    expect(controlador.equipos.single.estado, EstadoEquipo.disponible);
    expect(controlador.cacheDesde.value, isNull);
    expect(controlador.mensaje.value, isNull);

    repo.desdeCache = null;
    controlador.actualizarSiHaceFalta();
    await esperar();
    expect(controlador.equipos.single.estado, EstadoEquipo.enMantenimiento);
  });

  test('sin marca actualizarSiHaceFalta no pide nada', () async {
    controlador.actualizarSiHaceFalta();
    await esperar();
    expect(repo.llamadas, isEmpty);
  });

  test('una carga normal exitosa deja los equipos al día', () async {
    repo.error = const ApiException(ApiException.mensajeSinConexion);
    controlador.marcarDesactualizados();
    await esperar();
    repo.error = null;
    await controlador.cargar();
    repo.llamadas.clear();

    controlador.actualizarSiHaceFalta();
    await esperar();

    expect(repo.llamadas, isEmpty);
  });

  test('si la sesión termina, la respuesta tardía se descarta', () async {
    repo.equipos = [equipoPrueba(1, estado: EstadoEquipo.enMantenimiento)];

    controlador.marcarDesactualizados();
    controlador.limpiar();
    await esperar();

    expect(controlador.equipos, isEmpty);
    expect(controlador.estado.value, EstadoEquipos.cargando);
  });
}
