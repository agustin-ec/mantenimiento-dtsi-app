import 'package:get/get.dart';

import '../models/evento_historial.dart';
import '../repositories/equipo_repository.dart';
import '../services/api_exception.dart';

enum EstadoHistorial { cargando, exito, vacio, error }

/// Historial de un equipo, del más reciente al más antiguo.
class DetalleEquipoController extends GetxController {
  final EquipoRepository _repositorio;
  final int equipoId;

  final estado = EstadoHistorial.cargando.obs;
  final eventos = <EventoHistorial>[].obs;
  final RxnString mensaje = RxnString();

  DetalleEquipoController(this._repositorio, this.equipoId);

  Future<void> cargar() async {
    estado.value = EstadoHistorial.cargando;
    mensaje.value = null;
    try {
      final lista = await _repositorio.listarHistorial(equipoId);
      // El contrato no fija el orden, así que se ordena aquí.
      lista.sort((a, b) {
        final fa = a.fecha, fb = b.fecha;
        if (fa == null && fb == null) return b.id.compareTo(a.id);
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fb.compareTo(fa);
      });
      eventos.assignAll(lista);
      estado.value = lista.isEmpty
          ? EstadoHistorial.vacio
          : EstadoHistorial.exito;
    } catch (e) {
      mensaje.value = ApiException.desdeError(e).mensaje;
      estado.value = EstadoHistorial.error;
    }
  }
}
