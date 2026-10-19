import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

/// Guarda en Hive la preferencia de tema (sistema, claro u oscuro) y la aplica
/// al instante.
class TemaController extends GetxController {
  static const nombreCaja = 'preferencias';
  static const _clave = 'modo_tema';

  final Box _caja;
  final Rx<ThemeMode> modo = ThemeMode.system.obs;

  TemaController(this._caja) {
    modo.value = _leer();
  }

  ThemeMode _leer() {
    final guardado = _caja.get(_clave);
    return ThemeMode.values.firstWhere(
      (m) => m.name == guardado,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> cambiarModo(ThemeMode nuevo) async {
    modo.value = nuevo;
    Get.changeThemeMode(nuevo);
    await _caja.put(_clave, nuevo.name);
  }
}
