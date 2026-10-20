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

  /// Equipos que cumplen la búsqueda de texto (sin mirar el filtro de estado).
  List<Equipo> get _coincidenBusqueda {
    final texto = normalizarTexto(busqueda.value.trim());
    if (texto.isEmpty) return equipos.toList();
    return equipos
        .where(
          (e) => [
            e.codigoInventario,
            e.marca,
            e.modelo,
            e.sede,
          ].any((campo) => normalizarTexto(campo).contains(texto)),
        )
        .toList();
  }

  /// Equipos que cumplen la búsqueda y el filtro de estado.
  List<Equipo> get equiposFiltrados {
    final filtro = filtroEstado.value;
    final lista = _coincidenBusqueda;
    if (filtro == null) return lista;
    return lista.where((e) => e.estado == filtro).toList();
  }

  /// Cuántos equipos da cada chip de estado: respeta la búsqueda, no el filtro
  /// seleccionado. Incluye todos los estados filtrables, aunque sea con 0.
  Map<EstadoEquipo, int> get conteoPorEstado {
    final conteo = {for (final e in EstadoEquipo.filtrables) e: 0};
    for (final equipo in _coincidenBusqueda) {
      if (conteo.containsKey(equipo.estado)) {
        conteo[equipo.estado] = conteo[equipo.estado]! + 1;
      }
    }
    return conteo;
  }

  /// Total para el chip «Todos»: coincide con la búsqueda, cuenta también los
  /// estados desconocidos.
  int get totalCoincidencias => _coincidenBusqueda.length;

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
