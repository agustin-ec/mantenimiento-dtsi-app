import 'package:get/get.dart';

import '../models/orden.dart';
import '../repositories/orden_repository.dart';
import '../services/api_exception.dart';

enum EstadoDetalleOrden { cargando, exito, error }

/// Detalle de una orden. Muestra de inmediato la que llega de la lista y la
/// refresca con el backend; si el refresco falla, conserva lo que ya tenía.
class DetalleOrdenController extends GetxController {
  final OrdenRepository _repositorio;

  final Rx<Orden> orden;
  final estado = EstadoDetalleOrden.cargando.obs;
  final RxnString mensaje = RxnString();

  DetalleOrdenController(this._repositorio, Orden inicial)
    : orden = inicial.obs;

  Future<void> cargar() async {
    estado.value = EstadoDetalleOrden.cargando;
    mensaje.value = null;
    try {
      orden.value = await _repositorio.obtenerOrden(orden.value.id);
      estado.value = EstadoDetalleOrden.exito;
    } catch (e) {
      mensaje.value = ApiException.desdeError(e).mensaje;
      estado.value = EstadoDetalleOrden.error;
    }
  }
}
