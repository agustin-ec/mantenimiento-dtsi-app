import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/actualizador_ordenes_controller.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_falso.dart';
import '../utils/repositorio_ordenes_falso.dart';

void main() {
  const intervalo = Duration(seconds: 30);

  late RepositorioOrdenesFalso repo;
  late AuthController auth;
  late OrdenesController ordenes;

  int cargas() => repo.llamadas.where((l) => l == 'listarOrdenes').length;

  void crear({bool conSesion = true}) {
    repo = RepositorioOrdenesFalso()..ordenes = [ordenPrueba(1)];
    auth = AuthController(RepositorioFalso(), navegar: (_) {});
    ordenes = Get.put(OrdenesController(repo, auth));
    Get.put(ActualizadorOrdenesController(ordenes, auth, intervalo: intervalo));
    if (conSesion) auth.estado.value = EstadoAuth.conSesion;
  }

  /// Cierra la sesión para que el temporizador no quede pendiente al terminar.
  void terminar() => auth.estado.value = EstadoAuth.sinSesion;

  tearDown(Get.reset);

  test('el intervalo por defecto es de 60 segundos', () {
    expect(
      ActualizadorOrdenesController.intervaloPorDefecto,
      const Duration(seconds: 60),
    );
  });

  testWidgets('con sesión refresca cada intervalo y no antes', (tester) async {
    crear();

    await tester.pump(const Duration(seconds: 29));
    expect(cargas(), 0);

    await tester.pump(const Duration(seconds: 1));
    expect(cargas(), 1);

    await tester.pump(intervalo);
    expect(cargas(), 2);
    terminar();
  });

  testWidgets('sin sesión no refresca', (tester) async {
    crear(conSesion: false);

    await tester.pump(intervalo * 3);

    expect(cargas(), 0);
  });

  testWidgets('al cerrar sesión el temporizador se cancela', (tester) async {
    crear();
    await tester.pump(intervalo);
    expect(cargas(), 1);

    await auth.cerrarSesion();
    await tester.pump(intervalo * 3);

    expect(cargas(), 1);
  });

  testWidgets('al caducar la sesión el temporizador se cancela', (
    tester,
  ) async {
    crear();
    await tester.pump(intervalo);

    auth.alCaducarSesion();
    await tester.pump(intervalo * 3);

    expect(cargas(), 1);
  });

  testWidgets('pasa a segundo plano: cancela; al volver refresca y reanuda', (
    tester,
  ) async {
    crear();
    await tester.pump(intervalo);
    expect(cargas(), 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(intervalo * 3);
    expect(cargas(), 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(cargas(), 2);

    await tester.pump(intervalo);
    expect(cargas(), 3);
    terminar();
  });

  testWidgets('volver a primer plano sin sesión no refresca', (tester) async {
    crear(conSesion: false);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(intervalo);

    expect(cargas(), 0);
  });

  testWidgets('un fallo del refresco no deja error ni borra la lista', (
    tester,
  ) async {
    crear();
    await ordenes.cargar();
    final estados = <EstadosOrdenes>[];
    final vigilante = ever(ordenes.estado, estados.add);

    repo.error = const ApiException(ApiException.mensajeSinConexion);
    await tester.pump(intervalo);

    expect(cargas(), 2);
    expect(ordenes.mensaje.value, isNull);
    expect(ordenes.estado.value, EstadosOrdenes.exito);
    expect(ordenes.ordenes, hasLength(1));
    expect(estados, isEmpty);

    repo.error = null;
    repo.ordenes = [ordenPrueba(1), ordenPrueba(2)];
    await tester.pump(intervalo);
    expect(ordenes.ordenes, hasLength(2));
    expect(estados.contains(EstadosOrdenes.cargando), isFalse);

    vigilante.dispose();
    terminar();
  });
}
