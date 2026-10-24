import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/services/almacen_estados_ordenes.dart';

/// Estados de órdenes en memoria, por persona, para pruebas (sin disco).
class AlmacenEstadosOrdenesFalso implements AlmacenEstadosOrdenes {
  final Map<int, Map<int, EstadoOrden>> datos = {};
  bool fallaAlGuardar = false;

  @override
  Map<int, EstadoOrden>? leer(int usuarioId) {
    final guardado = datos[usuarioId];
    return guardado == null ? null : {...guardado};
  }

  @override
  Future<void> guardar(int usuarioId, Map<int, EstadoOrden> estados) async {
    if (fallaAlGuardar) throw StateError('disco lleno');
    datos[usuarioId] = {...estados};
  }
}
