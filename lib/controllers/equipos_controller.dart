import 'package:get/get.dart';

import '../models/equipo.dart';
import '../repositories/equipo_repository.dart';
import '../services/api_exception.dart';
import '../utils/texto.dart';
import 'auth_controller.dart';

enum EstadoEquipos { cargando, exito, vacio, error }

/// Lista de equipos con búsqueda y filtro locales. Se limpia sola cuando la
/// sesión termina, sea por cierre manual o por caducidad.
class EquiposController extends GetxController {
  final EquipoRepository _repositorio;
  final AuthController _auth;

  final estado = EstadoEquipos.cargando.obs;
  final equipos = <Equipo>[].obs;
  final busqueda = ''.obs;
  final Rxn<EstadoEquipo> filtroEstado = Rxn<EstadoEquipo>();
  final RxnString mensaje = RxnString();

  /// Cambia al limpiar: una respuesta que llega después se descarta.
  int _generacion = 0;

  EquiposController(this._repositorio, this._auth);

  @override
  void onInit() {
    super.onInit();
    ever(_auth.estado, (EstadoAuth e) {
      if (e == EstadoAuth.sinSesion) limpiar();
    });
  }

  /// Equipos que cumplen la búsqueda y el filtro de estado.
  List<Equipo> get equiposFiltrados {
    final texto = normalizarTexto(busqueda.value.trim());
    final filtro = filtroEstado.value;
    return equipos.where((e) {
      if (filtro != null && e.estado != filtro) return false;
      if (texto.isEmpty) return true;
      return [
        e.codigoInventario,
        e.marca,
        e.modelo,
        e.sede,
      ].any((campo) => normalizarTexto(campo).contains(texto));
    }).toList();
  }

  bool get hayFiltros =>
      busqueda.value.trim().isNotEmpty || filtroEstado.value != null;

  /// Hay equipos, pero ninguno cumple la búsqueda o el filtro. Es distinto de
  /// [EstadoEquipos.vacio], que significa que no existen equipos.
  bool get sinCoincidencias =>
      estado.value == EstadoEquipos.exito && equiposFiltrados.isEmpty;

  /// Carga mostrando el indicador de progreso.
  Future<void> cargar() async {
    estado.value = EstadoEquipos.cargando;
    mensaje.value = null;
    await _traer();
  }

  /// Recarga sin volver al indicador de progreso (arrastrar para refrescar).
  /// Si falla y ya había datos, los conserva y deja el mensaje.
  Future<void> refrescar() => _traer(conservarDatos: true);

  Future<void> _traer({bool conservarDatos = false}) async {
    final generacion = _generacion;
    try {
      final lista = await _repositorio.listarEquipos();
      if (generacion != _generacion) return;
      equipos.assignAll(lista);
      mensaje.value = null;
      estado.value = lista.isEmpty ? EstadoEquipos.vacio : EstadoEquipos.exito;
    } catch (e) {
      if (generacion != _generacion) return;
      mensaje.value = ApiException.desdeError(e).mensaje;
      if (!(conservarDatos && equipos.isNotEmpty)) {
        estado.value = EstadoEquipos.error;
      }
    }
  }

  void buscar(String texto) => busqueda.value = texto;

  void filtrarPorEstado(EstadoEquipo? nuevo) => filtroEstado.value = nuevo;

  void limpiarFiltros() {
    busqueda.value = '';
    filtroEstado.value = null;
  }

  /// Descarta todos los datos de la persona. Es el único lugar donde se hace.
  void limpiar() {
    _generacion++;
    equipos.clear();
    limpiarFiltros();
    mensaje.value = null;
    estado.value = EstadoEquipos.cargando;
  }
}
