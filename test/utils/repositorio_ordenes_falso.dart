import 'dart:async';

import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/repositories/orden_repository.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

Orden ordenPrueba(
  int id, {
  int equipoId = 1,
  EstadoOrden estado = EstadoOrden.creada,
  DateTime? fechaSolicitud,
  String descripcion = 'La pantalla no enciende',
}) => Orden(
  id: id,
  codigoOrden: 'OT-$id',
  equipoId: equipoId,
  solicitanteId: 1,
  tipo: TipoMantenimiento.correctivo,
  prioridad: PrioridadOrden.alta,
  estado: estado,
  descripcionProblema: descripcion,
  fechaSolicitud: fechaSolicitud ?? DateTime.utc(2026, 9, 20, 10),
);

/// Repositorio de órdenes sin red.
class RepositorioOrdenesFalso implements OrdenRepository {
  List<Orden> ordenes = [];
  ApiException? error;

  /// Si se define, [obtenerOrden] devuelve esta orden en lugar de buscarla.
  Orden? detalle;
  ApiException? errorDetalle;
  final List<String> llamadas = [];

  /// Orden que devuelve [crearOrden]; si es null, una de prueba con id 100.
  Orden? creada;
  ApiException? errorCrear;

  /// Si se define, [crearOrden] espera a que se complete (para probar el
  /// envío en curso).
  Completer<void>? espera;

  /// Argumentos de cada llamada a [crearOrden].
  final List<Map<String, Object>> creaciones = [];

  @override
  Future<List<Orden>> listarOrdenes() async {
    llamadas.add('listarOrdenes');
    if (error != null) throw error!;
    return List.of(ordenes);
  }

  @override
  Future<Orden> obtenerOrden(int id) async {
    llamadas.add('obtenerOrden:$id');
    if (errorDetalle != null) throw errorDetalle!;
    return detalle ?? ordenes.firstWhere((o) => o.id == id);
  }

  @override
  Future<Orden> crearOrden({
    required int equipoId,
    required TipoMantenimiento tipo,
    required PrioridadOrden prioridad,
    required String descripcion,
  }) async {
    llamadas.add('crearOrden');
    creaciones.add({
      'equipoId': equipoId,
      'tipo': tipo,
      'prioridad': prioridad,
      'descripcion': descripcion,
    });
    if (espera != null) await espera!.future;
    if (errorCrear != null) throw errorCrear!;
    return creada ?? ordenPrueba(100, equipoId: equipoId);
  }
}
