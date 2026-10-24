import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/notificaciones_controller.dart';

import '../utils/repositorio_falso.dart';
import '../utils/servicio_notificaciones_falso.dart';

void main() {
  late Directory directorio;
  late Box caja;
  late ServicioNotificacionesFalso servicio;
  late AuthController auth;
  late NotificacionesController controlador;

  /// Crea auth y controlador como al abrir la app; [conSesion] simula abrirla
  /// con una sesión ya válida.
  void abrirApp({bool conSesion = false}) {
    Get.reset();
    auth = AuthController(RepositorioFalso(), navegar: (_) {});
    if (conSesion) auth.estado.value = EstadoAuth.conSesion;
    controlador = Get.put(NotificacionesController(servicio, auth, caja));
  }

  Future<void> iniciarSesion() async {
    await auth.iniciarSesion('ana@utb.edu.ec', 'clave');
    await controlador.resolucion;
  }

  setUp(() async {
    directorio = await Directory.systemTemp.createTemp('hive_notificaciones');
    Hive.init(directorio.path);
    caja = await Hive.openBox('prueba_notificaciones');
    servicio = ServicioNotificacionesFalso();
  });

  tearDown(() async {
    Get.reset();
    await Hive.deleteFromDisk();
    await directorio.delete(recursive: true);
  });

  test('sin sesión no pide el permiso', () async {
    abrirApp();
    await controlador.resolucion;

    expect(servicio.permisosPedidos, 0);
    expect(servicio.consultas, 0);
    expect(controlador.permiso.value, isNull);
  });

  test('al iniciar sesión pide el permiso una sola vez', () async {
    abrirApp();
    await iniciarSesion();

    expect(servicio.permisosPedidos, 1);
    expect(controlador.permiso.value, isTrue);
    expect(caja.get(NotificacionesController.clavePermisoPedido), isTrue);
  });

  test('cerrar sesión y volver a entrar no vuelve a pedirlo', () async {
    abrirApp();
    await iniciarSesion();
    await auth.cerrarSesion();
    await iniciarSesion();

    expect(servicio.permisosPedidos, 1);
    expect(servicio.consultas, 1);
    expect(controlador.permiso.value, isTrue);
  });

  test('al reabrir la app con sesión y permiso concedido no lo pide, consulta '
      'el estado y sí muestra avisos', () async {
    await caja.put(NotificacionesController.clavePermisoPedido, true);
    abrirApp(conSesion: true);
    await controlador.resolucion;

    expect(servicio.permisosPedidos, 0);
    expect(servicio.consultas, 1);
    expect(controlador.permiso.value, isTrue);

    await controlador.avisar('Orden actualizada', 'La orden OT-1 cambió.');
    expect(servicio.avisos, [('Orden actualizada', 'La orden OT-1 cambió.')]);
  });

  test('al reabrir la app con el permiso retirado desde los ajustes queda en '
      'false, no lo pide y no muestra avisos', () async {
    await caja.put(NotificacionesController.clavePermisoPedido, true);
    servicio.permisoActual = false;
    abrirApp(conSesion: true);
    await controlador.resolucion;

    expect(servicio.permisosPedidos, 0);
    expect(controlador.permiso.value, isFalse);

    await controlador.avisar('Orden actualizada', 'La orden OT-1 cambió.');
    expect(servicio.avisos, isEmpty);
  });

  test('si la app se abre con sesión y nunca se pidió, lo pide', () async {
    abrirApp(conSesion: true);
    await controlador.resolucion;

    expect(servicio.permisosPedidos, 1);
    expect(controlador.permiso.value, isTrue);
  });

  test('con el permiso denegado no hay avisos', () async {
    servicio.concederAlPedir = false;
    abrirApp();
    await iniciarSesion();

    expect(controlador.permiso.value, isFalse);
    await controlador.avisar('Título', 'Cuerpo');
    expect(servicio.avisos, isEmpty);
  });

  test('con el permiso concedido muestra el título y el cuerpo', () async {
    abrirApp();
    await iniciarSesion();

    await controlador.avisar('Orden asignada', 'Se te asignó la orden OT-7.');

    expect(servicio.avisos, [
      ('Orden asignada', 'Se te asignó la orden OT-7.'),
    ]);
  });

  test('avisar antes de pedir el permiso no muestra nada', () async {
    abrirApp();
    await controlador.avisar('Título', 'Cuerpo');

    expect(servicio.avisos, isEmpty);
  });

  test(
    'un fallo del servicio no rompe nada y deja el permiso en false',
    () async {
      servicio.falla = true;
      abrirApp();
      await iniciarSesion();
      expect(controlador.permiso.value, isFalse);
      await controlador.avisar('Título', 'Cuerpo');

      await caja.put(NotificacionesController.clavePermisoPedido, true);
      abrirApp(conSesion: true);
      await controlador.resolucion;
      expect(controlador.permiso.value, isFalse);
      await controlador.avisar('Título', 'Cuerpo');
      expect(servicio.avisos, isEmpty);
    },
  );
}
