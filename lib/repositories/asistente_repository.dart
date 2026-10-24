import 'package:dio/dio.dart';

import '../services/api_client.dart';
import '../services/api_exception.dart';

/// Consultas al asistente de IA del backend. Los errores salen como
/// [ApiException]. La pregunta no se reintenta sola ni se registra.
class AsistenteRepository {
  /// El backend espera hasta 20 s al modelo; este margen evita cortar antes.
  static const esperaRespuesta = Duration(seconds: 30);

  static const mensajeNoConfigurado =
      'El asistente no está configurado en el servidor.';
  static const mensajeNoDisponible =
      'El asistente no está disponible por ahora. Intenta más tarde.';

  final ApiClient _cliente;

  AsistenteRepository(this._cliente);

  /// Envía la pregunta y devuelve el texto de la respuesta. El tiempo de
  /// espera de 30 s vale solo para esta petición.
  Future<String> preguntar(String pregunta) async {
    try {
      final respuesta = await _cliente.dio.post(
        '/asistente/preguntar',
        data: {'pregunta': pregunta},
        options: Options(receiveTimeout: esperaRespuesta),
      );
      final datos = respuesta.data;
      final texto = datos is Map ? datos['respuesta'] : null;
      if (texto is! String) {
        throw const ApiException(ApiException.mensajeGenerico);
      }
      return texto;
    } catch (e) {
      throw _traducir(ApiException.desdeError(e));
    }
  }

  ApiException _traducir(ApiException error) {
    return switch (error.codigoEstado) {
      503 => const ApiException(mensajeNoConfigurado, codigoEstado: 503),
      502 => const ApiException(mensajeNoDisponible, codigoEstado: 502),
      _ => error,
    };
  }
}
