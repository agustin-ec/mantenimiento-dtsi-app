import 'package:get/get.dart';

import '../models/orden.dart';
import '../repositories/orden_repository.dart';
import '../services/api_exception.dart';
import '../utils/validadores.dart';
import 'auth_controller.dart';
import 'equipos_controller.dart';
import 'ordenes_controller.dart';
import 'tecnicos_controller.dart';

enum EstadoDetalleOrden { cargando, exito, error }

/// Cómo terminó una acción: [exito]; [rechazada] si el servidor respondió 400
/// (la transición ya no es válida) y se volvió a leer la orden; [error] si no
/// se envió o falló por otra causa.
enum ResultadoAccion { exito, rechazada, error }

/// Detalle de una orden. Muestra de inmediato la que llega de la lista y la
/// refresca con el backend; si el refresco falla, conserva lo que ya tenía.
/// También cambia su estado (iniciar, completar y cancelar) y asigna técnico.
class DetalleOrdenController extends GetxController {
  final OrdenRepository _repositorio;
  final OrdenesController? _ordenes;
  final EquiposController? _equipos;
  final AuthController? _auth;

  /// Lista de técnicos en memoria, solo para mostrar nombres y elegir.
  final TecnicosController? tecnicos;

  final Rx<Orden> orden;
  final estado = EstadoDetalleOrden.cargando.obs;
  final RxnString mensaje = RxnString();

  /// Acción en curso: mientras no es null se bloquean todas las acciones.
  final Rxn<AccionOrden> accionEnCurso = Rxn<AccionOrden>();

  /// Error (o aviso del servidor) de la última acción.
  final RxnString mensajeAccion = RxnString();

  DetalleOrdenController(
    this._repositorio,
    Orden inicial, {
    this._ordenes,
    this._equipos,
    this.tecnicos,
    this._auth,
  }) : orden = inicial.obs;

  /// Acciones que el estado actual permite ofrecer.
  List<AccionOrden> get acciones => orden.value.estado.accionesPermitidas;

  /// «Asignar técnico» solo para admin y con la orden CREADA o ASIGNADA. Guía
  /// la interfaz: el servidor decide.
  bool get puedeAsignar =>
      (_auth?.usuario.value?.esAdmin ?? false) &&
      orden.value.estado.permiteAsignar;

  /// Los botones se habilitan cuando no hay una acción en curso ni se está
  /// leyendo la orden (su estado podría ser viejo).
  bool get accionesHabilitadas =>
      accionEnCurso.value == null &&
      estado.value != EstadoDetalleOrden.cargando;

  Future<void> cargar() async {
    estado.value = EstadoDetalleOrden.cargando;
    mensaje.value = null;
    mensajeAccion.value = null;
    try {
      orden.value = await _repositorio.obtenerOrden(orden.value.id);
      estado.value = EstadoDetalleOrden.exito;
    } catch (e) {
      mensaje.value = ApiException.desdeError(e).mensaje;
      estado.value = EstadoDetalleOrden.error;
    }
  }

  Future<ResultadoAccion> iniciar() => _ejecutar(
    AccionOrden.iniciar,
    () => _repositorio.iniciarOrden(orden.value.id),
  );

  Future<ResultadoAccion> completar({
    required String diagnostico,
    required String accionesRealizadas,
    String? repuestosUtilizados,
  }) {
    final diagnosticoLimpio = diagnostico.trim();
    final accionesLimpias = accionesRealizadas.trim();
    final error =
        Validadores.diagnostico(diagnosticoLimpio) ??
        Validadores.accionesRealizadas(accionesLimpias);
    if (error != null) return _rechazarLocal(error);
    return _ejecutar(
      AccionOrden.completar,
      () => _repositorio.completarOrden(
        orden.value.id,
        diagnostico: diagnosticoLimpio,
        accionesRealizadas: accionesLimpias,
        repuestosUtilizados: repuestosUtilizados?.trim(),
      ),
    );
  }

  Future<ResultadoAccion> cancelar(String motivo) {
    final motivoLimpio = motivo.trim();
    final error = Validadores.motivoCancelacion(motivoLimpio);
    if (error != null) return _rechazarLocal(error);
    return _ejecutar(
      AccionOrden.cancelar,
      () => _repositorio.cancelarOrden(orden.value.id, motivo: motivoLimpio),
    );
  }

  /// Asigna o reasigna el técnico. No cambia el equipo, así que no se marcan
  /// equipos como desactualizados.
  Future<ResultadoAccion> asignar(int tecnicoId) => _ejecutar(
    AccionOrden.asignar,
    () => _repositorio.asignarTecnico(orden.value.id, tecnicoId),
    cambiaEquipo: false,
  );

  Future<ResultadoAccion> _rechazarLocal(String mensajeValidacion) async {
    if (accionEnCurso.value == null) mensajeAccion.value = mensajeValidacion;
    return ResultadoAccion.error;
  }

  Future<ResultadoAccion> _ejecutar(
    AccionOrden accion,
    Future<Orden> Function() llamada, {
    bool cambiaEquipo = true,
  }) async {
    if (accionEnCurso.value != null) return ResultadoAccion.error;
    accionEnCurso.value = accion;
    mensajeAccion.value = null;
    try {
      final nueva = await llamada();
      orden.value = nueva;
      mensaje.value = null;
      estado.value = EstadoDetalleOrden.exito;
      _ordenes?.actualizarOrden(nueva);
      if (cambiaEquipo) _equipos?.marcarDesactualizados();
      return ResultadoAccion.exito;
    } catch (e) {
      final error = ApiException.desdeError(e);
      mensajeAccion.value = error.mensaje;
      if (error.codigoEstado != 400) return ResultadoAccion.error;
      await _releer();
      return ResultadoAccion.rechazada;
    } finally {
      accionEnCurso.value = null;
    }
  }

  /// Tras un 400 la orden pudo cambiar desde otro dispositivo: se lee el
  /// estado real. Si la relectura falla, queda el mensaje del servidor.
  Future<void> _releer() async {
    try {
      final real = await _repositorio.obtenerOrden(orden.value.id);
      orden.value = real;
      estado.value = EstadoDetalleOrden.exito;
      _ordenes?.actualizarOrden(real);
    } catch (_) {
      // Se conserva el mensaje del 400.
    }
  }
}
