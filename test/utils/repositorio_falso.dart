import 'package:mantenimiento_dtsi/models/usuario.dart';
import 'package:mantenimiento_dtsi/repositories/auth_repository.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

const usuarioPrueba = Usuario(
  id: 1,
  email: 'ana@utb.edu.ec',
  nombreCompleto: 'Ana Pérez',
);

/// Repositorio sin red: cada método falla si [error] está definido.
class RepositorioFalso implements AuthRepository {
  ApiException? error;
  ApiException? errorRegistro;
  ApiException? errorPerfil;
  bool token = false;
  int cierres = 0;
  final List<String> llamadas = [];

  @override
  Future<bool> tieneToken() async => token;

  @override
  Future<Usuario> iniciarSesion(String email, String password) async {
    llamadas.add('iniciarSesion');
    if (error != null) throw error!;
    token = true;
    return usuarioPrueba;
  }

  @override
  Future<Usuario> registrar(
    String nombre,
    String email,
    String password,
  ) async {
    llamadas.add('registrar');
    if (errorRegistro != null) throw errorRegistro!;
    return usuarioPrueba;
  }

  @override
  Future<Usuario> obtenerPerfil() async {
    llamadas.add('obtenerPerfil');
    if (errorPerfil != null) throw errorPerfil!;
    return usuarioPrueba;
  }

  @override
  Future<void> cerrarSesion() async {
    cierres++;
    token = false;
  }
}
