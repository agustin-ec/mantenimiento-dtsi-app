import 'package:dio/dio.dart';

/// Error de red o del backend, con un mensaje listo para mostrar en español.
class ApiException implements Exception {
  final String mensaje;
  final int? codigoEstado;

  const ApiException(this.mensaje, {this.codigoEstado});

  /// Marca de la petición que indica que llevaba token.
  static const claveConToken = 'conToken';

  static const mensajeSinConexion =
      'Sin conexión. Revisa tu red e inténtalo de nuevo.';
  static const mensajeTiempoAgotado =
      'Se agotó el tiempo de espera. Inténtalo de nuevo.';
  static const mensajeCredenciales = 'Correo o contraseña incorrectos';
  static const mensajeSesionCaducada =
      'Tu sesión caducó, inicia sesión de nuevo';
  static const mensajeServidor =
      'El servidor tuvo un problema. Inténtalo más tarde.';
  static const mensajeGenerico = 'Ocurrió un error inesperado.';

  /// Traduce un error de dio a un [ApiException].
  factory ApiException.desdeDio(DioException error) {
    if (error.error is ApiException) return error.error as ApiException;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(mensajeTiempoAgotado);
      case DioExceptionType.connectionError:
        return const ApiException(mensajeSinConexion);
      case DioExceptionType.badResponse:
        return _desdeRespuesta(error);
      default:
        return const ApiException(mensajeGenerico);
    }
  }

  /// Convierte cualquier error capturado en un mensaje apto para el usuario.
  factory ApiException.desdeError(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) return ApiException.desdeDio(error);
    return const ApiException(mensajeGenerico);
  }

  static ApiException _desdeRespuesta(DioException error) {
    final codigo = error.response?.statusCode ?? 0;
    final detalle = _detalle(error.response?.data);

    if (codigo == 401) {
      final teniaToken = error.requestOptions.extra[claveConToken] == true;
      return ApiException(
        teniaToken ? mensajeSesionCaducada : mensajeCredenciales,
        codigoEstado: codigo,
      );
    }
    if (codigo == 422) {
      return ApiException(_resumir422(detalle), codigoEstado: codigo);
    }
    if (codigo >= 500) {
      return ApiException(mensajeServidor, codigoEstado: codigo);
    }
    if (codigo == 400 || codigo == 403 || codigo == 404 || codigo == 409) {
      if (detalle is String && detalle.trim().isNotEmpty) {
        return ApiException(detalle, codigoEstado: codigo);
      }
      final porDefecto = switch (codigo) {
        403 => 'No tienes permiso para realizar esta acción.',
        404 => 'No se encontró lo que buscabas.',
        409 => 'Ya existe un registro con esos datos.',
        _ => 'La solicitud no es válida.',
      };
      return ApiException(porDefecto, codigoEstado: codigo);
    }
    return ApiException(mensajeGenerico, codigoEstado: codigo);
  }

  static dynamic _detalle(dynamic datos) {
    if (datos is Map) return datos['detail'];
    return null;
  }

  static String _resumir422(dynamic detalle) {
    final campos = <String>[];
    if (detalle is List) {
      for (final item in detalle) {
        if (item is! Map) continue;
        final loc = item['loc'];
        if (loc is! List || loc.isEmpty) continue;
        final nombre = loc.last.toString();
        if (!campos.contains(nombre)) campos.add(nombre);
      }
    }
    if (campos.isEmpty) return 'Hay datos que no son válidos. Revísalos.';
    final lista = campos.length == 1
        ? campos.first
        : '${campos.sublist(0, campos.length - 1).join(', ')} y ${campos.last}';
    return campos.length == 1
        ? 'Revisa el campo: $lista.'
        : 'Revisa los campos: $lista.';
  }

  /// Fallo de red o del servidor (sin conexión, tiempo agotado o 5xx): los
  /// únicos en los que tiene sentido usar datos guardados.
  bool get permiteCache {
    final codigo = codigoEstado;
    if (codigo != null) return codigo >= 500;
    return mensaje == mensajeSinConexion || mensaje == mensajeTiempoAgotado;
  }

  @override
  String toString() => mensaje;
}
