import '../models/orden.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';

/// Lectura y creación de órdenes de mantenimiento. Los errores salen como
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
      final datos = respuesta.data;
      if (datos is! Map) throw const ApiException(ApiException.mensajeGenerico);
      return Orden.fromJson(Map<String, dynamic>.from(datos));
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
      final datos = respuesta.data;
      if (datos is! Map) throw const ApiException(ApiException.mensajeGenerico);
      return Orden.fromJson(Map<String, dynamic>.from(datos));
    } catch (e) {
      throw ApiException.desdeError(e);
    }
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
