import 'dart:async';

import 'package:get/get.dart';

import '../models/equipo.dart';
import '../models/orden.dart';
import '../repositories/orden_repository.dart';
import '../services/api_exception.dart';
import '../utils/validadores.dart';
import 'equipos_controller.dart';
import 'ordenes_controller.dart';

/// Estado del formulario de nueva orden y de su envío. Se crea al abrir la
/// pantalla y se elimina al cerrarla.
class FormularioOrdenController extends GetxController {
  final OrdenRepository _repositorio;
  final EquiposController _equipos;
  final OrdenesController _ordenes;

  final Rxn<int> equipoId = Rxn<int>();
  final tipo = TipoMantenimiento.correctivo.obs;
  final prioridad = PrioridadOrden.media.obs;
  final descripcion = ''.obs;

  /// Verdadero mientras la petición está en curso: bloquea el doble envío.
  final enviando = false.obs;

  /// Error del servidor (o de red) del último intento.
  final RxnString mensaje = RxnString();

  FormularioOrdenController(this._repositorio, this._equipos, this._ordenes);

  @override
  void onInit() {
    super.onInit();
    // El estado inicial de los equipos es «cargando» aunque nadie haya pedido
    // nada, así que solo se confía en ellos cuando ya están cargados.
    if (_equipos.estado.value != EstadoEquipos.exito) recargarEquipos();
  }

  EstadoEquipos get estadoEquipos => _equipos.estado.value;

  String? get mensajeEquipos => _equipos.mensaje.value;

  /// Equipos en memoria que se pueden elegir: todos menos los dados de baja.
  /// El servidor sigue siendo quien decide (puede haber cambiado el estado).
  List<Equipo> get equiposElegibles => _equipos.equipos
      .where((e) => e.estado != EstadoEquipo.dadoDeBaja)
      .toList();

  void recargarEquipos() => unawaited(_equipos.cargar());

  /// Hay equipos cargados entre los que elegir.
  bool get hayEquipos =>
      estadoEquipos == EstadoEquipos.exito && equiposElegibles.isNotEmpty;

  String? validarEquipo() => Validadores.equipo(equipoId.value);

  String? validarDescripcion() =>
      Validadores.descripcionProblema(descripcion.value);

  bool get esValido => validarEquipo() == null && validarDescripcion() == null;

  /// Envía la orden. Devuelve la orden creada, o null si no se envió (datos
  /// no válidos o ya hay un envío en curso) o si falló; en ese caso el motivo
  /// queda en [mensaje].
  Future<Orden?> enviar() async {
    if (enviando.value || !esValido) return null;
    enviando.value = true;
    mensaje.value = null;
    try {
      final orden = await _repositorio.crearOrden(
        equipoId: equipoId.value!,
        tipo: tipo.value,
        prioridad: prioridad.value,
        descripcion: descripcion.value.trim(),
      );
      _ordenes.incorporarCreada(orden);
      return orden;
    } catch (e) {
      mensaje.value = ApiException.desdeError(e).mensaje;
      return null;
    } finally {
      enviando.value = false;
    }
  }
}
