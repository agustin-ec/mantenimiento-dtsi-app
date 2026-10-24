import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../utils/sesion.dart';
import 'auth_controller.dart';
import 'ordenes_controller.dart';

/// Refresca las órdenes en silencio cada [intervalo] mientras la app está en
/// primer plano y hay sesión, y de inmediato al volver a primer plano. El
/// temporizador se cancela al terminar la sesión y al pasar a segundo plano.
class ActualizadorOrdenesController extends GetxController
    with WidgetsBindingObserver {
  static const intervaloPorDefecto = Duration(seconds: 60);

  final OrdenesController _ordenes;
  final AuthController _auth;
  final Duration intervalo;

  Timer? _temporizador;
  bool _primerPlano = true;

  ActualizadorOrdenesController(
    this._ordenes,
    this._auth, {
    this.intervalo = intervaloPorDefecto,
  });

  bool get _haySesion => _auth.estado.value == EstadoAuth.conSesion;

  @override
  void onInit() {
    super.onInit();
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    final estado = binding.lifecycleState;
    _primerPlano =
        estado == null ||
        estado == AppLifecycleState.resumed ||
        estado == AppLifecycleState.inactive;
    alCambiarSesion(_auth, alIniciar: _arrancar, alTerminar: _cancelar);
    if (_haySesion) _arrancar();
  }

  @override
  void onClose() {
    _cancelar();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _primerPlano = true;
        if (_haySesion) {
          unawaited(_ordenes.refrescarEnSilencio());
          _arrancar();
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _primerPlano = false;
        _cancelar();
      case AppLifecycleState.inactive:
        // Transitorio (diálogo de permiso, panel de notificaciones).
        break;
    }
  }

  void _arrancar() {
    _cancelar();
    if (!_primerPlano || !_haySesion) return;
    _temporizador = Timer.periodic(
      intervalo,
      (_) => unawaited(_ordenes.refrescarEnSilencio()),
    );
  }

  void _cancelar() {
    _temporizador?.cancel();
    _temporizador = null;
  }
}
