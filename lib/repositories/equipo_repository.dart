import '../models/equipo.dart';
import '../models/evento_historial.dart';
import '../models/lista_equipos.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/cache_equipos.dart';

/// Lectura de equipos e historial. Los errores salen como [ApiException].
///
/// La lista se guarda en la caché de la persona activa ([idUsuario]); si la
/// red o el servidor fallan, se devuelven los últimos datos guardados.
class EquipoRepository {
  /// Máximo que permite el backend por petición. El contrato no devuelve
  /// total, así que por ahora se pide una sola página.
  static const limite = 100;

  final ApiClient _cliente;
  final CacheEquipos? _cache;
  final int? Function()? _idUsuario;

  EquipoRepository(this._cliente, {this._cache, this._idUsuario});

  Future<ListaEquipos> listarEquipos() async {
    final ListaEquipos lista;
    try {
      final respuesta = await _cliente.dio.get(
        '/equipos/',
        queryParameters: {'skip': 0, 'limit': limite},
      );
      final equipos = _mapas(respuesta.data).map(Equipo.fromJson).toList();
      lista = ListaEquipos(equipos, sincronizadoEn: DateTime.now());
    } catch (e) {
      final error = ApiException.desdeError(e);
      if (error.permiteCache) {
        final guardada = await _leerCache();
        if (guardada != null) return guardada;
      }
      throw error;
    }
    await _guardarCache(lista);
    return lista;
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

  // La caché es un respaldo: si falla al leer o escribir, no debe romper la
  // carga.
  Future<ListaEquipos?> _leerCache() async {
    final id = _idUsuario?.call();
    if (_cache == null || id == null) return null;
    try {
      return await _cache.leer(id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardarCache(ListaEquipos lista) async {
    final id = _idUsuario?.call();
    if (_cache == null || id == null) return;
    try {
      await _cache.guardar(id, lista.equipos, lista.sincronizadoEn);
    } catch (_) {
      // Sin caché la app sigue funcionando con datos de la red.
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
