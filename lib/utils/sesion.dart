import 'package:get/get.dart';

import '../controllers/auth_controller.dart';

/// Único punto donde los controladores con datos de la persona reaccionan al
/// estado de la sesión: [alIniciar] cuando hay sesión y [alTerminar] cuando
/// termina, sea por cierre manual o por caducidad.
Worker alCambiarSesion(
  AuthController auth, {
  void Function()? alIniciar,
  void Function()? alTerminar,
}) {
  return ever(auth.estado, (EstadoAuth estado) {
    if (estado == EstadoAuth.conSesion) alIniciar?.call();
    if (estado == EstadoAuth.sinSesion) alTerminar?.call();
  });
}
