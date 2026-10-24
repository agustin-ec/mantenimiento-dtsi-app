import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/asistente_controller.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/models/mensaje_asistente.dart';
import 'package:mantenimiento_dtsi/repositories/asistente_repository.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_asistente_falso.dart';
import '../utils/repositorio_falso.dart';

void main() {
  late RepositorioAsistenteFalso repo;
  late AuthController auth;
  late AsistenteController controlador;

  const fallo502 = ApiException(
    AsistenteRepository.mensajeNoDisponible,
    codigoEstado: 502,
  );

  setUp(() {
    repo = RepositorioAsistenteFalso();
    auth = AuthController(RepositorioFalso(), navegar: (_) {});
    controlador = Get.put(AsistenteController(repo, auth));
  });

  tearDown(Get.reset);

  test('el estado inicial no tiene mensajes, error ni espera', () {
    expect(controlador.mensajes, isEmpty);
    expect(controlador.error.value, isNull);
    expect(controlador.pensando.value, isFalse);
    expect(controlador.puedeReintentar, isFalse);
  });

  test(
    'una pregunta válida agrega el mensaje del usuario y la respuesta',
    () async {
      await controlador.enviar('¿Cuántas órdenes hay?');

      expect(repo.preguntas, ['¿Cuántas órdenes hay?']);
      expect(controlador.mensajes.map((m) => m.texto), [
        '¿Cuántas órdenes hay?',
        'Hay 3 órdenes abiertas.',
      ]);
      expect(controlador.mensajes.map((m) => m.autor), [
        AutorMensaje.usuario,
        AutorMensaje.asistente,
      ]);
      expect(controlador.pensando.value, isFalse);
      expect(controlador.error.value, isNull);
    },
  );

  test('una pregunta corta deja el error sin llamar al repositorio', () async {
    await controlador.enviar('ab');

    expect(controlador.error.value, 'Escribe al menos 3 caracteres.');
    expect(repo.preguntas, isEmpty);
    expect(controlador.mensajes, isEmpty);
  });

  test('una pregunta larga deja el error sin llamar al repositorio', () async {
    await controlador.enviar('a' * 301);

    expect(controlador.error.value, 'Máximo 300 caracteres.');
    expect(repo.preguntas, isEmpty);
    expect(controlador.mensajes, isEmpty);
  });

  test('exactamente 3 y 300 caracteres sí se envían', () async {
    await controlador.enviar('abc');
    await controlador.enviar('a' * 300);

    expect(repo.preguntas, ['abc', 'a' * 300]);
    expect(controlador.error.value, isNull);
  });

  test('recorta los espacios antes de validar y de enviar', () async {
    await controlador.enviar('  hola  ');
    expect(repo.preguntas, ['hola']);
    expect(controlador.mensajes.first.texto, 'hola');

    await controlador.enviar('  a  ');
    expect(controlador.error.value, 'Escribe al menos 3 caracteres.');
    expect(repo.preguntas, ['hola']);
  });

  test('ignora el envío mientras espera una respuesta', () async {
    repo.espera = Completer<void>();
    final primero = controlador.enviar('primera pregunta');
    await Future<void>.delayed(Duration.zero);
    expect(controlador.pensando.value, isTrue);

    await controlador.enviar('segunda pregunta');
    expect(repo.preguntas, ['primera pregunta']);
    expect(controlador.mensajes, hasLength(1));

    repo.espera!.complete();
    await primero;
    expect(controlador.pensando.value, isFalse);
    expect(controlador.mensajes, hasLength(2));
  });

  test('un fallo conserva el mensaje del usuario y muestra el error', () async {
    repo.error = fallo502;
    await controlador.enviar('¿Cuántas órdenes hay?');

    expect(controlador.mensajes.map((m) => m.texto), ['¿Cuántas órdenes hay?']);
    expect(controlador.error.value, AsistenteRepository.mensajeNoDisponible);
    expect(controlador.pensando.value, isFalse);
    expect(controlador.puedeReintentar, isTrue);
  });

  test('reintentar con éxito no duplica el mensaje del usuario', () async {
    repo.error = fallo502;
    await controlador.enviar('¿Cuántas órdenes hay?');

    repo.error = null;
    await controlador.reintentar();

    expect(repo.preguntas, ['¿Cuántas órdenes hay?', '¿Cuántas órdenes hay?']);
    expect(controlador.mensajes.map((m) => m.texto), [
      '¿Cuántas órdenes hay?',
      'Hay 3 órdenes abiertas.',
    ]);
    expect(controlador.error.value, isNull);
    expect(controlador.puedeReintentar, isFalse);
  });

  test(
    'reintentar que vuelve a fallar deja un solo mensaje y el error',
    () async {
      repo.error = fallo502;
      await controlador.enviar('¿Cuántas órdenes hay?');
      await controlador.reintentar();

      expect(controlador.mensajes, hasLength(1));
      expect(controlador.error.value, AsistenteRepository.mensajeNoDisponible);
      expect(controlador.puedeReintentar, isTrue);
    },
  );

  test('reintentar sin una pregunta fallida no hace nada', () async {
    await controlador.reintentar();
    expect(repo.preguntas, isEmpty);
  });

  test('un envío válido limpia el error de validación', () async {
    await controlador.enviar('ab');
    expect(controlador.error.value, isNotNull);

    await controlador.enviar('abc');
    expect(controlador.error.value, isNull);
  });

  test('cerrar sesión vacía mensajes, error y espera', () async {
    repo.error = fallo502;
    await controlador.enviar('¿Cuántas órdenes hay?');

    await auth.cerrarSesion();

    expect(controlador.mensajes, isEmpty);
    expect(controlador.error.value, isNull);
    expect(controlador.pensando.value, isFalse);
    expect(controlador.puedeReintentar, isFalse);
  });

  test('la sesión caducada también limpia', () async {
    await controlador.enviar('¿Cuántas órdenes hay?');

    auth.alCaducarSesion();

    expect(controlador.mensajes, isEmpty);
    expect(controlador.pensando.value, isFalse);
  });

  test('una respuesta que llega tras cerrar sesión se descarta', () async {
    repo.espera = Completer<void>();
    final envio = controlador.enviar('¿Cuántas órdenes hay?');
    await Future<void>.delayed(Duration.zero);

    await auth.cerrarSesion();
    repo.espera!.complete();
    await envio;

    expect(controlador.mensajes, isEmpty);
    expect(controlador.pensando.value, isFalse);
  });

  test('un fallo que llega tras cerrar sesión no deja error', () async {
    repo.espera = Completer<void>();
    repo.error = fallo502;
    final envio = controlador.enviar('¿Cuántas órdenes hay?');
    await Future<void>.delayed(Duration.zero);

    await auth.cerrarSesion();
    repo.espera!.complete();
    await envio;

    expect(controlador.error.value, isNull);
    expect(controlador.puedeReintentar, isFalse);
  });
}
