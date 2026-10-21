import 'package:get/get.dart';

import '../services/almacen_seguimiento.dart';
import '../utils/sesion.dart';
import 'auth_controller.dart';

/// Equipos que la persona sigue («Mis equipos»). Al iniciar sesión se leen del disco; al
/// terminar solo se vacía la memoria, así que vuelven al entrar de nuevo.
class SeguimientoController extends GetxController {
  final AlmacenSeguimiento _almacen;
  final AuthController _auth;

  final ids = <int>{}.obs;
  final RxnString mensaje = RxnString();

  /// Cambia al limpiar: una lectura que llega después se descarta.
  int _generacion = 0;

  SeguimientoController(this._almacen, this._auth);

  @override
  void onInit() {
    super.onInit();
    alCambiarSesion(_auth, alIniciar: cargar, alTerminar: limpiarMemoria);
    if (_auth.estado.value == EstadoAuth.conSesion) cargar();
  }

  bool estaSiguiendo(int equipoId) => ids.contains(equipoId);

  /// Lectura en curso; [alternar] la espera para no guardar una memoria
  /// incompleta encima de lo guardado en el disco.
  Future<void>? _carga;

  Future<void> cargar() => _carga = _leer();

  Future<void> _leer() async {
    final usuarioId = _auth.usuario.value?.id;
    if (usuarioId == null) return;
    final generacion = _generacion;
    try {
      final guardados = await _almacen.leer(usuarioId);
      if (generacion != _generacion) return;
      ids.assignAll(guardados);
    } catch (_) {
      if (generacion != _generacion) return;
      mensaje.value = 'No se pudo leer tu seguimiento.';
    }
  }

  /// Marca o desmarca y guarda en disco. Si no se puede guardar, deshace el
  /// cambio.
  Future<void> alternar(int equipoId) async {
    await _carga;
    final usuarioId = _auth.usuario.value?.id;
    if (usuarioId == null) return;
    mensaje.value = null;
    final eraSeguido = ids.contains(equipoId);
    if (eraSeguido) {
      ids.remove(equipoId);
    } else {
      ids.add(equipoId);
    }
    try {
      await _almacen.guardar(usuarioId, ids.toSet());
    } catch (_) {
      if (eraSeguido) {
        ids.add(equipoId);
      } else {
        ids.remove(equipoId);
      }
      mensaje.value = 'No se pudo guardar el seguimiento.';
    }
  }

  /// Vacía la memoria sin tocar el disco.
  void limpiarMemoria() {
    _generacion++;
    ids.clear();
    mensaje.value = null;
  }
}
