import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/detalle_orden_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/models/usuario.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_equipos_falso.dart';
import '../utils/repositorio_falso.dart';
import '../utils/repositorio_ordenes_falso.dart';

void main() {
  late RepositorioOrdenesFalso repo;
  late RepositorioEquiposFalso repoEquipos;
  late AuthController auth;
  late OrdenesController ordenes;
  late EquiposController equipos;
  late DetalleOrdenController controlador;

  Future<void> esperar() => Future<void>.delayed(Duration.zero);

  DetalleOrdenController crear(Orden orden) => DetalleOrdenController(
    repo,
    orden,
    ordenes: ordenes,
    equipos: equipos,
    auth: auth,
  );

  void sesion(int id, [String rol = 'tecnico_dtsi']) {
    auth.usuario.value = Usuario(
      id: id,
      email: 'a@utb.edu.ec',
      nombreCompleto: 'Ana',
      rol: rol,
    );
  }

  setUp(() async {
    repo = RepositorioOrdenesFalso()
      ..ordenes = [ordenPrueba(5), ordenPrueba(6)];
    repoEquipos = RepositorioEquiposFalso()..equipos = [equipoPrueba(1)];
    auth = AuthController(RepositorioFalso(), navegar: (_) {});
    equipos = Get.put(EquiposController(repoEquipos, auth));
    ordenes = Get.put(OrdenesController(repo, auth, equipos: equipos));
    await equipos.cargar();
    await ordenes.cargar();
    repo.llamadas.clear();
    repoEquipos.llamadas.clear();
    controlador = crear(ordenPrueba(5));
  });
  tearDown(Get.reset);

  test('éxito: la orden sale de la lista y no se recargan equipos', () async {
    final resultado = await controlador.eliminar();

    expect(resultado, ResultadoAccion.exito);
    expect(repo.eliminadas, [5]);
    expect(ordenes.ordenes.map((o) => o.id), [6]);
    expect(controlador.accionEnCurso.value, isNull);
    expect(controlador.mensajeAccion.value, isNull);
    await esperar();
    expect(repoEquipos.llamadas, isEmpty);
  });

  test('400: muestra el mensaje y relee la orden', () async {
    repo.errorAccion = const ApiException(
      'Solo se pueden eliminar órdenes en estado CREADA. Estado actual: ASIGNADA.',
      codigoEstado: 400,
    );
    repo.detalle = ordenPrueba(5, estado: EstadoOrden.asignada);

    final resultado = await controlador.eliminar();

    expect(resultado, ResultadoAccion.rechazada);
    expect(controlador.mensajeAccion.value, contains('Estado actual'));
    expect(repo.llamadas, ['eliminarOrden:5', 'obtenerOrden:5']);
    expect(controlador.orden.value.estado, EstadoOrden.asignada);
    expect(ordenes.ordenes.map((o) => o.id), containsAll([5, 6]));
    expect(
      ordenes.ordenes.firstWhere((o) => o.id == 5).estado,
      EstadoOrden.asignada,
    );
  });

  test(
    '403: muestra el mensaje, no relee y la orden sigue en la lista',
    () async {
      repo.errorAccion = const ApiException(
        'Solo el solicitante de la orden o un administrador puede eliminarla',
        codigoEstado: 403,
      );

      final resultado = await controlador.eliminar();

      expect(resultado, ResultadoAccion.error);
      expect(controlador.mensajeAccion.value, contains('solicitante'));
      expect(repo.llamadas, ['eliminarOrden:5']);
      expect(ordenes.ordenes, hasLength(2));
    },
  );

  test('404: la orden ya no existe y sale de la lista', () async {
    repo.errorAccion = const ApiException(
      'Orden no encontrada',
      codigoEstado: 404,
    );

    final resultado = await controlador.eliminar();

    expect(resultado, ResultadoAccion.noExiste);
    expect(controlador.mensajeAccion.value, 'Orden no encontrada');
    expect(ordenes.ordenes.map((o) => o.id), [6]);
    expect(repo.llamadas, ['eliminarOrden:5']);
  });

  test('doble envío: la segunda llamada no llega al servidor', () async {
    repo.esperaAccion = Completer<void>();
    final primera = controlador.eliminar();
    await esperar();
    expect(controlador.accionEnCurso.value, AccionOrden.eliminar);

    expect(await controlador.eliminar(), ResultadoAccion.error);
    expect(repo.eliminadas, [5]);

    repo.esperaAccion!.complete();
    expect(await primera, ResultadoAccion.exito);
    expect(controlador.accionEnCurso.value, isNull);
  });

  group('puedeEliminar', () {
    test('el solicitante o un admin, solo en CREADA', () {
      sesion(1);
      expect(crear(ordenPrueba(5)).puedeEliminar, isTrue);
      sesion(9, 'admin');
      expect(crear(ordenPrueba(5)).puedeEliminar, isTrue);
      for (final estado in EstadoOrden.values) {
        expect(
          crear(ordenPrueba(5, estado: estado)).puedeEliminar,
          estado == EstadoOrden.creada,
          reason: estado.name,
        );
      }
    });

    test('otro usuario o sin sesión no puede', () {
      sesion(2);
      expect(controlador.puedeEliminar, isFalse);
      auth.usuario.value = null;
      expect(controlador.puedeEliminar, isFalse);
    });
  });
}
