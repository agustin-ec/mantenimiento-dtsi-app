import 'package:mantenimiento_dtsi/services/servicio_notificaciones.dart';

/// Servicio de notificaciones sin plugin: guarda los avisos mostrados y deja
/// simular el permiso concedido, denegado o retirado desde los ajustes.
class ServicioNotificacionesFalso implements ServicioNotificaciones {
  /// Lo que devuelve [pedirPermiso]; false simula «denegado».
  bool concederAlPedir = true;

  /// Lo que devuelve [permisoConcedido]; false simula «retirado desde los
  /// ajustes del sistema».
  bool permisoActual = true;

  /// Si es true, pedir, consultar el permiso y avisar lanzan una excepción.
  bool falla = false;

  int iniciados = 0;
  int permisosPedidos = 0;
  int consultas = 0;
  final List<(String, String)> avisos = [];

  @override
  Future<void> iniciar() async => iniciados++;

  @override
  Future<bool> pedirPermiso() async {
    permisosPedidos++;
    if (falla) throw StateError('fallo del plugin');
    return concederAlPedir;
  }

  @override
  Future<bool> permisoConcedido() async {
    consultas++;
    if (falla) throw StateError('fallo del plugin');
    return permisoActual;
  }

  @override
  Future<void> mostrarAviso(String titulo, String cuerpo) async {
    if (falla) throw StateError('fallo del plugin');
    avisos.add((titulo, cuerpo));
  }
}
