import 'package:get/get.dart';

import '../models/tecnico.dart';
import '../repositories/orden_repository.dart';
import '../services/api_exception.dart';
import '../utils/sesion.dart';
import 'auth_controller.dart';

enum EstadosTecnicos { cargando, exito, vacio, error }

/// Técnicos disponibles para asignar órdenes. Solo se piden cuando un admin
/// abre la selección y se descartan al terminar la sesión.
class TecnicosController extends GetxController {
  final OrdenRepository _repositorio;
  final AuthController _auth;

  final estado = EstadosTecnicos.cargando.obs;
  final tecnicos = <Tecnico>[].obs;
  final RxnString mensaje = RxnString();

  /// Cambia al limpiar: una respuesta que llega después se descarta.
  int _generacion = 0;

  TecnicosController(this._repositorio, this._auth);

  @override
  void onInit() {
    super.onInit();
    alCambiarSesion(_auth, alTerminar: limpiar);
  }

  /// Nombre del técnico si la lista ya está en memoria; si no, null. No pide
  /// nada al servidor.
  String? nombrePara(int? id) {
    if (id == null) return null;
    for (final tecnico in tecnicos) {
      if (tecnico.id == id) return tecnico.nombreCompleto;
    }
    return null;
  }

  Future<void> cargar() async {
    final generacion = _generacion;
    estado.value = EstadosTecnicos.cargando;
    mensaje.value = null;
    try {
      final lista = await _repositorio.listarTecnicos();
      if (generacion != _generacion) return;
      tecnicos.assignAll(lista);
      estado.value = lista.isEmpty
          ? EstadosTecnicos.vacio
          : EstadosTecnicos.exito;
    } catch (e) {
      if (generacion != _generacion) return;
      mensaje.value = ApiException.desdeError(e).mensaje;
      estado.value = EstadosTecnicos.error;
    }
  }

  /// Descarta de la memoria los datos de la sesión anterior.
  void limpiar() {
    _generacion++;
    tecnicos.clear();
    mensaje.value = null;
    estado.value = EstadosTecnicos.cargando;
  }
}
