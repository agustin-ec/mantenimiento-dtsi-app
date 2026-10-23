import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/tecnicos_controller.dart';
import 'package:mantenimiento_dtsi/models/tecnico.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_falso.dart';
import '../utils/repositorio_ordenes_falso.dart';

void main() {
  late RepositorioOrdenesFalso repo;
  late AuthController auth;
  late TecnicosController controlador;

  setUp(() {
    repo = RepositorioOrdenesFalso()
      ..tecnicos = [
        const Tecnico(id: 4, nombreCompleto: 'Ana Ruiz'),
        const Tecnico(id: 5, nombreCompleto: 'Luis Mora'),
      ];
    auth = AuthController(RepositorioFalso(), navegar: (_) {});
    controlador = Get.put(TecnicosController(repo, auth));
  });
  tearDown(Get.reset);

  test('arranca en cargando y sin pedir nada', () {
    expect(controlador.estado.value, EstadosTecnicos.cargando);
    expect(repo.llamadas, isEmpty);
  });

  test('cargar: pasa a éxito con la lista', () async {
    await controlador.cargar();
    expect(controlador.estado.value, EstadosTecnicos.exito);
    expect(controlador.tecnicos.map((t) => t.id), [4, 5]);
    expect(controlador.nombrePara(5), 'Luis Mora');
    expect(controlador.nombrePara(99), isNull);
    expect(controlador.nombrePara(null), isNull);
  });

  test('cargar: lista vacía queda en vacío', () async {
    repo.tecnicos = [];
    await controlador.cargar();
    expect(controlador.estado.value, EstadosTecnicos.vacio);
  });

  test('cargar: el error deja el mensaje y se puede reintentar', () async {
    repo.errorTecnicos = const ApiException('Sin conexión', codigoEstado: null);
    await controlador.cargar();
    expect(controlador.estado.value, EstadosTecnicos.error);
    expect(controlador.mensaje.value, 'Sin conexión');

    repo.errorTecnicos = null;
    await controlador.cargar();
    expect(controlador.estado.value, EstadosTecnicos.exito);
    expect(controlador.mensaje.value, isNull);
  });

  test('pasa por cargando mientras espera la respuesta', () async {
    repo.esperaTecnicos = Completer<void>();
    final futuro = controlador.cargar();
    expect(controlador.estado.value, EstadosTecnicos.cargando);
    repo.esperaTecnicos!.complete();
    await futuro;
    expect(controlador.estado.value, EstadosTecnicos.exito);
  });

  test('al terminar la sesión se limpia la lista', () async {
    await controlador.cargar();
    auth.estado.value = EstadoAuth.conSesion;
    auth.estado.value = EstadoAuth.sinSesion;
    await Future<void>.delayed(Duration.zero);

    expect(controlador.tecnicos, isEmpty);
    expect(controlador.estado.value, EstadosTecnicos.cargando);
    expect(controlador.nombrePara(4), isNull);
  });

  test('una respuesta tardía de la sesión anterior se descarta', () async {
    repo.esperaTecnicos = Completer<void>();
    final futuro = controlador.cargar();
    auth.estado.value = EstadoAuth.conSesion;
    auth.estado.value = EstadoAuth.sinSesion;
    await Future<void>.delayed(Duration.zero);
    repo.esperaTecnicos!.complete();
    await futuro;

    expect(controlador.tecnicos, isEmpty);
    expect(controlador.estado.value, EstadosTecnicos.cargando);
  });
}
