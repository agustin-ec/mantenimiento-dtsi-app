import 'package:dio/dio.dart';

import 'almacen_token.dart';
import 'api_exception.dart';

/// Cliente HTTP del backend. Añade el token, detecta la sesión caducada y
/// entrega los errores como [ApiException] dentro de `DioException.error`.
class ApiClient {
  static const urlBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8001',
  );

  final Dio dio;
  final AlmacenToken almacen;

  /// Se invoca cuando una petición con token recibe 401.
  void Function()? alCaducarSesion;

  ApiClient({required this.almacen, this.alCaducarSesion, Dio? dio})
    : dio = dio ?? Dio() {
    this.dio.options
      ..baseUrl = urlBase
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 15)
      ..sendTimeout = const Duration(seconds: 15);
    this.dio.interceptors.add(
      InterceptorsWrapper(onRequest: _alEnviar, onError: _alFallar),
    );
  }

  Future<void> _alEnviar(
    RequestOptions opciones,
    RequestInterceptorHandler manejador,
  ) async {
    final token = await almacen.leer();
    if (token != null && token.isNotEmpty) {
      opciones.headers['Authorization'] = 'Bearer $token';
      opciones.extra[ApiException.claveConToken] = true;
    }
    manejador.next(opciones);
  }

  Future<void> _alFallar(
    DioException error,
    ErrorInterceptorHandler manejador,
  ) async {
    final teniaToken =
        error.requestOptions.extra[ApiException.claveConToken] == true;
    if (error.response?.statusCode == 401 && teniaToken) {
      await almacen.borrar();
      alCaducarSesion?.call();
    }
    manejador.next(error.copyWith(error: ApiException.desdeDio(error)));
  }
}
