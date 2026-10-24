import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../services/servicio_notificaciones.dart';
import '../utils/sesion.dart';
import 'auth_controller.dart';

/// Permiso y avisos locales. El diálogo del sistema se muestra una sola vez por
/// instalación, justo después de tener sesión; en las siguientes aperturas solo
/// se consulta el estado actual (la persona puede cambiarlo desde los ajustes).
class NotificacionesController extends GetxController {
  /// Marca en la caja de preferencias: el diálogo ya se mostró en este equipo.
  static const clavePermisoPedido = 'permiso_notificaciones_pedido';

  final ServicioNotificaciones _servicio;
  final AuthController _auth;
  final Box _caja;

  /// null mientras no se ha resuelto; luego true (se puede avisar) o false.
  final RxnBool permiso = RxnBool();

  Future<void> _resolucion = Future.value();

  NotificacionesController(this._servicio, this._auth, this._caja);

  @override
  void onInit() {
    super.onInit();
    alCambiarSesion(_auth, alIniciar: _alIniciarSesion);
    if (_auth.estado.value == EstadoAuth.conSesion) _alIniciarSesion();
  }

  /// Última resolución del permiso en curso o terminada.
  Future<void> get resolucion => _resolucion;

  void _alIniciarSesion() {
    _resolucion = _resolucion.then((_) => _resolverPermiso());
  }

  Future<void> _resolverPermiso() async {
    try {
      if (_caja.get(clavePermisoPedido) == true) {
        permiso.value = await _servicio.permisoConcedido();
        return;
      }
      permiso.value = await _servicio.pedirPermiso();
      await _caja.put(clavePermisoPedido, true);
    } catch (_) {
      permiso.value = false;
    }
  }

  /// Muestra un aviso solo si el permiso está concedido.
  Future<void> avisar(String titulo, String cuerpo) async {
    if (permiso.value != true) return;
    try {
      await _servicio.mostrarAviso(titulo, cuerpo);
    } catch (_) {
      // Un aviso que falla no debe romper a quien lo pide.
    }
  }
}
