import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_falso.dart';
import '../utils/repositorio_ordenes_falso.dart';

void main() {
  late RepositorioOrdenesFalso repo;
  late OrdenesController controlador;

  Future<void> esperar() => Future<void>.delayed(Duration.zero);

  setUp(() {
    repo = RepositorioOrdenesFalso()..ordenes = [ordenPrueba(1)];
    final auth = AuthController(RepositorioFalso(), navegar: (_) {});
    controlador = Get.put(OrdenesController(repo, auth));
  });

  tearDown(Get.reset);

  test('con la lista en éxito inserta la orden sin pedir la lista', () async {
    await controlador.cargar();
    repo.llamadas.clear();

    controlador.incorporarCreada(ordenPrueba(50));

    expect(controlador.ordenes.map((o) => o.id), [50, 1]);
    expect(controlador.estado.value, EstadosOrdenes.exito);
    expect(repo.llamadas, isEmpty);
  });

  test('con la lista vacía inserta la orden y pasa a éxito', () async {
    repo.ordenes = [];
    await controlador.cargar();
    expect(controlador.estado.value, EstadosOrdenes.vacio);
    repo.llamadas.clear();

    controlador.incorporarCreada(ordenPrueba(50));

    expect(controlador.ordenes.map((o) => o.id), [50]);
    expect(controlador.estado.value, EstadosOrdenes.exito);
    expect(repo.llamadas, isEmpty);
  });

  test('con la lista cargando no inserta: recarga desde el servidor', () async {
    expect(controlador.estado.value, EstadosOrdenes.cargando);

    controlador.incorporarCreada(ordenPrueba(50));
    await esperar();

    expect(repo.llamadas, ['listarOrdenes']);
    expect(controlador.ordenes.map((o) => o.id), [1]);
    expect(controlador.estado.value, EstadosOrdenes.exito);
  });

  test('con la lista en error no inserta: recarga desde el servidor', () async {
    repo.error = const ApiException(ApiException.mensajeSinConexion);
    await controlador.cargar();
    expect(controlador.estado.value, EstadosOrdenes.error);
    repo.error = null;
    repo.llamadas.clear();

    controlador.incorporarCreada(ordenPrueba(50));
    await esperar();

    expect(repo.llamadas, ['listarOrdenes']);
    expect(controlador.ordenes.map((o) => o.id), [1]);
    expect(controlador.estado.value, EstadosOrdenes.exito);
    expect(controlador.mensaje.value, isNull);
  });
}
