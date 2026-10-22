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
}
