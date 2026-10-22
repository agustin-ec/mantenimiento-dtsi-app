import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/controllers/detalle_orden_controller.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_ordenes_falso.dart';

void main() {
  late RepositorioOrdenesFalso repo;
  late DetalleOrdenController controlador;

  setUp(() {
    repo = RepositorioOrdenesFalso()..ordenes = [ordenPrueba(5)];
    controlador = DetalleOrdenController(repo, ordenPrueba(5));
  });

  test('muestra la orden recibida antes de refrescar', () {
    expect(controlador.orden.value.id, 5);
    expect(controlador.estado.value, EstadoDetalleOrden.cargando);
  });

  test('cargar reemplaza la orden con la del backend', () async {
    repo.detalle = ordenPrueba(5, estado: EstadoOrden.completada);
    await controlador.cargar();
    expect(controlador.estado.value, EstadoDetalleOrden.exito);
    expect(controlador.orden.value.estado, EstadoOrden.completada);
    expect(repo.llamadas, ['obtenerOrden:5']);
  });

  test('si el refresco falla conserva la orden y deja el mensaje', () async {
    repo.errorDetalle = const ApiException('No se encontró lo que buscabas.');
    await controlador.cargar();
    expect(controlador.estado.value, EstadoDetalleOrden.error);
    expect(controlador.mensaje.value, 'No se encontró lo que buscabas.');
    expect(controlador.orden.value.codigoOrden, 'OT-5');
  });

  test('reintentar tras un fallo vuelve a éxito y limpia el mensaje', () async {
    repo.errorDetalle = const ApiException(ApiException.mensajeSinConexion);
    await controlador.cargar();
    repo.errorDetalle = null;
    await controlador.cargar();
    expect(controlador.estado.value, EstadoDetalleOrden.exito);
    expect(controlador.mensaje.value, isNull);
  });
}
