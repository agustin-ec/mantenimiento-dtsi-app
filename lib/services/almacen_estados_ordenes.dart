import 'package:hive/hive.dart';

import '../models/orden.dart';

/// Último estado conocido de las órdenes de cada persona, en la caja de
/// preferencias. Solo se guarda texto: id de la orden → estado del backend.
class AlmacenEstadosOrdenes {
  final Box _caja;

  AlmacenEstadosOrdenes(this._caja);

  static String clave(int usuarioId) => 'estados_ordenes_$usuarioId';

  /// null si la persona aún no tiene mapa guardado (primera carga).
  Map<int, EstadoOrden>? leer(int usuarioId) {
    final guardado = _caja.get(clave(usuarioId));
    if (guardado is! Map) return null;
    final estados = <int, EstadoOrden>{};
    for (final entrada in guardado.entries) {
      final id = int.tryParse(entrada.key.toString());
      if (id == null) continue;
      estados[id] = EstadoOrden.desdeApi(entrada.value);
    }
    return estados;
  }

  Future<void> guardar(int usuarioId, Map<int, EstadoOrden> estados) {
    return _caja.put(clave(usuarioId), {
      for (final entrada in estados.entries)
        '${entrada.key}': entrada.value.valorApi,
    });
  }
}
