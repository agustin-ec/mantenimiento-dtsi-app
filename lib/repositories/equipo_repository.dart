import '../models/equipo.dart';
import '../models/evento_historial.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';

/// Lectura de equipos e historial. Los errores salen como [ApiException].
class EquipoRepository {
  /// Máximo que permite el backend por petición. El contrato no devuelve
  /// total, así que por ahora se pide una sola página.
  static const limite = 100;

  final ApiClient _cliente;

  EquipoRepository(this._cliente);

  Future<List<Equipo>> listarEquipos() async {
    try {
      final respuesta = await _cliente.dio.get(
        '/equipos/',
        queryParameters: {'skip': 0, 'limit': limite},
      );
      return _mapas(respuesta.data).map(Equipo.fromJson).toList();
    } catch (e) {
      throw ApiException.desdeError(e);
    }
  }

  Future<List<EventoHistorial>> listarHistorial(int equipoId) async {
    try {
      final respuesta = await _cliente.dio.get(
        '/equipos/$equipoId/historial',
        queryParameters: {'skip': 0, 'limit': limite},
      );
      return _mapas(respuesta.data).map(EventoHistorial.fromJson).toList();
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
