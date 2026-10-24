import 'dart:async';

import 'package:mantenimiento_dtsi/repositories/asistente_repository.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

/// Repositorio del asistente sin red.
class RepositorioAsistenteFalso implements AsistenteRepository {
  String respuesta = 'Hay 3 órdenes abiertas.';
  ApiException? error;

  /// Preguntas recibidas, en orden.
  final List<String> preguntas = [];

  /// Si se define, [preguntar] espera a que se complete (para probar la
  /// espera de la respuesta).
  Completer<void>? espera;

  @override
  Future<String> preguntar(String pregunta) async {
    preguntas.add(pregunta);
    await espera?.future;
    final fallo = error;
    if (fallo != null) throw fallo;
    return respuesta;
  }
}
