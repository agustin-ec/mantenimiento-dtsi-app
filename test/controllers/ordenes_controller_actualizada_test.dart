import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_falso.dart';
import '../utils/repositorio_ordenes_falso.dart';

void main() {
  late RepositorioOrdenesFalso repo;
  late OrdenesController controlador;

  Future<void> esperar() => Future<void>.delayed(Duration.zero);

  setUp(() {
    repo = RepositorioOrdenesFalso()
      ..ordenes = [
        ordenPrueba(1, fechaSolicitud: DateTime.utc(2026, 9, 2)),
        ordenPrueba(2, fechaSolicitud: DateTime.utc(2026, 9, 1)),
      ];
    final auth = AuthController(RepositorioFalso(), navegar: (_) {});
    controlador = Get.put(OrdenesController(repo, auth));
  });

  tearDown(Get.reset);

  test('con la lista en éxito reemplaza la orden en su sitio', () async {
    await controlador.cargar();
    repo.llamadas.clear();

    controlador.actualizarOrden(ordenPrueba(2, estado: EstadoOrden.enProceso));

    expect(controlador.ordenes.map((o) => o.id), [1, 2]);
    expect(controlador.ordenes[1].estado, EstadoOrden.enProceso);
    expect(controlador.conteoPorEstado[EstadoOrden.enProceso], 1);
    expect(controlador.conteoPorEstado[EstadoOrden.creada], 1);
    expect(repo.llamadas, isEmpty);
  });

  test('una orden que no está en la lista no cambia nada', () async {
    await controlador.cargar();
    repo.llamadas.clear();

    controlador.actualizarOrden(ordenPrueba(99));

    expect(controlador.ordenes.map((o) => o.id), [1, 2]);
    expect(repo.llamadas, isEmpty);
  });

  test('con la lista vacía no inserta: recarga', () async {
    repo.ordenes = [];
    await controlador.cargar();
    expect(controlador.estado.value, EstadosOrdenes.vacio);
    repo.ordenes = [ordenPrueba(1)];
    repo.llamadas.clear();

    controlador.actualizarOrden(ordenPrueba(1, estado: EstadoOrden.cancelada));
    await esperar();

    expect(repo.llamadas, ['listarOrdenes']);
    expect(controlador.estado.value, EstadosOrdenes.exito);
    expect(controlador.ordenes.single.estado, EstadoOrden.creada);
  });

  test('con la lista cargando no reemplaza: recarga', () async {
    expect(controlador.estado.value, EstadosOrdenes.cargando);

    controlador.actualizarOrden(ordenPrueba(1, estado: EstadoOrden.cancelada));
    await esperar();

    expect(repo.llamadas, ['listarOrdenes']);
    expect(controlador.ordenes.first.estado, EstadoOrden.creada);
  });

  test('con la lista en error no reemplaza: recarga', () async {
    repo.error = const ApiException(ApiException.mensajeSinConexion);
    await controlador.cargar();
    expect(controlador.estado.value, EstadosOrdenes.error);
    repo.error = null;
    repo.llamadas.clear();

    controlador.actualizarOrden(ordenPrueba(1, estado: EstadoOrden.cancelada));
    await esperar();

    expect(repo.llamadas, ['listarOrdenes']);
    expect(controlador.estado.value, EstadosOrdenes.exito);
    expect(controlador.ordenes, hasLength(2));
  });
}
