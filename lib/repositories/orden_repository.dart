import '../models/orden.dart';
import '../models/tecnico.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';

/// Lectura, creación y cambios de estado de órdenes de mantenimiento. Los errores salen como
/// [ApiException]. No hay caché: las órdenes siempre vienen del backend.
class OrdenRepository {
  /// Máximo que permite el backend por petición. El contrato no devuelve
  /// total, así que por ahora se pide una sola página.
  static const limite = 100;

  final ApiClient _cliente;

  OrdenRepository(this._cliente);

  Future<List<Orden>> listarOrdenes() async {
    try {
      final respuesta = await _cliente.dio.get(
        '/mantenimientos/',
        queryParameters: {'skip': 0, 'limit': limite},
      );
      return _mapas(respuesta.data).map(Orden.fromJson).toList();
    } catch (e) {
      throw ApiException.desdeError(e);
    }
  }

  Future<Orden> obtenerOrden(int id) async {
    try {
      final respuesta = await _cliente.dio.get('/mantenimientos/$id');
      return _orden(respuesta.data);
    } catch (e) {
      throw ApiException.desdeError(e);
    }
  }

  /// Crea una orden. El solicitante sale del token, no se envía. El POST no se
  /// reintenta solo: no es idempotente.
  Future<Orden> crearOrden({
    required int equipoId,
    required TipoMantenimiento tipo,
    required PrioridadOrden prioridad,
    required String descripcion,
  }) async {
    try {
      final respuesta = await _cliente.dio.post(
        '/mantenimientos/',
        data: {
          'equipo_id': equipoId,
          'tipo_mantenimiento': tipo.valorApi,
          'prioridad': prioridad.valorApi,
          'descripcion_problema': descripcion,
        },
      );
      return _orden(respuesta.data);
    } catch (e) {
      throw ApiException.desdeError(e);
    }
  }

  /// Pasa la orden a EN_PROCESO (y el equipo a EN_MANTENIMIENTO). Sin cuerpo.
  Future<Orden> iniciarOrden(int id) => _cambiarEstado(id, 'iniciar');

  /// Cierra la orden como COMPLETADA. Los repuestos son opcionales: si vienen
  /// vacíos no se envían.
  Future<Orden> completarOrden(
    int id, {
    required String diagnostico,
    required String accionesRealizadas,
    String? repuestosUtilizados,
  }) => _cambiarEstado(
    id,
    'completar',
    cuerpo: {
      'diagnostico': diagnostico,
      'acciones_realizadas': accionesRealizadas,
      if (repuestosUtilizados != null && repuestosUtilizados.isNotEmpty)
        'repuestos_utilizados': repuestosUtilizados,
    },
  );

  Future<Orden> cancelarOrden(int id, {required String motivo}) =>
      _cambiarEstado(id, 'cancelar', cuerpo: {'motivo_cancelacion': motivo});

  /// Asigna o reasigna el técnico; la orden queda ASIGNADA.
  Future<Orden> asignarTecnico(int id, int tecnicoId) =>
      _cambiarEstado(id, 'asignar', cuerpo: {'tecnico_id': tecnicoId});

  /// Elimina (borrado lógico) una orden CREADA. El 204 llega sin cuerpo, así
  /// que no se interpreta la respuesta. No se reintenta solo.
  Future<void> eliminarOrden(int id) async {
    try {
      await _cliente.dio.delete('/mantenimientos/$id');
    } catch (e) {
      throw ApiException.desdeError(e);
    }
  }

  /// Técnicos activos para asignar (solo admin; otro rol recibe 403).
  Future<List<Tecnico>> listarTecnicos() async {
    try {
      final respuesta = await _cliente.dio.get('/usuarios/tecnicos');
      return _mapas(respuesta.data).map(Tecnico.fromJson).toList();
    } catch (e) {
      throw ApiException.desdeError(e);
    }
  }

  /// Los PATCH de cambio de estado no se reintentan solos: no son idempotentes.
  Future<Orden> _cambiarEstado(
    int id,
    String accion, {
    Map<String, dynamic>? cuerpo,
  }) async {
    try {
      final respuesta = await _cliente.dio.patch(
        '/mantenimientos/$id/$accion',
        data: cuerpo,
      );
      return _orden(respuesta.data);
    } catch (e) {
      throw ApiException.desdeError(e);
    }
  }

  Orden _orden(Object? datos) {
    if (datos is! Map) throw const ApiException(ApiException.mensajeGenerico);
    return Orden.fromJson(Map<String, dynamic>.from(datos));
  }

  /// Los elementos que no son objetos JSON se ignoran.
  List<Map<String, dynamic>> _mapas(Object? datos) {
    if (datos is! List) {
      throw const ApiException(ApiException.mensajeGenerico);
    }
    return datos
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }
}
