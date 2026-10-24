import 'dart:async';

import 'package:get/get.dart';

import '../models/orden.dart';
import '../repositories/orden_repository.dart';
import '../services/api_exception.dart';
import '../services/avisos_ordenes.dart';
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
  final AvisosOrdenes? _avisos;

  final estado = EstadosOrdenes.cargando.obs;
  final ordenes = <Orden>[].obs;
  final Rxn<EstadoOrden> filtroEstado = Rxn<EstadoOrden>();
  final RxnString mensaje = RxnString();

  /// Cambia al limpiar: una respuesta que llega después se descarta.
  int _generacion = 0;

  /// Sube con cada acción de la propia persona (crear, cambiar estado,
  /// eliminar): una respuesta que estaba en camino se ve «vieja» y no se
  /// compara para avisar.
  int _accionesPropias = 0;

  /// Cargas en curso; el refresco silencioso no se solapa con ellas.
  int _cargasEnCurso = 0;

  OrdenesController(
    this._repositorio,
    this._auth, {
    this._equipos,
    this._avisos,
  });

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

  /// Incorpora una orden recién creada. Si la lista ya está cargada (éxito o
  /// vacío) se inserta la que devolvió el servidor; en cualquier otro estado
  /// (cargando o error) no se inserta y se vuelve a cargar la lista completa.
  void incorporarCreada(Orden orden) {
    _registrarPropia(orden);
    final estadoActual = estado.value;
    if (estadoActual != EstadosOrdenes.exito &&
        estadoActual != EstadosOrdenes.vacio) {
      unawaited(cargar());
      return;
    }
    ordenes.removeWhere((o) => o.id == orden.id);
    ordenes.insert(0, orden);
    mensaje.value = null;
    estado.value = EstadosOrdenes.exito;
  }

  /// Refleja el cambio de estado de una orden. Si la lista ya está en éxito
  /// reemplaza esa orden en su sitio (si no está, no hace nada); en cualquier
  /// otro estado vuelve a cargar la lista completa.
  void actualizarOrden(Orden orden) {
    _registrarPropia(orden);
    if (estado.value != EstadosOrdenes.exito) {
      unawaited(cargar());
      return;
    }
    final indice = ordenes.indexWhere((o) => o.id == orden.id);
    if (indice >= 0) ordenes[indice] = orden;
  }

  /// Quita una orden eliminada. Si la lista ya está en éxito la quita en su
  /// sitio (y pasa a vacío si era la última); en cualquier otro estado vuelve
  /// a cargar la lista completa.
  void quitar(int id) {
    _accionesPropias++;
    _avisos?.olvidar(id);
    if (estado.value != EstadosOrdenes.exito) {
      unawaited(cargar());
      return;
    }
    ordenes.removeWhere((o) => o.id == id);
    if (ordenes.isEmpty) estado.value = EstadosOrdenes.vacio;
  }

  /// Carga mostrando el indicador de progreso.
  Future<void> cargar() async {
    estado.value = EstadosOrdenes.cargando;
    mensaje.value = null;
    await _traer();
  }

  void _registrarPropia(Orden orden) {
    _accionesPropias++;
    _avisos?.registrarPropia(orden);
  }

  /// Recarga sin volver al indicador de progreso (arrastrar para refrescar).
  /// Si falla y ya había datos, los conserva y deja el mensaje.
  Future<void> refrescar() => _traer(conservarDatos: true);

  /// Recarga periódica: no muestra errores, no toca el estado ni la lista si
  /// falla, y no se solapa con otra carga.
  Future<void> refrescarEnSilencio() {
    if (_cargasEnCurso > 0) return Future.value();
    return _traer(conservarDatos: true, silencioso: true);
  }

  Future<void> _traer({
    bool conservarDatos = false,
    bool silencioso = false,
  }) async {
    final generacion = _generacion;
    final acciones = _accionesPropias;
    _cargasEnCurso++;
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
      if (acciones == _accionesPropias) await _compararParaAvisar(lista);
    } catch (e) {
      if (generacion != _generacion || silencioso) return;
      mensaje.value = ApiException.desdeError(e).mensaje;
      if (!(conservarDatos && ordenes.isNotEmpty)) {
        estado.value = EstadosOrdenes.error;
      }
    } finally {
      _cargasEnCurso--;
    }
  }

  /// Un fallo al comparar o avisar nunca convierte la carga en un error.
  Future<void> _compararParaAvisar(List<Orden> lista) async {
    try {
      await _avisos?.alCargar(lista);
    } catch (_) {
      // El mapa se queda como estaba y se reintenta en la siguiente carga.
    }
  }

  void filtrarPorEstado(EstadoOrden? nuevo) => filtroEstado.value = nuevo;

  void limpiarFiltros() => filtroEstado.value = null;

  /// Descarta de la memoria los datos de la persona.
  void limpiar() {
    _generacion++;
    _avisos?.limpiar();
    ordenes.clear();
    limpiarFiltros();
    mensaje.value = null;
    estado.value = EstadosOrdenes.cargando;
  }
}
