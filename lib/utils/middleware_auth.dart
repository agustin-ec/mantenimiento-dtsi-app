import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import 'rutas.dart';

/// Protege las rutas según haya sesión o no.
class MiddlewareAuth extends GetMiddleware {
  /// true: exige sesión (pantallas protegidas); false: solo para quien no la
  /// tiene (inicio de sesión y registro).
  final bool requiereSesion;

  MiddlewareAuth({required this.requiereSesion});

  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthController>();
    final conSesion = auth.estado.value == EstadoAuth.conSesion;
    if (requiereSesion && !conSesion) {
      return const RouteSettings(name: Rutas.login);
    }
    if (!requiereSesion && conSesion) {
      return const RouteSettings(name: Rutas.inicio);
    }
    return null;
  }
}
