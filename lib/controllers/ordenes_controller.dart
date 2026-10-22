import 'package:get/get.dart';

import '../models/orden.dart';
import '../repositories/orden_repository.dart';
import '../services/api_exception.dart';
import '../utils/sesion.dart';
import 'auth_controller.dart';
import 'equipos_controller.dart';

enum EstadosOrdenes { cargando, exito, vacio, error }

/// Lista de órdenes con filtro local por estado. Se limpia sola cuando la
/// sesión termina, sea por cierre manual o por caducidad.
class OrdenesController extends GetxController {
  final OrdenRepository _repositorio;
  final AuthController _auth;
  final EquiposController? _equipos;

  final estado = EstadosOrdenes.cargando.obs;
  final ordenes = <Orden>[].obs;
  final Rxn<EstadoOrden> filtroEstado = Rxn<EstadoOrden>();
  final RxnString mensaje = RxnString();

  /// Cambia al limpiar: una respuesta que llega después se descarta.
  int _generacion = 0;

  OrdenesController(this._repositorio, this._auth, {this._equipos});

  @override
  void onInit() {
    super.onInit();
    alCambiarSesion(_auth, alTerminar: limpiar);
  }

  /// Órdenes que cumplen el filtro de estado.
  List<Orden> get ordenesFiltradas {
    final filtro = filtroEstado.value;
    if (filtro == null) return ordenes.toList();
    return ordenes.where((o) => o.estado == filtro).toList();
  }

  /// Cuántas órdenes da cada chip de estado, incluso con 0.
  Map<EstadoOrden, int> get conteoPorEstado {
    final conteo = {for (final e in EstadoOrden.filtrables) e: 0};
    for (final orden in ordenes) {
      if (conteo.containsKey(orden.estado)) {
        conteo[orden.estado] = conteo[orden.estado]! + 1;
      }
    }
    return conteo;
  }

  /// Total para el chip «Todos»: cuenta también los estados desconocidos.
  int get total => ordenes.length;

  bool get hayFiltros => filtroEstado.value != null;

  /// Código y nombre del equipo si ya está cargado en memoria; si no,
  /// «Equipo #id». No pide nada al servidor.
  String etiquetaEquipo(int equipoId) {
    final equipo = _equipos?.porId(equipoId);
    if (equipo == null) return 'Equipo #$equipoId';
    return '${equipo.codigoInventario} · ${equipo.marca} ${equipo.modelo}'
        .trim();
  }

  /// Carga mostrando el indicador de progreso.
  Future<void> cargar() async {
    estado.value = EstadosOrdenes.cargando;
    mensaje.value = null;
    await _traer();
  }

  /// Recarga sin volver al indicador de progreso (arrastrar para refrescar).
  /// Si falla y ya había datos, los conserva y deja el mensaje.
  Future<void> refrescar() => _traer(conservarDatos: true);

  Future<void> _traer({bool conservarDatos = false}) async {
    final generacion = _generacion;
    try {
      final lista = await _repositorio.listarOrdenes();
      if (generacion != _generacion) return;
      // El contrato no fija el orden: primero las más recientes.
      lista.sort((a, b) {
        final fa = a.fechaSolicitud, fb = b.fechaSolicitud;
        if (fa == null && fb == null) return b.id.compareTo(a.id);
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fb.compareTo(fa);
      });
      ordenes.assignAll(lista);
      mensaje.value = null;
      estado.value = lista.isEmpty
          ? EstadosOrdenes.vacio
          : EstadosOrdenes.exito;
    } catch (e) {
      if (generacion != _generacion) return;
      mensaje.value = ApiException.desdeError(e).mensaje;
      if (!(conservarDatos && ordenes.isNotEmpty)) {
        estado.value = EstadosOrdenes.error;
      }
    }
  }

  void filtrarPorEstado(EstadoOrden? nuevo) => filtroEstado.value = nuevo;

  void limpiarFiltros() => filtroEstado.value = null;

  /// Descarta de la memoria los datos de la persona.
  void limpiar() {
    _generacion++;
    ordenes.clear();
    limpiarFiltros();
    mensaje.value = null;
    estado.value = EstadosOrdenes.cargando;
  }
}
