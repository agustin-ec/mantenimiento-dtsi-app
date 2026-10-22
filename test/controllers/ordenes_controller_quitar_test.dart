import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';

import '../utils/repositorio_falso.dart';
import '../utils/repositorio_ordenes_falso.dart';

void main() {
  late RepositorioOrdenesFalso repo;
  late OrdenesController controlador;

  setUp(() {
    repo = RepositorioOrdenesFalso()
      ..ordenes = [ordenPrueba(1), ordenPrueba(2)];
    controlador = Get.put(
      OrdenesController(
        repo,
        AuthController(RepositorioFalso(), navegar: (_) {}),
      ),
    );
  });
  tearDown(Get.reset);

  test('en éxito quita la orden en su sitio sin recargar', () async {
    await controlador.cargar();
    repo.llamadas.clear();

    controlador.quitar(1);

    expect(controlador.ordenes.map((o) => o.id), [2]);
    expect(controlador.estado.value, EstadosOrdenes.exito);
    expect(repo.llamadas, isEmpty);
  });

  test('si era la última pasa a vacío', () async {
    repo.ordenes = [ordenPrueba(1)];
    await controlador.cargar();

    controlador.quitar(1);

    expect(controlador.ordenes, isEmpty);
    expect(controlador.estado.value, EstadosOrdenes.vacio);
  });

  test('fuera de éxito recarga la lista completa', () async {
    repo.ordenes = [ordenPrueba(2)];
    expect(controlador.estado.value, EstadosOrdenes.cargando);

    controlador.quitar(1);
    await Future<void>.delayed(Duration.zero);

    expect(repo.llamadas, ['listarOrdenes']);
    expect(controlador.ordenes.map((o) => o.id), [2]);
  });
}
