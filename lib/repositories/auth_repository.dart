import 'package:dio/dio.dart';

import '../models/usuario.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';

/// Acceso a los endpoints de autenticación. Los errores salen como
/// [ApiException].
class AuthRepository {
  final ApiClient _cliente;

  AuthRepository(this._cliente);

  Future<bool> tieneToken() async {
    final token = await _cliente.almacen.leer();
    return token != null && token.isNotEmpty;
  }

  /// Inicia sesión, guarda el token y devuelve el perfil.
  Future<Usuario> iniciarSesion(String email, String password) async {
    try {
      final respuesta = await _cliente.dio.post(
        '/auth/login',
        data: {'username': email, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final token = (respuesta.data as Map)['access_token']?.toString();
      if (token == null || token.isEmpty) {
        throw const ApiException(ApiException.mensajeGenerico);
      }
      await _cliente.almacen.guardar(token);
    } catch (e) {
      throw ApiException.desdeError(e);
    }
    try {
      return await obtenerPerfil();
    } catch (_) {
      await _cliente.almacen.borrar();
      rethrow;
    }
  }

  Future<Usuario> registrar(
    String nombreCompleto,
    String email,
    String password,
  ) async {
    try {
      final respuesta = await _cliente.dio.post(
        '/auth/registro',
        data: {
          'nombre_completo': nombreCompleto,
          'email': email,
          'password': password,
        },
      );
      return Usuario.fromJson(Map<String, dynamic>.from(respuesta.data));
    } catch (e) {
      throw ApiException.desdeError(e);
    }
  }

  Future<Usuario> obtenerPerfil() async {
    try {
      final respuesta = await _cliente.dio.get('/auth/me');
      return Usuario.fromJson(Map<String, dynamic>.from(respuesta.data));
    } catch (e) {
      throw ApiException.desdeError(e);
    }
  }

  Future<void> cerrarSesion() => _cliente.almacen.borrar();
}
