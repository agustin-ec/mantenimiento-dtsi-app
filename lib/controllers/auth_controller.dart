import 'package:get/get.dart';

import '../repositories/auth_repository.dart';
import '../models/usuario.dart';
import '../services/api_exception.dart';
import '../utils/rutas.dart';

enum EstadoAuth { cargando, sinSesion, conSesion, error }

class AuthController extends GetxController {
  static const avisoSesionCaducada =
      'Tu sesión caducó, inicia sesión de nuevo.';

  final AuthRepository _repositorio;
  final void Function(String ruta) _navegar;

  final estado = EstadoAuth.cargando.obs;
  final Rxn<Usuario> usuario = Rxn<Usuario>();
  final RxnString mensaje = RxnString();
  final RxnString aviso = RxnString();

  AuthController(this._repositorio, {void Function(String ruta)? navegar})
    : _navegar = navegar ?? ((ruta) => Get.offAllNamed(ruta));

  bool get estaCargando => estado.value == EstadoAuth.cargando;

  /// Al abrir la app: si hay token lo valida con /auth/me.
  Future<void> restaurarSesion() async {
    estado.value = EstadoAuth.cargando;
    mensaje.value = null;
    try {
      if (!await _repositorio.tieneToken()) {
        _sinSesion();
        return;
      }
      usuario.value = await _repositorio.obtenerPerfil();
      estado.value = EstadoAuth.conSesion;
      _navegar(Rutas.inicio);
    } catch (e) {
      final error = ApiException.desdeError(e);
      if (error.codigoEstado == 401) {
        await _repositorio.cerrarSesion();
        _sinSesion();
      } else {
        mensaje.value = error.mensaje;
        estado.value = EstadoAuth.error;
      }
    }
  }

  Future<void> iniciarSesion(String email, String password) async {
    estado.value = EstadoAuth.cargando;
    mensaje.value = null;
    aviso.value = null;
    try {
      usuario.value = await _repositorio.iniciarSesion(email.trim(), password);
      estado.value = EstadoAuth.conSesion;
      _navegar(Rutas.inicio);
    } catch (e) {
      _fallar(e);
    }
  }

  /// Registra a la persona y luego inicia sesión sola.
  Future<void> registrar(
    String nombreCompleto,
    String email,
    String password,
  ) async {
    estado.value = EstadoAuth.cargando;
    mensaje.value = null;
    aviso.value = null;
    try {
      await _repositorio.registrar(
        nombreCompleto.trim(),
        email.trim(),
        password,
      );
    } catch (e) {
      _fallar(e);
      return;
    }
    await iniciarSesion(email, password);
  }

  Future<void> cerrarSesion() async {
    await _repositorio.cerrarSesion();
    usuario.value = null;
    _sinSesion();
  }

  /// Callback del ApiClient: una petición con token recibió 401.
  void alCaducarSesion() {
    usuario.value = null;
    aviso.value = avisoSesionCaducada;
    estado.value = EstadoAuth.sinSesion;
    _navegar(Rutas.login);
  }

  void limpiarMensajes() {
    mensaje.value = null;
    aviso.value = null;
  }

  void _sinSesion() {
    estado.value = EstadoAuth.sinSesion;
    _navegar(Rutas.login);
  }

  void _fallar(Object e) {
    mensaje.value = ApiException.desdeError(e).mensaje;
    estado.value = EstadoAuth.error;
  }
}
